#!/bin/bash

# Exit on any error
set -e

# Define the source and destination paths
SCRIPT_NAME="flatty.sh"
DESTINATION="/usr/local/bin/flatty"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/flatty/main/$SCRIPT_NAME"

echo "Installing flatty..."

# Check if /usr/local/bin exists and is writable
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin directory..."
    sudo mkdir -p /usr/local/bin
fi

# Download the flatty script
echo "Downloading flatty from GitHub..."
if ! curl -fsSL "$GITHUB_RAW_URL" -o "/tmp/$SCRIPT_NAME"; then
    echo "Error: Failed to download flatty script"
    exit 1
fi

# Make the script executable
chmod +x "/tmp/$SCRIPT_NAME"

# Move the script to /usr/local/bin
echo "Installing flatty to $DESTINATION..."
if sudo mv "/tmp/$SCRIPT_NAME" "$DESTINATION"; then
    echo "✅ flatty has been installed successfully!"
    echo "You can now flatten any directory by navigating to it and running the 'flatty' command."
    echo "The flattened output will be saved to ~/flattened/"
else
    echo "Error: Failed to install flatty"
    rm -f "/tmp/$SCRIPT_NAME"
    exit 1
fi 