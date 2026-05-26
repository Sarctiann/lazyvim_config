---
description: Summarize current Neovim editor state (buffer, cursor, LSP, windows)
---

1. Run the Window Focus Step to ensure a file window is active (not the OpenCode terminal):
   `neovim_vim_command(":lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == '' and bn ~= '' then vim.api.nvim_set_current_win(w) break end end")`
2. Call `neovim_vim_status` to get the current Neovim session state.
3. Call `neovim_vim_buffer` to read the active buffer content.

Summarize:

- Active file and cursor position
- Current mode and any visual selection
- Attached LSP clients (from `lspInfo` field)
- Open windows and their layout
- Any relevant marks or registers

If the Neovim MCP is not available, say so clearly.
