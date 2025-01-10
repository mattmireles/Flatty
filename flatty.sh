#!/bin/bash

# Exit on any error
set -e

# Initialize variables
OUTPUT_DIR="$HOME/flattened"
TMP_DIR="/tmp/flatty_$$"
MAX_SIZE_MB=${MAX_SIZE_MB:-10}
VERBOSE=${VERBOSE:-false}

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install it first:"
    echo "  brew install jq"
    exit 1
fi

# Create necessary directories
mkdir -p "$OUTPUT_DIR" "$TMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
    [ "$VERBOSE" = true ] && echo "Cleaned up temporary files"
}
trap cleanup EXIT

# Helper function to detect file type
detect_file_type() {
    case "$1" in
        *.py) echo "python";;
        *.js) echo "javascript";;
        *.jsx) echo "jsx";;
        *.ts) echo "typescript";;
        *.tsx) echo "tsx";;
        *.go) echo "go";;
        *.rb) echo "ruby";;
        *.php) echo "php";;
        *.java) echo "java";;
        *.scala) echo "scala";;
        *.kt|*.kts) echo "kotlin";;
        *.swift) echo "swift";;
        *.c|*.h) echo "c";;
        *.cpp|*.hpp|*.cc) echo "cpp";;
        *.cs) echo "csharp";;
        *.rs) echo "rust";;
        *.sh|*.bash) echo "shell";;
        *.html|*.htm) echo "html";;
        *.css) echo "css";;
        *.md|*.markdown) echo "markdown";;
        *.json) echo "json";;
        *.xml) echo "xml";;
        *.yml|*.yaml) echo "yaml";;
        *.txt) echo "text";;
        *) echo "text";;  # Default to text for unknown types
    esac
}

# Helper function to detect MIME type and handle binary files
get_file_info() {
    local file="$1"
    local mime_type
    local file_type
    local category
    local size
    
    # Get MIME type using file command
    mime_type=$(file --mime-type -b "$file")
    size=$(stat -f%z "$file")
    
    # Categorize file
    case "$mime_type" in
        text/*|application/json|application/xml|application/x-yaml)
            category="text"
            file_type=$(detect_file_type "$file")
            ;;
        image/*)
            category="image"
            file_type="${mime_type#image/}"
            ;;
        audio/*)
            category="audio"
            file_type="${mime_type#audio/}"
            ;;
        video/*)
            category="video"
            file_type="${mime_type#video/}"
            ;;
        application/pdf)
            category="document"
            file_type="pdf"
            ;;
        application/*)
            category="binary"
            file_type="${mime_type#application/}"
            ;;
        *)
            category="other"
            file_type="unknown"
            ;;
    esac
    
    # Output JSON structure
    cat << EOF
    {
      "path": "${file:2}",
      "category": "$category",
      "type": "$file_type",
      "mime_type": "$mime_type",
      "size": $size$([ "$category" = "text" ] && echo ',
      "content": '"$(python3 -c "import json, sys; print(json.dumps(sys.stdin.read()))" < "$file")")
    }
EOF
}

# Function to generate type statistics
generate_type_stats() {
    local input_file="$1"
    local total=0
    local stats=""
    
    # Calculate stats for each category
    for category in text binary image audio video document other; do
        local count
        count=$(jq -r ".files[] | select(.category == \"$category\") | .path" "$input_file" | wc -l | tr -d ' ')
        total=$((total + count))
        stats="${stats}      \"$category\": $count,
"
    done
    
    # Output the type_stats section
    cat << EOF
  "type_stats": {
    "by_category": {
${stats}      "total": $total
    }
  }
EOF
}

# Main processing with enhanced file handling
generate_json() {
    local project_name=$(basename "$(pwd)")
    local output_file="${OUTPUT_DIR}/${project_name}-$(date +%Y%m%d-%H%M%S).json"
    local total_files=0
    
    # Start JSON structure
    cat << EOF > "$output_file"
{
  "metadata": {
    "name": "$project_name",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "generator": {
      "name": "flatty",
      "version": "1.0.0"
    }
  },
EOF

    # Files section
    echo '  "files": [' >> "$output_file"
    
    # Process all files
    local first_file=true
    while IFS= read -r -d $'\n' file; do
        ((total_files++))
        
        # Skip unwanted paths and files
        if [[ "$file" =~ ^\./\. ]] || \
           [[ "$file" =~ ^\./(node_modules|venv|target|build|dist)/ ]]; then
            continue
        fi
        
        # Add comma for all but first file
        [ "$first_file" = true ] || echo "    ," >> "$output_file"
        first_file=false
        
        # Get and write file info
        get_file_info "$file" >> "$output_file"
        
    done < <(find . -type f)
    
    # Close files array and add stats
    echo "  ]," >> "$output_file"
    generate_type_stats "$output_file" >> "$output_file"
    echo "}" >> "$output_file"
    
    echo "✨ Analysis complete! Output saved to $output_file"
    
    # Show summary
    echo "📊 File Categories:"
    for category in text binary image audio video document other; do
        count=$(jq -r ".type_stats.by_category.$category" "$output_file")
        printf "%s: %d\n" "$category" "$count"
    done
    printf "Total: %d\n" "$(jq -r '.type_stats.by_category.total' "$output_file")"
}

# Main execution
generate_json