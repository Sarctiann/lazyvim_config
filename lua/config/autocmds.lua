-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Add terminal transparency
local FloatTransparency = vim.api.nvim_create_augroup("Custom-FloatTransparency", { clear = true })
vim.api.nvim_create_autocmd({ "TermEnter" }, {
  group = FloatTransparency,
  callback = function()
    vim.opt_local.winblend = 10
  end,
})

vim.api.nvim_create_autocmd({ "TermLeave" }, {
  group = FloatTransparency,
  callback = function()
    vim.opt_local.winblend = 30
  end,
})

-- Restore the cursor
vim.api.nvim_create_autocmd({ "VimLeave" }, {
  group = vim.api.nvim_create_augroup("Custom-RestoreCursor", { clear = true }),
  callback = function()
    vim.opt_local.guicursor = "a:ver30-blinkon100"
  end,
})
