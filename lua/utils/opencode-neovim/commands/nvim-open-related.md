---
description: Find and open files related to a topic in Neovim splits
---

Find files related to: $ARGUMENTS

Steps:

1. Use vim_grep to search for "$ARGUMENTS" across the project.
2. Identify the most relevant files (max 4) based on the results.
3. Open each file with vim_file_open.
4. Arrange them using vim_window split or vsplit so the user can see them side by side.
5. Summarize what each file contains and why it's relevant.

If no argument is provided, use vim_status to get the current buffer context and find related files based on that.
If the Neovim MCP is not available, say so clearly.
