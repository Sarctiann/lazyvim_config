-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Set up custom cursor
vim.api.nvim_create_autocmd({ "VimEnter", "GUIEnter", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("Custom-Cursor", { clear = true }),
  callback = function()
    -- Set cursor colors
    vim.api.nvim_command("highlight Cursor guibg=#aaff70")
    vim.api.nvim_command("highlight ReplaceCursor guibg=#cc7070")
    vim.api.nvim_command("highlight VisualCursor guibg=#cc99cc")
    -- Apply confs
    vim.opt_local.cursorline = false
    vim.opt_local.guicursor = "n-c-ci-cr-sm:block,i:ver30-Cursor,v-ve-o:hor30-VisualCursor,r:hor50-ReplaceCursor"
  end,
})
