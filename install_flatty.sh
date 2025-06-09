#!/bin/bash

# Exit on any error
# set -e

echo "--- SCRIPT EXECUTION STARTED (v2) ---"

echo "DEBUG: Script started"
echo "DEBUG: Current directory: $(pwd)"

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

echo "DEBUG: Install mode: $INSTALL_MODE"

# Define paths
SCRIPT_NAME="flatty.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/flatty/main"
CHECKSUM_FILE_URL="$GITHUB_RAW_URL/$SCRIPT_NAME.sha256"

echo "DEBUG: Will download from: $GITHUB_RAW_URL/$SCRIPT_NAME"
echo "DEBUG: Checksum file URL: $CHECKSUM_FILE_URL"

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
echo "DEBUG: Created temp dir: $TMP_DIR"
DOWNLOAD_PATH="$TMP_DIR/$SCRIPT_NAME"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "DEBUG: Will download to: $DOWNLOAD_PATH"
if ! curl -fsSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$DOWNLOAD_PATH"; then
    echo "😱 Download failed! Is GitHub having a case of the Mondays?"
    exit 1
fi
echo "DEBUG: Download complete. File exists: $(test -f "$DOWNLOAD_PATH" && echo "yes" || echo "no")"
echo "DEBUG: File size: $(wc -c < "$DOWNLOAD_PATH") bytes"

# Verify checksum in paranoid mode
if [ "$INSTALL_MODE" = "paranoid" ]; then
    echo "🔍 Verifying download with the thoroughness of a code reviewer before lunch..."
    
    echo "--- DEBUG INFO ---"
    echo "Temp dir: $TMP_DIR"
    echo "Listing files..."
    ls -la "$TMP_DIR"
    
    if ! curl -fsSL "$CHECKSUM_FILE_URL" -o "$TMP_DIR/$SCRIPT_NAME.sha256"; then
        echo "😱 Could not download checksum file!"
        exit 1
    fi
    
    echo "Checksum file downloaded. Listing files again:"
    ls -la "$TMP_DIR"
    echo "Contents of checksum file:"
    cat "$TMP_DIR/$SCRIPT_NAME.sha256"
    echo "--------------------"

    # Run the check from inside the temp dir
    if ! (cd "$TMP_DIR" && shasum -a 256 -c "$SCRIPT_NAME.sha256" 2>/dev/null || \
          cd "$TMP_DIR" && sha256sum -c "$SCRIPT_NAME.sha256" 2>/dev/null); then
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