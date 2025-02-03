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
DESTINATION="/usr/local/bin/flatty"
GITHUB_RAW_URL="https://raw.githubusercontent.com/mattmireles/flatty/main"
EXPECTED_CHECKSUM="443ecf95a6ab5e22d1d2a72d0193fa78eecce83961cfd7a9ddb3defe53dfac8b"

# Welcome message based on mode
case $INSTALL_MODE in
    quick)
        echo "🏃‍♂️ Living dangerously I see! Quick install mode activated..."
        ;;
    paranoid)
        echo "🕵️‍♂️ Trust, but verify. Actually, skip the trust part..."
        echo "Initiating paranoid installation mode..."
        ;;
esac

# Dependency checks with friendly messages
if ! command -v curl >/dev/null 2>&1; then
    echo "😅 Hmm... looks like curl is missing. I'd download it for you, but... well... chicken and egg problem 🐔"
    echo "Try: "
    echo "  macOS: brew install curl"
    echo "  Ubuntu/Debian: sudo apt-get install curl"
    echo "  Fedora: sudo dnf install curl"
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "🤔 sudo not found. Either you're not a sudoer, or this is getting really interesting..."
    exit 1
fi

# Permission and directory checks
if [ ! -w "/usr/local/bin" ] && [ ! -w "/usr/local" ]; then
    echo "🔐 Permission denied. Your computer seems to be playing hard to get."
    echo "Try running with sudo, like this:"
    echo "  curl -fsSL $GITHUB_RAW_URL/install_flatty.sh | sudo bash"
    exit 1
fi

# Create /usr/local/bin if needed
if [ ! -d "/usr/local/bin" ]; then
    echo "📁 Creating /usr/local/bin directory..."
    sudo mkdir -p /usr/local/bin
fi

# Handle existing installation
if [ -f "$DESTINATION" ]; then
    echo "🤨 Looks like Flatty is already installed. Updating to the latest version..."
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
DOWNLOAD_PATH="$TMP_DIR/$SCRIPT_NAME"
trap 'rm -rf "$TMP_DIR"' EXIT

# Download script
echo "📥 Downloading Flatty..."
if ! curl -fsSL "$GITHUB_RAW_URL/$SCRIPT_NAME" -o "$DOWNLOAD_PATH"; then
    echo "😱 Download failed! Is GitHub having a case of the Mondays?"
    exit 1
fi

# Verify checksum if in paranoid mode
verify_checksum() {
    local file="$1"
    local expected="$2"
    local actual=""

    if command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | cut -d' ' -f1)
    elif command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | cut -d' ' -f1)
    else
        echo "⚠️ No checksum tools found. Living life on the edge!"
        return 0
    fi

    if [ "$actual" = "$expected" ]; then
        echo "✅ Checksum verified. You can sleep soundly tonight."
        return 0
    else
        return 1
    fi
}

if [ "$INSTALL_MODE" = "paranoid" ]; then
    echo "🔍 Verifying download with the thoroughness of a code reviewer before lunch..."
    if ! verify_checksum "$DOWNLOAD_PATH" "$EXPECTED_CHECKSUM"; then
        echo "❌ Checksum verification failed! Trust no one, especially not this download."
        echo "Expected: $EXPECTED_CHECKSUM"
        exit 1
    fi
fi

# Make executable and install
chmod +x "$DOWNLOAD_PATH"
echo "📦 Installing to $DESTINATION..."
if sudo mv "$DOWNLOAD_PATH" "$DESTINATION"; then
    echo "✨ Success! Flatty is now installed and ready to rock!"
    echo "🚀 Run 'flatty' in any directory to flatten it for LLMs"
    echo "📂 Output will be saved to ~/flattened/"
else
    echo "💥 Installation failed. Murphy's law strikes again!"
    exit 1
fi