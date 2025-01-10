#!/bin/bash

# Define the source and destination paths
SCRIPT_NAME="flatty.sh"
DESTINATION="/usr/local/bin/flatty"

# Download the flatty script
curl -O https://raw.githubusercontent.com/mattmireles/flatty/main/$SCRIPT_NAME

# Make the script executable
chmod +x "$SCRIPT_NAME"

# Move the script to /usr/local/bin
sudo mv "$SCRIPT_NAME" "$DESTINATION"

echo "flatty has been installed successfully. You can now flatten any directory it using the command 'flatty'." 