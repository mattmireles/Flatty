#!/bin/bash

# Exit on any error
set -e

# Trap errors and perform cleanup
trap 'echo "An unexpected error occurred. Exiting."; rm -f "$DOWNLOAD_PATH"; exit 1;' ERR

# Define the source and destination paths
SCRIPT_NAME="flatty.sh"
DESTINATION="/usr/local/bin/flatty"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/flatty/main/$SCRIPT_NAME"
CHECKSUM_URL="https://raw.githubusercontent.com/mattmireles/flatty/main/$SCRIPT_NAME.sha256"

echo "Installing Flatty..."

# Function to check dependencies
check_dependencies() {
    for cmd in curl sudo sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: '$cmd' is not installed. Please install '$cmd' and try again."
            exit 1
        fi
    done
}

# Call the function to check dependencies
check_dependencies

# Check if /usr/local/bin exists and is writable
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin directory..."
    sudo mkdir -p /usr/local/bin
fi

# Check if Flatty is already installed
if [ -f "$DESTINATION" ]; then
    read -p "Flatty is already installed. Do you want to overwrite it? (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "Overwriting existing Flatty installation..."
            ;;
        *)
            echo "Installation aborted."
            exit 0
            ;;
    esac
fi

# Create a secure temporary directory
TMP_DIR=$(mktemp -d)
DOWNLOAD_PATH="$TMP_DIR/$SCRIPT_NAME"
CHECKSUM_PATH="$TMP_DIR/$SCRIPT_NAME.sha256"

# Ensure temporary directory is removed on exit
trap 'rm -rf "$TMP_DIR"' EXIT

# Download the Flatty script
echo "Downloading Flatty from GitHub..."
if ! curl -fsSL "$GITHUB_RAW_URL" -o "$DOWNLOAD_PATH"; then
    echo "Error: Failed to download Flatty script"
    exit 1
fi

# Download the checksum
echo "Downloading checksum..."
if ! curl -fsSL "$CHECKSUM_URL" -o "$CHECKSUM_PATH"; then
    echo "Error: Failed to download checksum file"
    exit 1
fi

# Verify checksum
echo "Verifying download integrity..."
cd "$TMP_DIR"
sha256sum -c "$SCRIPT_NAME.sha256" || { echo "Checksum verification failed."; exit 1; }

# Make the script executable
chmod +x "$DOWNLOAD_PATH"

# Move the script to /usr/local/bin
echo "Installing Flatty to $DESTINATION..."
if sudo mv "$DOWNLOAD_PATH" "$DESTINATION"; then
    echo "✅ Flatty has been installed successfully!"
    echo "You can now flatten any directory by navigating to it and running the 'flatty' command."
    echo "The flattened output will be saved to ~/flattened/"
    echo "To uninstall Flatty, run: sudo rm /usr/local/bin/flatty"
else
    echo "Error: Failed to install Flatty"
    exit 1
fi 

# Cleanup is handled by the EXIT trap
