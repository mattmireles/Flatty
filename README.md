# Flatty - Codebase-to-Text for LLMs

Transform any GitHub repo or folder on your Mac into a simple text file so that you can upload it to an LLM (Claude, ChatGPT, etc.) to reason over the whole thing in the context window.

## Codebase → Text File(s)

LLMs like ChatGPT and Claude let you upload files, but they limit how many you can upload at once. When you're dealing with large codebases that have tons of files, you can't just upload them directly to an LLM. You end up having to use RAG (retrieval augmented generation) techniques, which in my experience aren't as effective as uploading everything into the full context window - especially when you need to reason about architecture or understand the entire system. See [example](https://github.com/mattmireles/Flatty/blob/main/flatty-2025-01-10_12-57-33.txt).

Coding assistants like Cursor are amazeballs, but they work better for day-to-day code completion and inline edits than they do for higher-level system understanding. 

## Features

- **Comprehensive File Flattening:** Converts entire codebases into structured text files suitable for LLMs.
- **Smart File Handling:** Intelligently skips binary files, images, build artifacts, package directories, hidden files, and system files.
- ****🎉 **Pattern-Based Filtering:** **Enhance your flattening process by selectively including files based on specific code patterns or keywords in both file content and filenames. Customize your inclusion criteria using `AND`/`OR` conditions to target exactly what you need for focused analysis.**

## Installation

Choose your adventure:

### 🏃‍♂️ Quick Install (Easy mode)
```bash
curl -fsSL https://raw.githubusercontent.com/mattmireles/flatty/main/install_flatty.sh | bash -s -- --quick
```
### 🕵️‍♂️ Paranoid Install (Extra security checks)
```bash
curl -fsSL https://raw.githubusercontent.com/mattmireles/flatty/main/install_flatty.sh | bash
```

The paranoid install (default) includes checksum verification and full security checks. Quick install skips these checks for the "I like to live dangerously" crowd.

## Usage

Basic usage is stupidly simple:

```bash
cd your-project-directory
flatty
```

This creates a nicely formatted text file in `~/Documents/flatty/` containing all your project's text files, ready for LLM consumption.

### Pattern-Based Filtering

Take control of what gets included in your flattened output by specifying patterns and conditions. This feature allows you to focus on specific parts of your codebase, improving efficiency and relevance.

**Command-Line Arguments:**

- `--pattern "pattern1"`: Specify a pattern or keyword to filter files. You can use multiple `--pattern` flags for multiple patterns.
- `--condition AND|OR`: Define how multiple patterns should be matched.
  - `AND`: All specified patterns must be present in a file (either in the filename or content).
  - `OR`: Any one of the specified patterns must be present.

**Examples:**

1. **Include files containing either `useEffect` or `async function`:**

    ```bash
    flatty --pattern "useEffect" --pattern "async function" --condition OR
    ```

2. **Include files containing both `useEffect` and `async function`:**

    ```bash
    flatty --pattern "useEffect" --pattern "async function" --condition AND
    ```

3. **Include files with `README` in the filename:**

    ```bash
    flatty --pattern "README" --condition OR
    ```

4. **Default behavior without patterns (includes all eligible text files):**

    ```bash
    flatty
    ```

**Behavior:**

- **OR Condition:** Files are included if **any** of the specified patterns are found in the filename or file content.
- **AND Condition:** Files are included only if **all** of the specified patterns are found in the filename or file content.
- **No Patterns Specified:** Defaults to including all eligible text files, maintaining the original behavior.

## Smart File Handling

Flatty intelligently skips:
- Binary files and images
- Build artifacts
- Package directories (`node_modules`, `vendor`)
- Hidden files and `.git`
- System files (`.DS_Store`)

## Output

Flattened text files are saved in the `~/flattened/` directory with filenames formatted as:

```
<project-name>-v<version>-<timestamp>.txt
```

Each output file includes:
- Project information and metadata
- Complete repository structure with directories and file token counts
- Contents of each included text file, separated by defined separators

## Development

Developed with ❤️ by [TalkTastic](https://talktastic.com/)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.

### Git Hooks

To maintain the integrity of the `flatty.sh` script and ensure that the checksum file (`flatty.sh.sha256`) is always up-to-date, contributors should set up a pre-commit Git hook. This hook automatically generates and updates the checksum before each commit.

**Steps to Set Up the Pre-Commit Hook:**

1. **Navigate to the Git Hooks Directory:**

    ```bash
    cd .git/hooks
    ```

2. **Create or Edit the `pre-commit` Hook:**

    ```bash
    cursor pre-commit
    ```

3. **Add the Following Script to the `pre-commit` File:**

    ```bash
    #!/bin/bash

    # Generate SHA256 checksum for flatty.sh
    sha256sum flatty.sh > flatty.sh.sha256

    # Add the checksum file to the commit
    git add flatty.sh.sha256
    ```

4. **Make the Hook Executable:**

    ```bash
    chmod +x pre-commit
    ```

**Explanation:** This hook ensures that every time `flatty.sh` is modified and a commit is made, the corresponding `flatty.sh.sha256` checksum file is automatically updated and included in the commit. This maintains the integrity verification process for the installation script.
## License

[MIT](https://opensource.org/licenses/MIT)

