#!/bin/bash

# ==========================================================
# Flatty - Convert directories into LLM-friendly text files
# ==========================================================
#
# This script scans a directory (and subdirectories),
# then generates consolidated plain text files containing
# source code and text-based files. 
#
# Key Features:
#  - Grouping by directory, file type, or size
#  - Token estimations to split large files
#  - Detailed logging and status messages
#  - Validation, cleanup, and robust error handling
#
# ==========================================================
# 1. Global Behavior: Errors, Cleanup, & Signal Handling
# ==========================================================

set -e
set -o pipefail

handle_error() {
    local line_no=$1
    local error_code=$2
    echo "❌ Error on line ${line_no}: Command exited with status ${error_code}"
    exit 1
}
trap 'handle_error ${LINENO} $?' ERR

declare -a cleanup_files=()

cleanup() {
    local exit_code=$?

    if [ ${#cleanup_files[@]} -gt 0 ]; then
        print_status "Cleaning up temporary files..."
        for file in "${cleanup_files[@]}"; do
            [ -f "$file" ] && rm -f "$file"
        done
    fi
    
    if [ $exit_code -ne 0 ]; then
        print_error "Process failed with exit code $exit_code"
    fi
    
    exit $exit_code
}

trap cleanup EXIT
trap 'exit 1' INT TERM


# ==========================================================
# 2. Configuration & Globals
# ==========================================================
OUTPUT_DIR="$HOME/flattened"
SEPARATOR="---"
TOKEN_LIMIT=100000
GROUP_BY="directory"    # Can be: directory, type, or size
VERBOSE=false

# Global arrays (Removed local -n)
# We'll store directory data here, visible to all functions
declare -a SCAN_DIR_NAMES=()
declare -a SCAN_DIR_TOKEN_COUNTS=()
declare -a SCAN_DIR_FILE_LISTS=()

declare -a created_files=()  # track output files
DEFAULT_EXCLUDES=("*.git/*" "*.DS_Store" "*node_modules/*" "*.swiftpm/*")
RUN_TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')


# ==========================================================
# 3. Logging & Output Helpers
# ==========================================================
print_status() {
    echo "🔄 $1"
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1"
}

print_error() {
    echo "❌ $1" >&2
}


# ==========================================================
# 4. Environment & Validation
# ==========================================================
validate_environment() {
    if [ -z "$(find . -type f -print -quit)" ]; then
        print_error "No files found in directory"
        exit 1
    fi

    if [ ! -w "$(dirname "$OUTPUT_DIR")" ]; then
        print_error "Cannot write to output directory location: $OUTPUT_DIR"
        exit 1
    fi

    for cmd in find grep sed tr wc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
}


# ==========================================================
# 5. Token Estimation & Pattern Matching
# ==========================================================
estimate_tokens() {
    local content="$1"
    local char_count
    char_count=$(printf "%s" "$content" | wc -c | tr -d '[:space:]')
    echo $((char_count / 4))
}

matches_patterns() {
    local file="$1"
    local matched=false
    
    for pattern in "${DEFAULT_EXCLUDES[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 1
        fi
    done
    
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


# ==========================================================
# 6. File Creation and Content Writing
# ==========================================================
create_output_file() {
    local name="$1"
    local type="$2"  # main, chunk, sub-chunk

    local file="${OUTPUT_DIR}/$(basename "$PWD")-${RUN_TIMESTAMP}"
    case "$type" in
        main)
            file+=".txt"
            ;;
        chunk)
            file+="-part${name}.txt"
            ;;
        *)
            print_error "Invalid file type: $type"
            return 1
            ;;
    esac

    if ! (set -o noclobber; > "$file" 2>/dev/null); then
        print_error "Output file already exists or cannot be created: $file"
        return 1
    fi

    created_files+=("$file")
    echo "$file"
}

