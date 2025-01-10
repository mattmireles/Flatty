# Flatty
Transform any GitHub repo or folder on your computer into a simple text file so that you can upload it an LLM (Claude, ChatGPT, etc.) to reason over the whole thing in the context window.

## Codebase → Text File

LLMs like ChatGPT and Claude let you upload files, but they limit how many you can upload at once. When you're dealing with large codebases that have tons of files, you can't just upload them directly to an LLM. You end up having to use RAG (retrieval augmented generation) techniques, which in my experience aren't as effective as uploading everything into the full context window - especially when you need to reason about architecture or understand the entire system.

## What Flatty Does

Flatty makes it dead simple to flatten all the files in any directory on your computer - including all its subdirectories - into a single text file that you can upload to your LLM of choice (Personally, I ❤️ Claude). Just run the `flatty` command in your terminal and it'll create a neat text file with all your code.

## Smart File Handling

The naive approach would include binary files, audio, images, and other stuff that would blow up the file size without adding value for code analysis. Flatty tries to solve this by intelligently ignoring certain file types.
