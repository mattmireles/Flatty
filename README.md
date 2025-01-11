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

This will analyze your project and create text files in `~/flattened/` containing all the text files from your project.

## Smart File Handling

Flatty intelligently skips:
- Binary files and images
- Build artifacts
- Package directories (node_modules, vendor)
- Hidden files and .git
- System files (.DS_Store)

Developed with ❤️ by [TalkTastic](https://talktastic.com/)
