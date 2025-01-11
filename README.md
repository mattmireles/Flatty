# Flatty - Codebase-to-Text for LLMs

Transform any GitHub repo or folder on your Mac into a simple text file so that you can upload it to an LLM (Claude, ChatGPT, etc.) to reason over the whole thing in the context window.

## Codebase → Text File(s)

LLMs like ChatGPT and Claude let you upload files, but they limit how many you can upload at once. When you're dealing with large codebases that have tons of files, you can't just upload them directly to an LLM. You end up having to use RAG (retrieval augmented generation) techniques, which in my experience aren't as effective as uploading everything into the full context window - especially when you need to reason about architecture or understand the entire system. See [example](https://github.com/mattmireles/Flatty/blob/main/flatty-2025-01-10_12-57-33.txt).

Coding assistants like Cursor are amazeballs, but they work better for day-to-day code completion and inline edits than they do for higher-level system understanding. 

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

This will analyze your project and create appropriately-sized text files in `~/flattened/` containing all the text files from your project.

### Smart Size Management

Flatty automatically handles projects of any size:
- Small projects (under 100k tokens) → single consolidated file
- Large projects → smart splitting based on directory structure
- Very large files → automatic chunking with clear continuation markers

### Command Options

```
flatty [options] [patterns...]

Options:
    -o, --output-dir DIR     Output directory (default: ~/flattened)
    -g, --group-by MODE      Grouping mode:
                            directory  - Group by directory structure (default)
                            type      - Group by file type
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
   - Preserves directory structure in output
   - Keeps related files together
   - Shows clear token counts per directory
   - Perfect for understanding project organization

2. **Type-based**:
   ```bash
   flatty --group-by type
   ```
   - Groups similar file types together
   - Great for language-specific analysis
   - Categories: python, javascript, golang, ruby, java, c, cpp, swift, objective-c, html, css, docs, config, other

3. **Size-based**:
   ```bash
   flatty --group-by size -t 50000
   ```
   - Creates evenly-sized chunks
   - Best for specific token limits
   - Clear part numbers and continuation markers

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

1. **Smart Size Analysis**
   - Analyzes total project size first
   - Uses single file for small projects
   - Automatically splits larger projects
   - Handles directories exceeding token limits

2. **Clean Organization**
   - Directory structure preservation
   - Token count tracking
   - Clear file boundaries
   - Detailed headers with context

3. **Intelligent Filtering**
   - Automatic text file detection
   - Binary/image exclusion
   - Configurable patterns
   - Common ignore paths (node_modules, .git, etc.)

The output includes helpful metadata:
```
# Project: my-project
# Generated: 2025-01-09 21:55:33
# Directory: src/components
# Total Tokens: ~95000
---
Complete Repository Structure:
  src/
    components/ (~45000 tokens)
    utils/ (~30000 tokens)
    tests/ (~20000 tokens)
---
[file contents follow...]
```

## Output Organization

Files are saved with descriptive names:
```
~/flattened/
  project-name-2025-01-09_21-55-33.txt           # Single file for small projects
  project-name-2025-01-09_21-55-33-part1-src.txt # Directory-based split
  project-name-2025-01-09_21-55-33-part2-lib.txt
  project-name-2025-01-09_21-55-33-swift.txt     # Type-based grouping
  project-name-2025-01-09_21-55-33-cpp.txt
```

## Smart File Handling

Flatty intelligently skips:
- Binary files and images
- Build artifacts
- Package directories (node_modules, vendor)
- Hidden files and .git
- System files (.DS_Store)

Developed with ❤️ by [TalkTastic](https://talktastic.com/)