write_file_content() {
    local file="$1"
    local output_file="$2"

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi
    if [ ! -r "$file" ]; then
        print_error "Cannot read file: $file"
        return 1
    fi

    echo "$SEPARATOR" >> "$output_file" || {
        print_error "Failed to write separator to output file"
        return 1
    }
    
    echo "$file" >> "$output_file" || {
        print_error "Failed to write filename to output file"
        return 1
    }
    
    echo "$SEPARATOR" >> "$output_file" || {
        print_error "Failed to write separator to output file"
        return 1
    }
    
    cat "$file" >> "$output_file" || {
        print_error "Failed to write file content: $file"
        return 1
    }
    
    echo "" >> "$output_file" || {
        print_error "Failed to write newline to output file"
        return 1
    }
}


# ==========================================================
# 7. Directory Scanning & Data Structures
# ==========================================================
# We'll store all directory data into the global arrays.

scan_repository() {
    print_status "Scanning repository structure..."
    
    local old_IFS="$IFS"
    IFS=$'\n'
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            local dir
            dir="$(dirname "$file")"
            local tokens
            tokens=$(estimate_tokens "$(cat "$file")")

            # Check if directory already tracked
            local found_index=-1
            for ((i=0; i<${#SCAN_DIR_NAMES[@]}; i++)); do
                if [ "${SCAN_DIR_NAMES[i]}" = "$dir" ]; then
                    found_index=$i
                    break
                fi
            done

            if [ $found_index -ge 0 ]; then
                SCAN_DIR_TOKEN_COUNTS[$found_index]=$(( SCAN_DIR_TOKEN_COUNTS[$found_index] + tokens ))
                SCAN_DIR_FILE_LISTS[$found_index]="${SCAN_DIR_FILE_LISTS[$found_index]}${file}"$'\n'
            else
                SCAN_DIR_NAMES+=("$dir")
                SCAN_DIR_TOKEN_COUNTS+=( "$tokens" )
                SCAN_DIR_FILE_LISTS+=( "${file}"$'\n' )
            fi

            [ "$VERBOSE" = true ] && echo "  Scanning: $file (${tokens} tokens)"
        fi
    done < <(find . -type f | sort)
    
    IFS="$old_IFS"
}


# ==========================================================
# 8. Single-File Output (Write Entire Repo to One File)
# ==========================================================
write_single_file() {
    print_status "Repository fits within token limit. Creating single consolidated file..."
    
    local current_file
    current_file=$(create_output_file "main" "main") || exit 1
    echo "# Project: $(basename "$PWD")" > "$current_file"
    echo "# Generated: $(date)" >> "$current_file"
    
    # For clarity, embed a directory structure overview if desired
    # (But we rely on the global arrays for tokens)
    write_full_directory_structure "$current_file" SCAN_DIR_TOKEN_COUNTS
    
    echo "---" >> "$current_file"

    for ((i=0; i<${#SCAN_DIR_NAMES[@]}; i++)); do
        local dir="${SCAN_DIR_NAMES[i]}"
        echo -e "\n## Directory: $dir" >> "$current_file"
        
        # Read the newline-delimited file list
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            write_file_content "$f" "$current_file"
        done <<< "${SCAN_DIR_FILE_LISTS[i]}"
    done
    
    created_files+=("$current_file")
    print_success "Created: $(basename "$current_file")"
}


# ==========================================================
# 9. Directory-Based Processing
# ==========================================================
process_by_directory() {
    # Fill up our global arrays
    scan_repository
    
    local total_tokens=0
    for ((i=0; i<${#SCAN_DIR_TOKEN_COUNTS[@]}; i++)); do
        total_tokens=$(( total_tokens + SCAN_DIR_TOKEN_COUNTS[i] ))
    done
    
    print_info "Found ${#SCAN_DIR_NAMES[@]} directories totaling ~$total_tokens tokens"
    
    if [ "$total_tokens" -le "$TOKEN_LIMIT" ]; then
        write_single_file
        return
    fi

    # Otherwise, break it into chunks
    local current_chunk_dirs=()
    local current_chunk_tokens=0
    local chunk_number=1
    
    for ((i=0; i<${#SCAN_DIR_NAMES[@]}; i++)); do
        local dir="${SCAN_DIR_NAMES[i]}"
        local dtokens="${SCAN_DIR_TOKEN_COUNTS[i]}"
        
        # Only split if directory is actually large
        if [ "$dtokens" -gt "$TOKEN_LIMIT" ]; then
            print_info "Directory exceeds token limit: $dir ($dtokens tokens)"
            # Write any pending chunk before handling large directory
            if [ ${#current_chunk_dirs[@]} -gt 0 ]; then
                write_chunk "$chunk_number" "${current_chunk_dirs[@]}" "$current_chunk_tokens"
                ((chunk_number++))
                current_chunk_dirs=()
                current_chunk_tokens=0
            fi
            # Handle the large directory
            write_large_directory "$chunk_number" "$dir" "$i"
            ((chunk_number++))
            continue
        fi
        
        # Regular directory handling
        if [ $(( current_chunk_tokens + dtokens )) -gt "$TOKEN_LIMIT" ] && [ ${#current_chunk_dirs[@]} -gt 0 ]; then
            write_chunk "$chunk_number" "${current_chunk_dirs[@]}" "$current_chunk_tokens"
            ((chunk_number++))
            current_chunk_dirs=()
            current_chunk_tokens=0
        fi
        
        current_chunk_dirs+=("$dir")
        current_chunk_tokens=$(( current_chunk_tokens + dtokens ))
    done

    # Write final chunk if any directories remain
    if [ ${#current_chunk_dirs[@]} -gt 0 ]; then
        write_chunk "$chunk_number" "${current_chunk_dirs[@]}" "$current_chunk_tokens"
    fi
}


# ==========================================================
# 10. Chunk Writing & Large Directory Splits
# ==========================================================
write_chunk() {
    local chunk_number="$1"
    shift  # Remove chunk number from args
    
    # Get total tokens (last argument)
    local total_chunk_tokens="${@: -1}"
    # Remove total tokens from args, leaving only directory list
    set -- "${@:1:$#-1}"
    
    # Now $@ contains only the directory list, safely preserving spaces
    local output_file
    output_file=$(create_output_file "$chunk_number" "chunk") || exit 1
    
    [ "$VERBOSE" = true ] && print_info "Creating chunk $chunk_number with $(($#)) directories"
    
    echo "# Project: $(basename "$PWD")" > "$output_file"
    echo "# Generated: $(date)" >> "$output_file"
    echo "# Chunk: $chunk_number" >> "$output_file"
    echo -e "\n# Complete Repository Structure:" >> "$output_file"
    write_full_directory_structure "$output_file"
    
    echo -e "\n# Current Chunk Contains:" >> "$output_file"
    for dir in "$@"; do
        echo "#   $dir" >> "$output_file"
        [ "$VERBOSE" = true ] && print_info "  Including directory: $dir"
    done
    
    # Validate token count
    if ! [[ "$total_chunk_tokens" =~ ^[0-9]+$ ]] || [ "$total_chunk_tokens" -gt "$TOKEN_LIMIT" ]; then
        print_error "Invalid token count for chunk: $total_chunk_tokens"
        return 1
    fi
    
    echo -e "\n# Total tokens in chunk: ~$total_chunk_tokens" >> "$output_file"
    echo "---" >> "$output_file"

    local chunk_file_count=0
    for dir in "$@"; do
        echo -e "\n## Directory: $dir" >> "$output_file"
        
        # find its index in SCAN_DIR_NAMES
        local found_index=-1
        for ((idx=0; idx<${#SCAN_DIR_NAMES[@]}; idx++)); do
            if [ "${SCAN_DIR_NAMES[idx]}" = "$dir" ]; then
                found_index=$idx
                break
            fi
        done
        
        if [ "$found_index" -ge 0 ]; then
            [ "$VERBOSE" = true ] && print_info "  Processing files from: $dir"
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                ((chunk_file_count++))
                write_file_content "$f" "$output_file"
                [ "$VERBOSE" = true ] && print_info "    Added: $f"
            done <<< "${SCAN_DIR_FILE_LISTS[$found_index]}"
        fi
    done
    
    created_files+=("$output_file")
    print_info "Created chunk $chunk_number: $(basename "$output_file") (tokens: $total_chunk_tokens, files: $chunk_file_count)"
}

write_large_directory() {
    local file_counter="$1"
    local dir="$2"
    local dir_index="$3"  # Changed from file_list to dir_index
    
    print_status "Directory '$dir' exceeds token limit, splitting at file level..."
    
    local sub_tokens=0
    local chunk_subfile_count=0
    local part_file
    part_file=$(create_output_file "$file_counter" "chunk") || exit 1
    
    [ "$VERBOSE" = true ] && print_info "Creating chunk for large directory: $dir"
    
    echo "# Project: $(basename "$PWD")" > "$part_file"
    echo "# Generated: $(date)" >> "$part_file"
    write_full_directory_structure "$part_file"
    echo -e "\n# Splitting Large Directory:" >> "$part_file"
    echo "#   ${dir}" >> "$part_file"
    echo "# Into Multiple Chunks" >> "$part_file"
    echo "---" >> "$part_file"
    
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        local f_tokens
        f_tokens=$(estimate_tokens "$(cat "$f")")
        
        if ! [[ "$f_tokens" =~ ^[0-9]+$ ]]; then
            print_error "Invalid token count for file $f: $f_tokens"
            continue
        fi
        
        if [ $((sub_tokens + f_tokens)) -gt "$TOKEN_LIMIT" ] && [ "$sub_tokens" -gt 0 ]; then
            print_info "Chunk for $dir complete. (tokens: $sub_tokens, files: $chunk_subfile_count)"
            ((file_counter++))
            sub_tokens=0
            chunk_subfile_count=0
            part_file=$(create_output_file "$file_counter" "chunk") || exit 1
            
            [ "$VERBOSE" = true ] && print_info "Creating continuation chunk $file_counter"
            
            echo "# Project: $(basename "$PWD")" > "$part_file"
            echo "# Generated: $(date)" >> "$part_file"
            write_full_directory_structure "$part_file"
            echo -e "\n# Splitting Large Directory (Continued):" >> "$part_file"
            echo "#   ${dir}" >> "$part_file"
            echo "# Chunk $file_counter" >> "$part_file"
            echo "---" >> "$part_file"
        fi
        
        write_file_content "$f" "$part_file"
        sub_tokens=$((sub_tokens + f_tokens))
        ((chunk_subfile_count++))
        [ "$VERBOSE" = true ] && print_info "  Added: $f ($f_tokens tokens)"
        
    done <<< "${SCAN_DIR_FILE_LISTS[$dir_index]}"  # Use file list from global array

    created_files+=("$part_file")
    print_info "Created chunk: $(basename "$part_file") (directory: $dir, files: $chunk_subfile_count, tokens: $sub_tokens)"
}


# ==========================================================
# 11. Processing by Type (Alternative grouping)
# ==========================================================
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

process_by_type() {
    print_status "Processing by file type..."
    
    # We'll just create new files as we switch types or exceed token limits
    local current_file=""
    local current_tokens=0
    local file_counter=1
    local current_type=""
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            local type
            type=$(get_file_type_group "$file")

            local f_tokens
            f_tokens=$(estimate_tokens "$(cat "$file")")

            # If we changed file type or exceeded token limit, start new file
            if [ "$type" != "$current_type" ] || [ $((current_tokens + f_tokens)) -gt "$TOKEN_LIMIT" ]; then
                current_type="$type"
                file_counter=$((file_counter + 1))
                current_file=$(create_output_file "$file_counter" "$type") || exit 1
                current_tokens=0

                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Type: $type" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi

            write_file_content "$file" "$current_file"
            current_tokens=$((current_tokens + f_tokens))
            [ "$VERBOSE" = true ] && echo "Processing: $file (type=$type, tokens=$current_tokens)"
        fi
    done < <(find . -type f | sort)
}


# ==========================================================
# 12. Processing by Size (Token Count)
# ==========================================================
calculate_total_tokens() {
    local total_tokens=0
    local file_count=0
    
    print_status "Analyzing repository size..."
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            ((file_count++))
            total_tokens=$(( total_tokens + $(estimate_tokens "$(cat "$file")") ))
            if [ "$VERBOSE" = true ]; then
                echo "  Scanning: $file"
            fi
        fi
    done < <(find . -type f | sort)
    
    print_info "Found $file_count files totaling approximately $total_tokens tokens"
    echo "$total_tokens"
}

process_by_size() {
    local total_tokens
    total_tokens=$(calculate_total_tokens)
    
    if [ "$total_tokens" -le "$TOKEN_LIMIT" ]; then
        print_status "Repository fits within token limit. Creating single consolidated file..."
        local current_file
        current_file=$(create_output_file "main" "main") || exit 1
        
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
    
    print_status "Repository exceeds token limit. Splitting into multiple files..."
    local current_file=""
    local current_tokens=0
    local file_counter=1
    
    while IFS= read -r -d $'\n' file; do
        if file "$file" | grep -qE '.*:.*text' && matches_patterns "$file"; then
            local f_tokens
            f_tokens=$(estimate_tokens "$(cat "$file")")
            
            if [ $((current_tokens + f_tokens)) -gt "$TOKEN_LIMIT" ] && [ "$current_tokens" -gt 0 ]; then
                print_info "Created: $(basename "$current_file") (tokens: $current_tokens)"
                file_counter=$((file_counter + 1))
                current_file=$(create_output_file "$file_counter" "chunk") || exit 1
                current_tokens=0
                
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Part: $file_counter" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            if [ -z "$current_file" ]; then
                current_file=$(create_output_file "$file_counter" "chunk") || exit 1
                echo "# Project: $(basename "$PWD")" > "$current_file"
                echo "# Part: $file_counter" >> "$current_file"
                echo "# Generated: $(date)" >> "$current_file"
                echo "---" >> "$current_file"
            fi
            
            write_file_content "$file" "$current_file"
            current_tokens=$(( current_tokens + f_tokens ))
            [ "$VERBOSE" = true ] && echo "Processing: $file (tokens=$current_tokens)"
        fi
    done < <(find . -type f | sort)
    
    [ -n "$current_file" ] && print_info "Created: $(basename "$current_file") (tokens: $current_tokens)"
}


# ==========================================================
# 13. Write Full Directory Structure for Context
# ==========================================================
write_full_directory_structure() {
    local output_file="$1"
    
    echo -e "\n# Complete Repository Structure:" >> "$output_file"
    echo "# (showing all directories and files with token counts)" >> "$output_file"
    
    # 1. Find total tokens for root (.) directory
    local root_tokens=0
    local root_index=-1
    for ((i=0; i<${#SCAN_DIR_NAMES[@]}; i++)); do
        if [ "${SCAN_DIR_NAMES[i]}" = "." ]; then
            root_tokens="${SCAN_DIR_TOKEN_COUNTS[i]}"
            root_index=$i
            break
        fi
    done
    
    # 2. Print root directory and its tokens
    echo "# ./ (~${root_tokens} tokens)" >> "$output_file"
    
    # 3. List root directory files (if index found)
    if [ "$root_index" -ge 0 ]; then
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            local f_tokens
            f_tokens=$(estimate_tokens "$(cat "$file")")
            echo "#   └── $(basename "$file") (~$f_tokens tokens)" >> "$output_file"
        done <<< "${SCAN_DIR_FILE_LISTS[$root_index]}"
    fi
    
    # 4. Gather non-root directories
    local all_dirs=()
    for ((i=0; i<${#SCAN_DIR_NAMES[@]}; i++)); do
        if [ "${SCAN_DIR_NAMES[i]}" != "." ]; then
            all_dirs+=("${SCAN_DIR_NAMES[i]}")
        fi
    done
    
    # 5. Sort them for a cleaner, more consistent layout
    IFS=$'\n' sorted_dirs=($(sort <<< "${all_dirs[*]}"))
    unset IFS
    
    # 6. Print subdirectories with indentation + file lists
    for dir in "${sorted_dirs[@]}"; do
        # Safely split directory path and get depth
        local dir_parts
        IFS='/' read -ra dir_parts <<< "$dir"
        local depth=0
        if [ ${#dir_parts[@]} -gt 0 ]; then
            depth=${#dir_parts[@]}
        fi
        
        # Create indent based on depth
        local indent=""
        for ((n=0; n<depth-1; n++)); do
            indent="$indent  "
        done
        
        # Find matching index in SCAN_DIR_NAMES
        local dir_index=-1
        for ((j=0; j<${#SCAN_DIR_NAMES[@]}; j++)); do
            if [ "${SCAN_DIR_NAMES[j]}" = "$dir" ]; then
                dir_index=$j
                break
            fi
        done
        
        # Print subdir's token count (using basename for directory name)
        if [ "$dir_index" -ge 0 ]; then
            echo "# ${indent}$(basename "$dir")/ (~${SCAN_DIR_TOKEN_COUNTS[dir_index]} tokens)" >> "$output_file"
            
            # List each file in that subdirectory
            while IFS= read -r file; do
                [ -z "$file" ] && continue
                local f_tokens
                f_tokens=$(estimate_tokens "$(cat "$file")")
                echo "#   ${indent}└── $(basename "$file") (~$f_tokens tokens)" >> "$output_file"
            done <<< "${SCAN_DIR_FILE_LISTS[$dir_index]}"
        fi
    done
    
    echo -e "#\n# Current Chunk Contains:" >> "$output_file"
}


# ==========================================================
# 14. Summary Reporting
# ==========================================================
print_summary() {
    local total_tokens=0
    local total_files=0
    
    for file in "${created_files[@]}"; do
        local tokens
        tokens=$(grep -m 1 "tokens" "$file" | grep -o "[0-9]\+")
        local file_count
        file_count=$(grep -c "^---$" "$file")
        
        tokens=${tokens:-0}
        file_count=${file_count:-0}
        
        total_tokens=$((total_tokens + tokens))
        total_files=$((total_files + file_count))
    done
    
    echo -e "\nProcessing Summary:"
    echo "Total Tokens: ~$total_tokens"
    echo "Total Files Processed: $total_files"
    echo "Output Files Created: ${#created_files[@]}"
}


# ==========================================================
# 15. Command-Line Argument Parsing
# ==========================================================
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
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

if [[ ! "$TOKEN_LIMIT" =~ ^[0-9]+$ ]] || [ "$TOKEN_LIMIT" -lt 1000 ]; then
    print_error "Token limit must be a positive integer >= 1000"
    exit 1
fi

validate_environment || exit 1
mkdir -p "$OUTPUT_DIR"


# ==========================================================
# 16. Main Execution Flow
# ==========================================================
print_status "Starting Flatty..."
print_info "Output directory: $OUTPUT_DIR"
[ "$VERBOSE" = true ] && print_info "Verbose mode enabled"

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
        print_error "Error: Invalid grouping mode: $GROUP_BY"
        exit 1
        ;;
esac

print_success "Processing complete!"
print_info "Files saved in: $OUTPUT_DIR"

print_success "Created ${#created_files[@]} files:"
for file in "${created_files[@]}"; do
    echo "  📄 $(basename "$file")"
done

print_summary