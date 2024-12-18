-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.relativenumber = false

-- Set cursor colors
vim.api.nvim_command("highlight CursorL guibg=#9ece6a")
vim.api.nvim_command("highlight VisualCursor guibg=#bb9af7")
vim.api.nvim_command("highlight ReplaceCursor guibg=#f7768e")

-- minimap colors
vim.api.nvim_set_hl(0, "CodewindowBorder", { bg = "#000e15" })
vim.api.nvim_set_hl(0, "CodewindowBackground", { bg = "#000e15" })

-- Set a new color group for unused code
vim.api.nvim_set_hl(0, "UnusedCode", { fg = "NONE", bg = "#004050" })

-- Apply confs
vim.opt_local.guicursor =
  "n-c-ci-cr-sm:block,i:ver30-CursorL,v-ve-o:hor30-VisualCursor,r:hor50-ReplaceCursor,a:Blinkon100"

-- Set colorcolumn
vim.opt.colorcolumn = "80"

-- Spanish and English spell check for Markdown.
vim.opt.spelllang = "en_us,es"

-- Add Transparency to floating windows
vim.opt.winblend = 10
