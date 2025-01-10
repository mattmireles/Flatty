# Flatty

Transform any GitHub repo or folder on your Mac into a simple text file so that you can upload it to an LLM (Claude, ChatGPT, etc.) to reason over the whole thing in the context window.

## Codebase → Text File

LLMs like ChatGPT and Claude let you upload files, but they limit how many you can upload at once. When you're dealing with large codebases that have tons of files, you can't just upload them directly to an LLM. You end up having to use RAG (retrieval augmented generation) techniques, which in my experience aren't as effective as uploading everything into the full context window - especially when you need to reason about architecture or understand the entire system.

## Installation

You can install Flatty using the provided installer script:

```bash
curl -fsSL https://raw.githubusercontent.com/mattmireles/flatty/main/install_flatty.sh | bash
```

This will:
1. Download the latest version of Flatty
2. Install it to `/usr/local/bin/flatty`
3. Make it executable and available system-wide

## Usage

Basic usage is as simple as:

```bash
cd your-project-directory
flatty
```

This will create flattened text files in `~/flattened/` containing all the text files from your project.

### Command Options

```
flatty [options] [patterns...]

Options:
    -o, --output-dir DIR     Output directory (default: ~/flattened)
    -g, --group-by MODE      Grouping mode:
                            directory  - Group by directory structure (default)
                            type       - Group by file type
                            size      - Evenly split by token count
    -i, --include PATTERN    Include only files matching pattern
    -x, --exclude PATTERN    Exclude files matching pattern
    -t, --tokens LIMIT       Target token limit per file (default: 100000)
    -v, --verbose           Show detailed progress
    -h, --help              Show this help message
```

### Pattern Matching

Flatty uses shell-style glob patterns for including and excluding files:

```bash
# Only process Swift and Objective-C files
flatty -i "*.swift" -i "*.h" -i "*.m"

# Process all files except tests
flatty -x "*test*" -x "*spec*"

# Combine includes and excludes
flatty -i "*.py" -x "*_test.py"
```

### Grouping Modes

Flatty offers three ways to organize your files:

1. **Directory-based** (default):
   ```bash
   flatty --group-by directory
   ```
   - Preserves directory structure
   - Creates new files when changing directories or hitting token limit
   - Best for understanding project organization

2. **Type-based**:
   ```bash
   flatty --group-by type
   ```
   - Groups similar file types together (e.g., all Swift files)
   - Useful for language-specific analysis
   - Automatically categorizes into: python, javascript, golang, ruby, java, c, cpp, swift, objective-c, html, css, docs, config, other

3. **Size-based**:
   ```bash
   flatty --group-by size -t 50000
   ```
   - Splits files evenly by token count
   - Perfect for LLMs with specific context window sizes
   - Ensures no file exceeds token limit

### Examples

```bash
# Basic usage - process current directory
flatty

# Process specific file types with custom output directory
flatty -o "./flattened" -i "*.swift" -i "*.h"

# Group by file type with verbose output
flatty --group-by type -v

# Create 50k token chunks for smaller context windows
flatty --group-by size -t 50000

# Process everything except tests and generate docs
flatty -x "*_test*" -x "*spec*" -x "doc/*"
```

## How It Works

Flatty intelligently processes your codebase:

1. **Smart Filtering**: Only includes text files, automatically ignoring binaries, images, and other non-text content

2. **Token Management**: Estimates tokens (roughly 4 characters per token) to keep files within LLM context window limits

3. **File Organization**: Creates structured output with clear separators and headers showing:
   - Project name
   - Generation timestamp
   - File paths or grouping information
   - Original file content

4. **Error Handling**: Exits gracefully on errors, preserving your original files

The output files are saved with timestamps and descriptive names, making it easy to manage multiple runs:

```
~/flattened/
  project-name-2025-01-09_02-33-33-1-src.txt
  project-name-2025-01-09_02-33-33-2-tests.txt
  ...
```

## Smart File Handling

The naive approach would include binary files, audio, images, and other stuff that would blow up the file size without adding value for code analysis. Flatty tries to solve this by intelligently ignoring certain file types.