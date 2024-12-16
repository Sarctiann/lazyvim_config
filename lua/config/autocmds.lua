-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Restore the cursor
vim.api.nvim_create_autocmd({ "VimLeave" }, {
  group = vim.api.nvim_create_augroup("Custom-RestoreCursor", { clear = true }),
  callback = function()
    vim.opt_local.guicursor = "a:ver30-blinkon100"
  end,
})

-- Change the color of unused code highlight
vim.api.nvim_create_autocmd({ "DiagnosticChanged" }, {
  group = vim.api.nvim_create_augroup("Custom-ResetUnusedCodeHighlight", { clear = true }),
  callback = function()
    vim.api.nvim_command("highlight! link DiagnosticUnnecessary UnusedCode")
  end,
})
