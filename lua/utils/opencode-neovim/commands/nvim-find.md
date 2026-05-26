---
description: Search project with vim_grep and show results in quickfix list
---

1. Run the Window Focus Step to ensure a file window is active (not the OpenCode terminal):
   `neovim_vim_command(":lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == '' and bn ~= '' then vim.api.nvim_set_current_win(w) break end end")`
2. Use `neovim_vim_grep` to search for the pattern: $ARGUMENTS

After the search:

3. Run `neovim_vim_command` with `":copen"` to show the quickfix list in Neovim
4. Summarize the results: how many matches, which files, notable patterns

If no pattern is provided, ask the user what to search for.
If the Neovim MCP is not available, say so clearly.
