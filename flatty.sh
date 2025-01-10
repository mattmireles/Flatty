#!/bin/bash

# Exit on any error
set -e

# Create the "flattened" directory in the user's home folder if it doesn't exist
output_dir="$HOME/flattened"
mkdir -p "$output_dir"

# Get current directory name and date
current_dir=$(basename "$(pwd)")
current_date=$(date +%Y%m%d-%H%M%S)
output_file="${output_dir}/${current_dir}-${current_date}-flattened.txt"

separator="=================="

# Configuration flags
INCLUDE_BUILD_FILES=1     # Include key build configuration files
INCLUDE_DEPENDENCIES=1    # Include package manager configurations
INCLUDE_COMMENTS=1        # Keep meaningful comments in source files
INCLUDE_STRUCTURE=1       # Include folder structure analysis

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Warning: Not in a git repository root. Script should be run from project root."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Clear output file
> "$output_file"

# Project Overview Section
echo "# Project Structure Analysis" >> "$output_file"
echo "Generated: $(date)" >> "$output_file"
echo "$separator" >> "$output_file"

# Generate structured overview
if [ "$INCLUDE_STRUCTURE" -eq 1 ]; then
    echo "## Directory Structure" >> "$output_file"
    # Show meaningful structure while excluding noise
    find . -type d \
        -not -path "*/\.*" \
        -not -path "*/DerivedData/*" \
        -not -path "*/Build/*" \
        -not -path "*/Pods/*" \
        -not -path "*/xcuserdata/*" \
        | sed 's/[^-][^\/]*\//  │   /g' \
        | sed 's/│   \([^│]\)/├── \1/' >> "$output_file"
    echo "$separator" >> "$output_file"
fi

# Process source files
process_source_file() {
    local file="$1"
    echo "## File: $file" >> "$output_file"
    
    # Extract file type specific information
    case "$file" in
        *.swift)
            # Extract class/struct definitions and protocol conformance
            grep -E '^[[:space:]]*(class|struct|enum|protocol|extension)' "$file" >> "$output_file" 2>/dev/null || true
            if [ "$INCLUDE_COMMENTS" -eq 1 ]; then
                # Extract documentation comments (///), but skip routine comments (//)
                grep -E '^\s*///' "$file" >> "$output_file" 2>/dev/null || true
            fi
            ;;
        *.h)
            # Extract interface definitions and public API
            grep -E '^@(interface|protocol|property|public|private)' "$file" >> "$output_file" 2>/dev/null || true
            ;;
        Package.swift)
            # Include entire dependency specification
            cat "$file" >> "$output_file"
            ;;
        *.xcconfig)
            # Include build configurations
            grep -v '^\s*//' "$file" >> "$output_file" 2>/dev/null || true
            ;;
    esac
    echo "$separator" >> "$output_file"
}

# Find and process relevant files
find . -type f \( \
    -name "*.swift" \
    -o -name "*.h" \
    -o -name "*.m" \
    -o -name "Package.swift" \
    -o -name "*.xcconfig" \
    \) \
    -not -path "*/DerivedData/*" \
    -not -path "*/Build/*" \
    -not -path "*/Pods/*" \
    -not -path "*/\.*" \
    | while read -r file; do
        process_source_file "$file"
    done

# Include dependency management files if enabled
if [ "$INCLUDE_DEPENDENCIES" -eq 1 ]; then
    echo "## Dependencies" >> "$output_file"
    for file in Package.swift Package.resolved Podfile Podfile.lock; do
        if [ -f "$file" ]; then
            echo "### $file" >> "$output_file"
            cat "$file" >> "$output_file"
            echo "$separator" >> "$output_file"
        fi
    done
fi

echo "Analysis complete! Output saved to $output_file"