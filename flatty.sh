#!/bin/bash
#
# Flatty - Convert directories into LLM-friendly text files
# https://github.com/mattmireles/flatty

set -e  # Exit on error

# Configuration
OUTPUT_DIR="$HOME/flattened"
TOKEN_LIMIT=100000
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

# Temporary files
TEMP_DIR=$(mktemp -d)
FILE_LIST="$TEMP_DIR/files.txt"
DIR_LIST="$TEMP_DIR/dirs.txt"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Helper Functions
print_error() {
    echo "❌ Error: $1" >&2
}

print_status() {
    echo "→ $1"
}

# Basic file filtering
is_text_file() {
    local file="$1"
    case "$file" in
        *.git/*|*.DS_Store|*node_modules/*|*venv/*|*__pycache__/*|*dist/*|*build/*) return 1 ;;
        *.py|*.js|*.jsx|*.ts|*.tsx|*.rb|*.php|*.java|*.go|\
        *.c|*.cpp|*.h|*.hpp|*.swift|*.m|*.cs|*.sh|*.pl|\
        *.html|*.css|*.scss|*.less|\
        *.json|*.yaml|*.yml|*.toml|*.ini|*.env|\
        *.md|*.txt|*.rst) return 0 ;;
        *) return 1 ;;
    esac
}

# Find all valid text files and their token counts
scan_files() {
    print_status "Scanning files..."
    
    > "$FILE_LIST"  # Clear file list
    > "$DIR_LIST"   # Clear directory list
    local total_tokens=0
    
    # Add current directory to DIR_LIST
    echo "." >> "$DIR_LIST"
    
    while IFS= read -r -d '' file; do
        if is_text_file "$file"; then
            local size=$(wc -c < "$file" | tr -d '[:space:]')
            local tokens=$((size / 4))
            echo "$file:$tokens" >> "$FILE_LIST"
            total_tokens=$((total_tokens + tokens))
            dirname "$file" >> "$DIR_LIST"
        fi
    done < <(find . -type f -print0)
    
    echo "$total_tokens"
}

# Show directory structure with token counts
show_structure() {
    local total_tokens="$1"
    echo -e "\nRepository Structure:"
    
    # Get unique directories with their token counts
    sort -u "$DIR_LIST" | while read -r dir; do
        local dir_tokens=0
        grep "^$dir/" "$FILE_LIST" | cut -d: -f2 | while read -r tokens; do
            dir_tokens=$((dir_tokens + tokens))
        done
        local indent=$(($(echo "$dir" | tr -cd '/' | wc -c) * 2))
        printf "%${indent}s%s (~%d tokens)\n" "" "${dir##*/}/" "$dir_tokens"
    done
    
    echo -e "\nTotal tokens: ~$total_tokens"
}

# Generate the output file
generate_output() {
    mkdir -p "$OUTPUT_DIR"
    local output="$OUTPUT_DIR/$(basename "$PWD")-$TIMESTAMP.txt"
    
    print_status "Generating output..."
    
    # Write header with detailed structure
    {
        echo "# Project: $(basename "$PWD")"
        echo "# Generated: $(date)"
        echo ""
        echo "# Complete Repository Structure:"
        echo "# (showing all directories and files with token counts)"
        
        # Print root directory
        local root_tokens=0
        grep "^\./" "$FILE_LIST" | cut -d: -f2 | while read -r tokens; do
            root_tokens=$((root_tokens + tokens))
        done
        echo "# ./ (~$root_tokens tokens)"
        
        # Print root files
        grep "^\./" "$FILE_LIST" | while IFS=: read -r file tokens; do
            echo "#   └── $(basename "$file") (~$tokens tokens)"
        done
        
        # Print directories and their files
        sort -u "$DIR_LIST" | grep -v "^\.$" | while read -r dir; do
            local dir_tokens=0
            grep "^$dir/" "$FILE_LIST" | cut -d: -f2 | while read -r tokens; do
                dir_tokens=$((dir_tokens + tokens))
            done
            local depth=$(($(echo "$dir" | tr -cd '/' | wc -c)))
            local indent=$(printf '%*s' $((depth * 2)) '')
            echo "#   $indent$(basename "$dir")/ (~$dir_tokens tokens)"
            
            # Print files in this directory
            grep "^$dir/" "$FILE_LIST" | while IFS=: read -r file tokens; do
                echo "#   $indent  └── $(basename "$file") (~$tokens tokens)"
            done
        done
        echo "#"
        echo "---"
    } > "$output"
    
    # Write files
    while IFS=: read -r file tokens; do
        {
            echo "---"
            echo "$file"
            echo "---"
            cat "$file"
            echo ""
        } >> "$output"
    done < "$FILE_LIST"
    
    print_status "Output written to: $(basename "$output")"
}

# Main execution
main() {
    if [ ! -d "." ]; then
        print_error "Not a directory"
        exit 1
    fi
    
    # Create temp directory for processing
    mkdir -p "$TEMP_DIR"
    
    # Scan repository
    total_tokens=$(scan_files)
    
    # Show structure
    show_structure "$total_tokens"
    
    # Generate output
    if [ -s "$FILE_LIST" ]; then
        generate_output
        print_status "Processing complete!"
    else
        print_error "No text files found"
        exit 1
    fi
}

main "$@"