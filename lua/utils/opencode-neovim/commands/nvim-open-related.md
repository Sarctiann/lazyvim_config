---
description: Find and open files related to a topic in Neovim splits
---

Find files related to: $ARGUMENTS

Steps:

1. Run the Window Focus Step to ensure a file window is active (not the OpenCode terminal):
   `neovim_vim_command(":lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == '' and bn ~= '' then vim.api.nvim_set_current_win(w) break end end")`
2. Use `neovim_vim_grep` to search for "$ARGUMENTS" across the project.
3. Identify the most relevant files (max 4) based on the results.
4. Open each file with `neovim_vim_file_open`.
5. Arrange them using `neovim_vim_window split` or `vsplit` so the user can see them side by side.
6. Summarize what each file contains and why it's relevant.

If no argument is provided, use `neovim_vim_status` to get the current buffer context and find related files based on that.
If the Neovim MCP is not available, say so clearly.
