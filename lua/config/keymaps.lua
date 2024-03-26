-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-t>", "<cmd>Telescope<CR>", { desc = "Open Telescope" })

-- Move Line (Mac Support).

vim.keymap.set("n", "¶", "<cmd>m .+1<cr>==", { desc = "Move down" })
vim.keymap.set("n", "§", "<cmd>m .-2<cr>==", { desc = "Move up" })

vim.keymap.set("i", "¶", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
vim.keymap.set("i", "§", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })

vim.keymap.set("v", "¶", ":m '>+1<cr>gv=gv", { desc = "Move down" })
vim.keymap.set("v", "§", ":m '<-2<cr>gv=gv", { desc = "Move up" })
