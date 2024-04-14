-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Set up custom cursor
vim.api.nvim_create_autocmd({ "BufEnter", "TermLeave" }, {
  group = vim.api.nvim_create_augroup("Custom-Cursor", { clear = true }),
  callback = function()
    -- Set cursor colors
    vim.api.nvim_command("highlight Cursor guibg=#aaffcc")
    vim.api.nvim_command("highlight VisualCursor guibg=#cc99cc")
    vim.api.nvim_command("highlight ReplaceCursor guibg=#cc7070")
    -- Apply confs
    vim.opt_local.guicursor = "n-c-ci-cr-sm:block,i:ver30-Cursor,v-ve-o:hor30-VisualCursor,r:hor50-ReplaceCursor"
  end,
})

-- Add terminal transparency
local FloatTransparency = vim.api.nvim_create_augroup("Custom-FloatTransparency", { clear = true })
vim.api.nvim_create_autocmd({ "TermEnter" }, {
  group = FloatTransparency,
  callback = function()
    vim.opt_local.winblend = 0
    vim.opt_local.guicursor = "a:ver30"
  end,
})
vim.api.nvim_create_autocmd({ "TermLeave" }, {
  group = FloatTransparency,
  callback = function()
    vim.opt_local.winblend = 10
  end,
})
