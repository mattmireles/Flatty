#!/bin/bash

set -e  # Exit on error

# Initialize variables for patterns and condition
PATTERNS=()
CONDITION="OR"

# Function to display usage
usage() {
    echo "Usage: $0 [--pattern \"pattern1\" --pattern \"pattern2\" ...] [--condition AND|OR]"
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --pattern)
            PATTERNS+=("$2")
            shift 2
            ;;
        --condition)
            CONDITION="$2"
            if [[ "$CONDITION" != "AND" && "$CONDITION" != "OR" ]]; then
                echo "Condition must be either AND or OR."
                usage
            fi
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
done

# Get version information from Git
get_version_info() {
    # Check if git command exists first
    if ! command -v git >/dev/null 2>&1; then
        echo "dev-$(date +'%Y%m%d')"
        return
    fi

    # Check if we're in a Git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "dev-$(date +'%Y%m%d')"
        return
    fi

    # Get the latest tag and commit hash
    local git_tag
    git_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    local git_hash
    git_hash=$(git rev-parse --short HEAD)
    local git_dirty
    git_dirty=$(git status --porcelain 2>/dev/null | grep -q . && echo "-dirty" || echo "")

    if [ -n "$git_tag" ]; then
        # If we have a tag, use it along with commit hash
        echo "${git_tag}-${git_hash}${git_dirty}"
    else
        # If no tag exists, just use commit hash
        echo "${git_hash}${git_dirty}"
    fi
}

VERSION=$(get_version_info)

# Configuration
OUTPUT_DIR="$HOME/flattened"
TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
SEPARATOR="---"

# Create output directory
mkdir -p "$OUTPUT_DIR"
output_file="$OUTPUT_DIR/$(basename "$PWD")-v${VERSION}-${TIMESTAMP}.txt"

# Comprehensive file filtering
is_text_file() {
    local file="$1"
    case "$file" in
        # First check exclusions
        *.git/*|*.DS_Store|*node_modules/*|*venv/*|*__pycache__/*|*dist/*|*build/*|\
        *.swp|*.swo|*.swn|*.pyc|*.pyo|*.rbc|*.yarb|*.o|*.obj|*.exe|*.dll|*.so|*.dylib|\
        *.class|*.jar|*.war|*.ear|*.zip|*.tar|*.gz|*.rar|*.7z|*/.idea/*|*/.vscode/*) 
            return 1 ;;
        
        # Then check known text file types
        *.py|*.js|*.jsx|*.ts|*.tsx|*.rb|*.php|*.java|*.go|\
        *.c|*.cpp|*.h|*.hpp|*.swift|*.m|*.cs|*.sh|*.pl|\
        *.html|*.css|*.scss|*.less|\
        *.json|*.yaml|*.yml|*.toml|*.ini|*.env|\
        *.md|*.txt|*.rst|*.xml|*.sql|*.conf|\
        *.gradle|*.properties|*.plist|*.pbxproj|Makefile|Dockerfile)
            return 0 ;;
            
        # For unknown extensions, check if it's text
        *) file "$file" | grep -qE '.*:.*text' ;;
    esac
}

# Simple token estimation
estimate_tokens() {
    local size
    size=$(wc -c < "$1" | tr -d '[:space:]')
    echo $((size / 4))
}

# Helper function to check excluded directories
is_excluded_dir() {
    local dir="$1"
    case "$dir" in
        *.git|*.git/*|*node_modules|*node_modules/*|*venv|*venv/*|*__pycache__|*__pycache__/*|\
        *dist|*dist/*|*build|*build/*|*.idea|*.idea/*|*.vscode|*.vscode/*)
            return 0 ;;
        *) return 1 ;;
    esac
}

# Function to determine if a file matches the patterns based on condition
matches_patterns() {
    local file="$1"
    local content_matches=0
    local name_matches=0

    # Check filename patterns
    for pattern in "${PATTERNS[@]}"; do
        if [[ "$(basename "$file")" == *"$pattern"* ]]; then
            name_matches=1
            break
        fi
    done

    # Check content patterns if it's a text file
    if is_text_file "$file"; then
        for pattern in "${PATTERNS[@]}"; do
            if grep -q "$pattern" "$file"; then
                content_matches=1
                break
            fi
        done
    fi

    if [ "${#PATTERNS[@]}" -eq 0 ]; then
        return 0
    fi

    if [ "$CONDITION" == "AND" ]; then
        # All patterns must match
        for pattern in "${PATTERNS[@]}"; do
            if [[ "$(basename "$file")" != *"$pattern"* ]] && (! grep -q "$pattern" "$file"); then
                return 1
            fi
        done
        return 0
    else
        # Any pattern matches
        if [ "$name_matches" -eq 1 ] || [ "$content_matches" -eq 1 ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Clear output file and write header
{
    echo "# Project: $(basename "$PWD")"
    echo "# Flatty Version: ${VERSION}"
    echo "# Generated: $(date)"
    echo "# Generator: flatty (https://github.com/yourusername/flatty)"
    echo ""
    echo "# Complete Repository Structure:"
    echo "# (showing all directories and files with token counts)"
    
    # First list directories with token counts
    find . -type d | sort | while read -r dir; do
        # Skip excluded directories
        if is_excluded_dir "$dir"; then
            continue
        fi
        
        # Count total tokens in this directory
        total_tokens=0
        while IFS= read -r file; do
            if [ -f "$file" ] && is_text_file "$file"; then
                # Apply pattern filtering
                if matches_patterns "$file"; then
                    tokens=$(estimate_tokens "$file")
                    total_tokens=$((total_tokens + tokens))
                fi
            fi
        done < <(find "$dir" -maxdepth 1 -type f)
        
        # Print directory even if empty (but skip excluded ones)
        depth=$(($(echo "$dir" | tr -cd '/' | wc -c)))
        indent=$(printf '%*s' $((depth * 2)) '')
        echo "#$indent${dir#.}/ (~$total_tokens tokens)"
        
        # Print files in this directory if it has any text files
        if [ "$total_tokens" -gt 0 ]; then
            while IFS= read -r file; do
                if [ -f "$file" ] && is_text_file "$file"; then
                    if matches_patterns "$file"; then
                        tokens=$(estimate_tokens "$file")
                        echo "#$indent  └── $(basename "$file") (~$tokens tokens)"
                    fi
                fi
            done < <(find "$dir" -maxdepth 1 -type f | sort)
        fi
    done
    
    echo "#"
    echo "$SEPARATOR"
} > "$output_file"

# Append each text file with separators
find . -type f | sort | while read -r file; do
    if is_text_file "$file"; then
        if matches_patterns "$file"; then
            {
                echo "$SEPARATOR"
                echo "${file#./}"
                echo "$SEPARATOR"
                cat "$file"
                echo ""
            } >> "$output_file"
        fi
    fi
done

echo "$SEPARATOR" >> "$output_file"
echo "Processing complete! Output saved to: $output_file"
