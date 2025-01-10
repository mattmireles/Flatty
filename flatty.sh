#!/bin/bash

# Exit on any error
set -e

# Default configuration
OUTPUT_DIR="$HOME/flattened"
SEPARATOR="---"
TOKEN_LIMIT=100000
GROUP_BY="directory"  # directory, type, or size
VERBOSE=false

# Help text
show_help() {
    cat << EOF
Flatty - Convert directories into LLM-friendly text files

Usage: flatty [options] [patterns...]

Options:
    -o, --output-dir DIR     Output directory (default: ~/flattened)
    -g, --group-by MODE      Grouping mode:
                            directory  - Group by directory structure (default)
                            type       - Group by file type
                            size       - Evenly split by token count
    -i, --include PATTERN    Include only files matching pattern
    -x, --exclude PATTERN    Exclude files matching pattern
    -t, --tokens LIMIT       Target token limit per file (default: 100000)
    -v, --verbose            Show detailed progress
    -h, --help               Show this help message

Examples:
    flatty                                    # Process current directory
    flatty -i "*.swift" -i "*.h" -i "*.m"    # Only Swift and Obj-C files
    flatty --group-by type                    # Group similar files together
    flatty --group-by size -t 50000          # Even chunks of 50k tokens
EOF
    exit 0
}

# Parse command line arguments
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -g|--group-by)
            GROUP_BY="$2"
            shift 2
            ;;
        -i|--include)
            INCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -t|--tokens)
            TOKEN_LIMIT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            INCLUDE_PATTERNS+=("$1")
            shift
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Define a run-specific timestamp (human-readable, avoiding colons).
RUN_TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

# Helper function to estimate tokens
estimate_tokens() {
    local content="$1"
    local char_count
    char_count=$(echo "$content" | wc -c)
    echo $((char_count / 4))  # Rough estimate: ~4 chars per token
}

# Helper function to check if file matches patterns
matches_patterns() {
    local file="$1"
    local matched=false
    
    # If no include patterns, match everything
    if [ ${#INCLUDE_PATTERNS[@]} -eq 0 ]; then
        matched=true
    else
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            if [[ "$file" == $pattern ]]; then
                matched=true
                break
            fi
        done
    fi
    
    # Check exclude patterns
    if [ "$matched" = true ]; then
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$file" == $pattern ]]; then
                matched=false
                break
            fi
        done
    fi
    
    [ "$matched" = true ]
}

# Helper function to get file type group
get_file_type_group() {
    local file="$1"
    case "$file" in
        *.py|*.pyc) echo "python";;
        *.js|*.jsx|*.ts|*.tsx) echo "javascript";;
        *.go) echo "golang";;
        *.rb) echo "ruby";;
        *.java|*.class) echo "java";;
        *.c|*.h) echo "c";;
        *.cpp|*.hpp|*.cc) echo "cpp";;
        *.swift) echo "swift";;
        *.m|*.mm) echo "objective-c";;
        *.html|*.htm) echo "html";;
        *.css|*.scss|*.sass) echo "css";;
        *.md|*.markdown) echo "docs";;
        *.json|*.yaml|*.yml|*.toml) echo "config";;
        *) echo "other";;
    esac
}

# Function to write file content
write_file_content() {
    local file="$1"
    local output_file="$2"
    
    echo "$SEPARATOR" >> "$output_file"
    echo "$file" >> "$output_file"
    echo "$SEPARATOR" >> "$output_file"
    cat "$file" >> "$output_file"
    echo "" >> "$output_file"
}

