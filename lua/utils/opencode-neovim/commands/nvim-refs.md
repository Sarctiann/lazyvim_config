---
description: Find all LSP references for the symbol under cursor and show in quickfix
---

1. Run the Window Focus Step to ensure a file window is active (not the OpenCode terminal):
   `neovim_vim_command(":lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == '' and bn ~= '' then vim.api.nvim_set_current_win(w) break end end")`
2. Call `neovim_vim_status` to get the current cursor position and confirm an LSP client is attached (check `lspInfo` field).
3. Run `neovim_vim_command` with `":lua vim.lsp.buf.references()"` to populate the quickfix list with all references.
4. Run `neovim_vim_command` with `":copen"` to show the quickfix list.
5. Run `neovim_vim_command` with `":lua print(vim.fn.json_encode(vim.fn.getqflist()))"` and summarize: how many references, which files and lines.

If no LSP client is attached (lspInfo shows "LSP information unavailable"), fall back to `neovim_vim_grep` using the word under the cursor from `neovim_vim_status`.
If the Neovim MCP is not available, say so clearly.
