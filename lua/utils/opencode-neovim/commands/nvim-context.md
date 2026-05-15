---
description: Summarize current Neovim editor state (buffer, cursor, LSP, windows)
---

Call `neovim_vim_status` to get the current Neovim session state, then call `neovim_vim_buffer` to read the active buffer content. Summarize:

- Active file and cursor position
- Current mode and any visual selection
- Attached LSP clients (from `lspInfo` field)
- Open windows and their layout
- Any relevant marks or registers

If the Neovim MCP is not available, say so clearly.
