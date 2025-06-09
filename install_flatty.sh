#!/bin/bash

# Exit on any error
# set -e

# Default to paranoid mode if no argument provided
INSTALL_MODE="paranoid"
DEBUG_MODE="false"

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --quick)
            INSTALL_MODE="quick"
            shift
            ;;
        --debug)
            DEBUG_MODE="true"
            shift
            ;;
        *)
            echo "🤔 Unknown option: $1"
            echo "Usage: install.sh [--quick] [--debug]"
            echo "  --quick    Quick install (skips security checks)"
            echo "  --debug    Show debug output"
            echo "  (no flag)  Paranoid install (full security checks)"
            exit 1
            ;;
    esac
done

# Debug function
debug() {
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "$1"
    fi
}

debug "--- SCRIPT EXECUTION STARTED (v2) ---"
debug "DEBUG: Script started"
debug "DEBUG: Current directory: $(pwd)"
debug "DEBUG: Install mode: $INSTALL_MODE"

# Define paths
SCRIPT_NAME="flatty.sh"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/Flatty/main"
CHECKSUM_FILE_URL="$GITHUB_RAW_URL/$SCRIPT_NAME.sha256"

debug "DEBUG: Will download from: $GITHUB_RAW_URL/$SCRIPT_NAME"
debug "DEBUG: Checksum file URL: $CHECKSUM_FILE_URL"

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

debug "DEBUG: Created temp dir: $TMP_DIR"
debug "DEBUG: Will download to: $DOWNLOAD_PATH"

if ! curl -fsSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$DOWNLOAD_PATH"; then
    echo "😱 Download failed! Is GitHub having a case of the Mondays?"
    exit 1
fi

debug "DEBUG: Download complete. File exists: $(test -f "$DOWNLOAD_PATH" && echo "yes" || echo "no")"
debug "DEBUG: File size: $(wc -c < "$DOWNLOAD_PATH") bytes"

# Verify checksum in paranoid mode
if [ "$INSTALL_MODE" = "paranoid" ]; then
    echo "🔍 Verifying download with the thoroughness of a code reviewer before lunch..."
    
    debug "--- DEBUG INFO ---"
    debug "Temp dir: $TMP_DIR"
    debug "Listing files..."
    debug "$(ls -la "$TMP_DIR")"
    
    if ! curl -fsSL "$CHECKSUM_FILE_URL" -o "$TMP_DIR/$SCRIPT_NAME.sha256"; then
        echo "😱 Could not download checksum file!"
        exit 1
    fi
    
    debug "Checksum file downloaded. Listing files again:"
    debug "$(ls -la "$TMP_DIR")"
    debug "Contents of checksum file:"
    debug "$(cat "$TMP_DIR/$SCRIPT_NAME.sha256")"
    debug "--------------------"

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