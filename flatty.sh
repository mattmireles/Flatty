#!/bin/bash
#
# Flatty - Convert directories into LLM-friendly text files
# https://github.com/mattmireles/flatty
#
# Exit on errors and pipeline failures
set -eo pipefail

# ==========================================================
# Configuration
# ==========================================================
OUTPUT_DIR="$HOME/flattened"
TOKEN_LIMIT=100000
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

# Common paths to skip
SKIP_PATTERNS=(
    ".git/"
    "node_modules/"
    "venv/"
    ".venv/"
    "__pycache__/"
    "dist/"
    "build/"
    ".next/"
    ".DS_Store"
)

# Text file extensions we care about
TEXT_EXTENSIONS=(
    # Code
    "py" "js" "jsx" "ts" "tsx" "rb" "php" "java" "go"
    "c" "cpp" "h" "hpp" "swift" "m" "cs" "sh" "pl"
    # Web
    "html" "css" "scss" "less"
    # Config
    "json" "yaml" "yml" "toml" "ini" "env"
    # Docs
    "md" "txt" "rst" "markdown"
)

# ==========================================================
# Parallel Arrays for Directory Data (bash 3.2 compatible)
# ==========================================================
DIRS=()           # Directory paths
DIR_TOKENS=()     # Token counts
DIR_FILES=()      # File lists (newline-separated)

# ==========================================================
# Helper Functions
# ==========================================================
print_error() {
    echo "❌ Error: $1" >&2
}

print_status() {
    echo "→ $1"
}

should_process_file() {
    local file="$1"
    
    # Check against skip patterns
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            return 1
        fi
    done
    
    # Check file extension
    local ext="${file##*.}"
    for valid_ext in "${TEXT_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$valid_ext" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Find index of directory in our arrays
get_dir_index() {
    local search_dir="$1"
    local i
    for ((i=0; i<${#DIRS[@]}; i++)); do
        if [[ "${DIRS[$i]}" == "$search_dir" ]]; then
            echo "$i"
            return 0
        fi
    done
    echo "-1"
}

# Add or update directory information
update_dir_info() {
    local dir="$1"
    local tokens="$2"
    local file="$3"
    
    local idx
    idx=$(get_dir_index "$dir")
    
    if [[ $idx -eq -1 ]]; then
        # New directory
        DIRS+=("$dir")
        DIR_TOKENS+=($tokens)
        DIR_FILES+=("$file"$'\n')
    else
        # Update existing directory
        DIR_TOKENS[$idx]=$((DIR_TOKENS[$idx] + tokens))
        DIR_FILES[$idx]+="$file"$'\n'
    fi
}

# ==========================================================
# Directory Scanning
# ==========================================================
scan_directory() {
    # Print status to stderr so it won't be captured by command substitution
    print_status "Analyzing repository structure..." >&2
    
    local total_tokens=0
    
    while IFS= read -r -d '' file; do
        # Skip if we shouldn't process this file
        should_process_file "$file" || continue
        
        # Get directory path
        local dir_path
        dir_path=$(dirname "$file")
        
        # Count tokens (rough estimate: chars/4)
        local chars
        chars=$(wc -c < "$file" | tr -d '[:space:]')
        local tokens=$((chars / 4))
        
        # Update directory info
        update_dir_info "$dir_path" "$tokens" "$file"
        total_tokens=$((total_tokens + tokens))
        
    done < <(find . -type f -print0)
    
    echo "$total_tokens"  # This goes to stdout
}

# ==========================================================
# User Interface
# ==========================================================
show_directory_structure() {
    echo -e "\nRepository Structure:"
    
    # Sort directories for consistent output
    local i
    for ((i=0; i<${#DIRS[@]}; i++)); do
        local indent=$(($(echo "${DIRS[$i]}" | tr -cd '/' | wc -c) * 2))
        printf "%${indent}s%s (~%'d tokens)\n" "" "${DIRS[$i]##*/}/" "${DIR_TOKENS[$i]}"
    done
    
    echo -e "\nTotal tokens: ~$1"
}

get_user_selection() {
    echo -e "\nSelect directories to process:"
    
    local i
    for ((i=0; i<${#DIRS[@]}; i++)); do
        echo "$((i+1)). ${DIRS[$i]} (~${DIR_TOKENS[$i]} tokens)"
    done
    
    echo -e "\nEnter numbers to include (e.g., \"1 2 3\"), or \"all\" for everything: "
    read selection
    
    if [[ "$selection" == "all" ]]; then
        echo "${DIRS[*]}"
    else
        local result=""
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num > 0 && num <= ${#DIRS[@]})); then
                result+="${DIRS[$((num-1))]} "
            fi
        done
        echo "$result"
    fi
}

# ==========================================================
# Output Generation
# ==========================================================
generate_output() {
    local selected=($@)
    local output_file="${OUTPUT_DIR}/$(basename "$PWD")-${TIMESTAMP}.txt"
    
    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"
    
    # Write header
    {
        echo "# Project: $(basename "$PWD")"
        echo "# Generated: $(date)"
        echo "# Total Directories: ${#selected[@]}"
        echo ""
        echo "# Repository Structure:"
        
        # Show complete structure for context
        local i
        for ((i=0; i<${#DIRS[@]}; i++)); do
            echo "#   ${DIRS[$i]}/ (~${DIR_TOKENS[$i]} tokens)"
        done
        
        echo -e "\n# Included in this file:"
        for dir in "${selected[@]}"; do
            local idx=$(get_dir_index "$dir")
            [[ $idx -ne -1 ]] && echo "#   $dir/ (~${DIR_TOKENS[$idx]} tokens)"
        done
        echo "---"
    } > "$output_file"
    
    # Process selected directories
    for dir in "${selected[@]}"; do
        local idx=$(get_dir_index "$dir")
        if [[ $idx -ne -1 ]]; then
            echo -e "\n## Directory: $dir" >> "$output_file"
            
            # Process files for this directory
            while IFS= read -r file; do
                [ -z "$file" ] && continue
                {
                    echo "---"
                    echo "$file"
                    echo "---"
                    cat "$file"
                    echo ""
                } >> "$output_file"
            done <<< "${DIR_FILES[$idx]}"
        fi
    done
    
    print_status "Output written to: $(basename "$output_file")"
}

# ==========================================================
# Main Execution
# ==========================================================
main() {
    # Validate current directory
    if [ ! -d "." ]; then
        print_error "Not a directory"
        exit 1
    fi
    
    # Scan repository
    local total_tokens
    total_tokens=$(scan_directory)
    
    # Show structure
    show_directory_structure "$total_tokens"
    
    # If we're over the token limit, let user select dirs
    if [ "$total_tokens" -gt "$TOKEN_LIMIT" ]; then
        echo -e "\nTotal size exceeds ${TOKEN_LIMIT} token limit."
        selected_dirs=($(get_user_selection))
    else
        # Under limit, process everything
        selected_dirs=(${DIRS[@]})
    fi
    
    # Generate output
    if [ ${#selected_dirs[@]} -gt 0 ]; then
        generate_output "${selected_dirs[@]}"
        print_status "Processing complete!"
    else
        print_error "No directories selected"
        exit 1
    fi
}

# Run main and handle errors
main "$@"