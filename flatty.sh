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
    local file_counter=1
    local current_dir=""
    
    # First, group files by directory
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            dir=$(dirname "$file")
            
            # Start new file if directory changes or token limit reached
            if [ "$dir" != "$current_dir" ] || [ $current_tokens -gt $TOKEN_LIMIT ]; then
                current_dir="$dir"
                file_counter=$((file_counter + 1))
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-${file_counter}-${dir//\//-}.txt"
                current_tokens=0
                
                # Write header
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Directory: $dir" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            write_file_content "$file" "$current_file"
            current_tokens=$((current_tokens + $(estimate_tokens "$(cat "$file")")))
            [ "$VERBOSE" = true ] && echo "Processing: $file ($current_tokens tokens)"
        fi
    done < <(find . -type f | sort)
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

# Function to process files by size
process_by_size() {
    local current_file=""
    local current_tokens=0
    local file_counter=1
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            # Start new file if token limit reached
            if [ $current_tokens -gt $TOKEN_LIMIT ]; then
                file_counter=$((file_counter + 1))
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-${file_counter}.txt"
                current_tokens=0
                
                # Write header
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Part: $file_counter" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            # If current_file is still empty (first file in the run), define it here
            if [ -z "$current_file" ]; then
                current_file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}-${file_counter}.txt"
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
}

# Main execution
case $GROUP_BY in
    "directory")
        process_by_directory
        ;;
    "type")
        process_by_type
        ;;
    "size")
        process_by_size
        ;;
    *)
        echo "Error: Invalid grouping mode: $GROUP_BY"
        exit 1
        ;;
esac

echo "✨ Processing complete!"
echo "📊 Output saved to: $OUTPUT_DIR"