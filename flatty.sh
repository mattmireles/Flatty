#!/bin/bash
#
# Flatty - Convert directories into LLM-friendly text files
# https://github.com/mattmireles/flatty
#
# Exit on errors, unset variables, and pipeline failures
set -euo pipefail

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

# ==========================================================
# Directory Scanning
# ==========================================================
declare -A dir_tokens=()  # Directory to token count mapping
declare -A dir_files=()   # Directory to file list mapping

scan_directory() {
    print_status "Analyzing repository structure..."
    
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
        
        # Update directory stats
        dir_tokens["$dir_path"]=$((${dir_tokens["$dir_path"]:-0} + tokens))
        dir_files["$dir_path"]="${dir_files["$dir_path"]:-}$file"$'\n'
        total_tokens=$((total_tokens + tokens))
    done < <(find . -type f -print0)
    
    echo "$total_tokens"  # Return total token count
}

# ==========================================================
# User Interface
# ==========================================================
show_directory_structure() {
    echo -e "\nRepository Structure:"
    
    # Sort directories for consistent output
    local sorted_dirs=($(printf "%s\n" "${!dir_tokens[@]}" | sort))
    
    for dir in "${sorted_dirs[@]}"; do
        local tokens=${dir_tokens["$dir"]}
        local indent=$(($(echo "$dir" | tr -cd '/' | wc -c) * 2))
        printf "%${indent}s%s (~%'d tokens)\n" "" "${dir##*/}/" "$tokens"
    done
    
    echo -e "\nTotal tokens: ~$1"
}

get_user_selection() {
    local sorted_dirs=($(printf "%s\n" "${!dir_tokens[@]}" | sort))
    local num_dirs=${#sorted_dirs[@]}
    
    echo -e "\nSelect directories to process:"
    
    for ((i=0; i<num_dirs; i++)); do
        local dir="${sorted_dirs[$i]}"
        local tokens=${dir_tokens["$dir"]}
        echo "$((i+1)). $dir (~$tokens tokens)"
    done
    
    echo -e "\nEnter numbers to include (e.g., \"1 2 3\"), or \"all\" for everything: "
    read -r selection
    
    if [[ "$selection" == "all" ]]; then
        echo "${sorted_dirs[*]}"
    else
        local result=""
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && ((num > 0 && num <= num_dirs)); then
                result+="${sorted_dirs[$((num-1))]} "
            fi
        done
        echo "$result"
    fi
}

# ==========================================================
# Output Generation
# ==========================================================
generate_output() {
    local dirs=("$@")
    local output_file="${OUTPUT_DIR}/$(basename "$PWD")-${TIMESTAMP}.txt"
    
    # Create output directory if needed
    mkdir -p "$OUTPUT_DIR"
    
    # Write header
    {
        echo "# Project: $(basename "$PWD")"
        echo "# Generated: $(date)"
        echo "# Total Directories: ${#dirs[@]}"
        echo ""
        echo "# Repository Structure:"
        
        # Show complete structure for context
        for dir in "${!dir_tokens[@]}"; do
            local tokens=${dir_tokens["$dir"]}
            echo "#   $dir/ (~$tokens tokens)"
        done
        
        echo -e "\n# Included in this file:"
        for dir in "${dirs[@]}"; do
            echo "#   $dir/ (~${dir_tokens["$dir"]} tokens)"
        done
        echo "---"
    } > "$output_file"
    
    # Process selected directories
    for dir in "${dirs[@]}"; do
        echo -e "\n## Directory: $dir" >> "$output_file"
        
        # Read file list for this directory
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            {
                echo "---"
                echo "$file"
                echo "---"
                cat "$file"
                echo ""
            } >> "$output_file"
        done <<< "${dir_files["$dir"]}"
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
        selected_dirs=(${!dir_tokens[@]})
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