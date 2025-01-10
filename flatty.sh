#!/bin/bash

# ---------------------------------------
# Flatty - Convert directories into LLM-friendly text files
# ---------------------------------------

# Exit on any error and failed pipes
set -e
set -o pipefail

# ---------------------------------------
# Helper Functions: Output & Logging
# ---------------------------------------

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

# ---------------------------------------
# Environment Validation
# ---------------------------------------

validate_environment() {
    # Check for empty directory
    if [ -z "$(find . -type f -print -quit)" ]; then
        print_error "No files found in directory"
        exit 1
    }

    # Validate output directory
    if [ ! -w "$(dirname "$OUTPUT_DIR")" ]; then
        print_error "Cannot write to output directory location: $OUTPUT_DIR"
        exit 1
    }

    # Check for required tools
    for cmd in find grep sed tr wc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
}

# ---------------------------------------
# Error Handling & Cleanup
# ---------------------------------------

# Error handler for unexpected failures
handle_error() {
    local line_no=$1
    local error_code=$2
    echo "❌ Error on line ${line_no}: Command exited with status ${error_code}"
    exit 1
}
trap 'handle_error ${LINENO} $?' ERR

# Array for tracking files that need cleanup
declare -a cleanup_files=()

cleanup() {
    local exit_code=$?
    
    # Clean up any temporary files
    if [ ${#cleanup_files[@]} -gt 0 ]; then
        print_status "Cleaning up temporary files..."
        for file in "${cleanup_files[@]}"; do
            [ -f "$file" ] && rm -f "$file"
        done
    fi
    
    # Handle non-zero exit
    if [ $exit_code -ne 0 ]; then
        print_error "Process failed with exit code $exit_code"
        # Could add additional cleanup here
    fi
    
    exit $exit_code
}

trap cleanup EXIT
trap 'exit 1' INT TERM

# ---------------------------------------
# Main Script Logic (argument parsing, etc.)
# ---------------------------------------

# Default configuration values
OUTPUT_DIR="$HOME/flattened"
SEPARATOR="---"
TOKEN_LIMIT=100000
GROUP_BY="directory"  # directory, type, or size
VERBOSE=false

# Array to track created files
declare -a created_files=()

# Default exclude patterns for common non-source directories
DEFAULT_EXCLUDES=("*.git/*" "*.DS_Store" "*node_modules/*" "*.swiftpm/*")

# Parse arguments...