# Function to process files by directory
process_by_directory() {
    local current_file=""
    local current_tokens=0
    local file_counter=0
    local current_dir=""
    local total_files=0
    local processed_files=0
    
    print_status "Analyzing files..."
    
    # Count total files first
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            ((total_files++))
        fi
    done < <(find . -type f | sort)
    
    if [ $total_files -eq 0 ]; then
        print_info "No matching text files found in directory"
        return
    fi
    
    print_status "Found $total_files text files to process"
    
    # Process files
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            dir=$(dirname "$file")
            
            # Start new file if directory changes or token limit reached
            if [ "$dir" != "$current_dir" ] || [ $current_tokens -gt $TOKEN_LIMIT ]; then
                if [ ! -z "$current_file" ]; then
                    print_info "Created: $(basename "$current_file") (files: $processed_files)"
                fi
                
                current_dir="$dir"
                file_counter=$((file_counter + 1))
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-${file_counter}-${dir//\//-}.txt"
                current_tokens=0
                
                # Write header
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Directory: $dir" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
                
                print_status "Processing directory: $dir"
            fi
            
            write_file_content "$file" "$current_file"
            current_tokens=$((current_tokens + $(estimate_tokens "$(cat "$file")")))
            ((processed_files++))
            
            if [ "$VERBOSE" = true ]; then
                echo "  Processing ($processed_files/$total_files): $file"
            fi
        fi
    done < <(find . -type f | sort)
    
    # Report final file if it exists
    if [ ! -z "$current_file" ]; then
        print_info "Created: $(basename "$current_file") (files: $processed_files)"
    fi
    
    print_success "Processed $processed_files files into $file_counter output files"
    for ((i=1; i<=$file_counter; i++)); do
        echo "  📄 $(basename "$PWD")-${RUN_TIMESTAMP}-${i}-*.txt"
    done
}

# Function to process files by type
process_by_type() {
    local current_file=""
    local current_tokens=0
    local file_counter=1
    local current_type=""
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            type=$(get_file_type_group "$file")
            
            # Start new file if type changes or token limit reached
            if [ "$type" != "$current_type" ] || [ $current_tokens -gt $TOKEN_LIMIT ]; then
                current_type="$type"
                file_counter=$((file_counter + 1))
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-${file_counter}-${type}.txt"
                current_tokens=0
                
                # Write header
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Type: $type" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            write_file_content "$file" "$current_file"
            current_tokens=$((current_tokens + $(estimate_tokens "$(cat "$file")")))
            [ "$VERBOSE" = true ] && echo "Processing: $file ($current_tokens tokens)"
        fi
    done < <(find . -type f | sort)
}

# Add these helper functions near the top after the configuration
print_status() {
    echo "🔄 $1"
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1"
}

# Add a function to calculate total tokens for initial assessment
calculate_total_tokens() {
    local total_tokens=0
    local file_count=0
    
    print_status "Analyzing repository size..."
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            ((file_count++))
            total_tokens=$((total_tokens + $(estimate_tokens "$(cat "$file")")))
            if [ "$VERBOSE" = true ]; then
                echo "  Scanning: $file"
            fi
        fi
    done < <(find . -type f | sort)
    
    print_info "Found $file_count files totaling approximately $total_tokens tokens"
    echo "$total_tokens"
}

# Modify the process_by_size function to handle single-file case
process_by_size() {
    local current_file=""
    local current_tokens=0
    local file_counter=1
    local total_tokens
    
    total_tokens=$(calculate_total_tokens)
    
    # For small repos, use a single file
    if [ "$total_tokens" -le "$TOKEN_LIMIT" ]; then
        print_status "Repository fits within token limit. Creating single consolidated file..."
        current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}.txt"
        
        # Write header
        echo "# Project: $(basename "$PWD")" > "$current_file"
        echo "# Generated: $(date)" >> "$current_file"
        echo "# Total Tokens: ~$total_tokens" >> "$current_file"
        echo "---" >> "$current_file"
        
        local processed_files=0
        while IFS= read -r -d $'\n' file; do
            if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
                ((processed_files++))
                write_file_content "$file" "$current_file"
                [ "$VERBOSE" = true ] && echo "Processing ($processed_files): $file"
            fi
        done < <(find . -type f | sort)
        
        print_success "Created: $(basename "$current_file")"
        print_info "Location: $current_file"
        return
    fi
    
    # For larger repos, split into multiple files
    print_status "Repository exceeds token limit. Splitting into multiple files..."
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            # Start new file if token limit reached
            if [ $current_tokens -gt $TOKEN_LIMIT ]; then
                print_info "Created: $(basename "$current_file") (tokens: $current_tokens)"
                file_counter=$((file_counter + 1))
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-part${file_counter}.txt"
                current_tokens=0
                
                # Write header
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Part: $file_counter" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            # If current_file is still empty (first file in the run), define it here
            if [ -z "$current_file" ]; then
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-part${file_counter}.txt"
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Part: $file_counter" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi

            write_file_content "$file" "$current_file"
            current_tokens=$((current_tokens + $(estimate_tokens "$(cat "$file")")))
            [ "$VERBOSE" = true ] && echo "Processing: $file ($current_tokens tokens)"
        fi
    done < <(find . -type f | sort)
    
    print_success "Created $file_counter files:"
    for ((i=1; i<=$file_counter; i++)); do
        echo "  📄 $(basename "$PWD")-${RUN_TIMESTAMP}-part${i}.txt"
    done
}

# Main execution
print_status "Starting Flatty..."
print_info "Output directory: $OUTPUT_DIR"
[ "$VERBOSE" = true ] && print_info "Verbose mode enabled"

case $GROUP_BY in
    "directory")
        print_status "Processing by directory structure..."
        process_by_directory
        ;;
    "type")
        print_status "Processing by file type..."
        process_by_type
        ;;
    "size")
        print_status "Processing by size..."
        process_by_size
        ;;
    *)
        echo "Error: Invalid grouping mode: $GROUP_BY"
        exit 1
        ;;
esac

print_success "Processing complete!"
print_info "Files saved in: $OUTPUT_DIR"