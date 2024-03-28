-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-t>", "<cmd>Telescope<CR>", { desc = "Open Telescope" })

-- Move Line with arrows ([warp]: Go to settings/features and set left option as Meta).

vim.keymap.set("n", "<M-Down>", "<cmd>m .+1<cr>==", { desc = "Move down" })
vim.keymap.set("n", "<M-Up>", "<cmd>m .-2<cr>==", { desc = "Move up" })

vim.keymap.set("i", "<M-Down>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
vim.keymap.set("i", "<M-Up>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })

vim.keymap.set("v", "<M-Down>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
vim.keymap.set("v", "<M-Up>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

local open_or_create_new_note = function()
  local note_name = string.lower(tostring(os.date("%m-%d-%a")))
  local note_file = "./" .. note_name .. ".md"
  if vim.fn.filereadable(note_file) == 0 then
    vim.fn.writefile({ "# " .. note_name, "", "## " }, note_file)
    print(note_name .. " was created")
  else
    print(note_name .. " already exist, only opening")
  end
  vim.cmd("e " .. note_file)
  vim.cmd("startinsert")
  vim.cmd("normal! G$<cr>")
end

vim.keymap.set("n", "<leader>fm", open_or_create_new_note, { desc = "Open or create Today's md-note" })
