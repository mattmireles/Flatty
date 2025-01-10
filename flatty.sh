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

# Set a unique separator
separator="--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--__--"

# Clear and initialize the output file
{
    echo "This is a flattened representation of source files."
    echo "This file contains the most recent version of the source code at the time it was generated."
    echo "This file is intended to be used as a knowledge base for an AI assistant."
    echo "Image files and binary files have been excluded from the text content, but they are included in the tree listing."
    echo "Files are separated by a unique marker: '$separator'"
    echo "The filename is also separated from the file content using the unique marker"
    echo "The date that this file was generated: $(date)"
    echo "$separator"
    echo "File Tree:"

    # File Tree using find
    find . -not -path "./public/*" -not -name ".*" -not -name "*.swp" -not -name "$(basename "$output_file")" -print | sed 's/^\.\///' | sort

    echo "$separator"

    # Loop through all the files, excluding the public folder and images
    while IFS= read -r -d $'\n' file; do
        if [[ ! "$file" =~ ^\./public/ ]] && [[ "$file" != "$output_file" ]]; then
            if file "$file" | grep -qE '.*:.*text'; then
                # remove "./" from filename
                file="${file:2}"
                echo "$separator"
                echo "Filename: $file"
                echo "$separator"
                # Output the content of the file
                cat "$file"
            fi
        fi
    done < <(find . -type f -not -name ".*" -not -name "*.swp")

    echo "$separator"
    echo "End of File"
} > "$output_file"

echo "Analysis complete! Output saved to $output_file"