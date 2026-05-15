---
description: Search project with vim_grep and show results in quickfix list
---

Use `neovim_vim_grep` to search for the pattern: $ARGUMENTS

After the search:

1. Run `neovim_vim_command` with `":copen"` to show the quickfix list in Neovim
2. Summarize the results: how many matches, which files, notable patterns

If no pattern is provided, ask the user what to search for.
If the Neovim MCP is not available, say so clearly.
