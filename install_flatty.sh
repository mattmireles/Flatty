#!/bin/bash

# Exit on any error
set -e

# Default to paranoid mode if no argument provided
INSTALL_MODE="paranoid"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --quick)
            INSTALL_MODE="quick"
            shift
            ;;
        *)
            echo "🤔 Unknown option: $1"
            echo "Usage: install.sh [--quick]"
            echo "  --quick    Quick install (skips security checks)"
            echo "  (no flag)  Paranoid install (full security checks)"
            exit 1
            ;;
    esac
done

# Define paths
SCRIPT_NAME="flatty.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/flatty/main"
EXPECTED_CHECKSUM="443ecf95a6ab5e22d1d2a72d0193fa78eecce83961cfd7a9ddb3defe53dfac8b"

# Set install location based on mode
if [ "$INSTALL_MODE" = "quick" ]; then
    echo "🏃‍♂️ Living dangerously I see! Quick install mode activated..."
    DESTINATION="$HOME/bin/flatty"
    mkdir -p "$HOME/bin"
else
    echo "🕵️‍♂️ Trust, but verify. Actually, skip the trust part..."
    DESTINATION="/usr/local/bin/flatty"
    sudo mkdir -p "/usr/local/bin"
fi

# Download script
echo "📥 Downloading Flatty..."
TMP_DIR=$(mktemp -d)
DOWNLOAD_PATH="$TMP_DIR/$SCRIPT_NAME"
trap 'rm -rf "$TMP_DIR"' EXIT

if ! curl -fsSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$DOWNLOAD_PATH"; then
    echo "😱 Download failed! Is GitHub having a case of the Mondays?"
    exit 1
fi

# Verify checksum in paranoid mode
if [ "$INSTALL_MODE" = "paranoid" ]; then
    echo "🔍 Verifying download with the thoroughness of a code reviewer before lunch..."
    if ! (echo "$EXPECTED_CHECKSUM  $DOWNLOAD_PATH" | shasum -a 256 -c 2>/dev/null || \
          echo "$EXPECTED_CHECKSUM  $DOWNLOAD_PATH" | sha256sum -c 2>/dev/null); then
        echo "❌ Checksum verification failed! Trust no one, especially not this download."
        exit 1
    fi
    echo "✅ Checksum verified. You can sleep soundly tonight."
fi

# Install the script
chmod +x "$DOWNLOAD_PATH"
echo "📦 Installing to $DESTINATION..."

if [ "$INSTALL_MODE" = "quick" ]; then
    mv "$DOWNLOAD_PATH" "$DESTINATION"
    
    # Add ~/bin to PATH if needed
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$HOME/.bashrc"
        echo "export PATH=\"\$HOME/bin:\$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || true
        echo "📝 Added ~/bin to your PATH. You may need to restart your terminal."
    fi
else
    sudo mv "$DOWNLOAD_PATH" "$DESTINATION"
fi

echo "✨ Success! Flatty is now installed and ready to rock!"
echo "🚀 Run 'flatty' in any directory to flatten it into a text file for LLMs"
echo "📂 Output will be saved to ~/flattened/"