-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

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

-- floating terminal
--
-- local lazyterm = function()
--   LazyVim.terminal(nil, {
--     cwd = LazyVim.root(),
--     border = "rounded",
--     margin = { top = 3, left = 5, right = 5, bottom = 3 },
--   })
-- end
-- vim.keymap.set("n", "<leader>ft", lazyterm, { desc = "Terminal (Root Dir)" })
-- vim.keymap.set("n", "<leader>fT", function()
--   LazyVim.terminal(nil, {
--     border = "rounded",
--     margin = { top = 3, left = 5, right = 5, bottom = 3 },
--   })
-- end, { desc = "Terminal (cwd)" })
-- vim.keymap.set("n", "<c-/>", lazyterm, { desc = "Terminal (Root Dir)" })
-- vim.keymap.set("n", "<c-_>", lazyterm, { desc = "which_key_ignore" })

-- Remove/Replace some default keymaps

-- maximize toggle (is handled by the plugin)
vim.keymap.set("n", "<leader>m", "", { desc = "Minimap options (codewindow)", noremap = false })

-- Added keymap to open lazyDocker
vim.keymap.set("n", "<leader>d", function()
  local result = ""
  local handle = io.popen([[bash -c 'if ! type "LazyDocker" &> /dev/null; then
      echo "error"
    fi']])
  if handle then
    result = handle:read("*a")
    handle:close()
  end
  if result == "error\n" then
    print("You need to install LazyDocker to use this feature")
  else
    LazyVim.terminal("LazyDocker")
  end
end, { desc = "Open LazyDocker (external)" })

vim.keymap.set({ "n", "v" }, "<leader>ct", function()
  local substitutions = {
    [[%s/null/unknown/g]],
    [[%s/\v\d+[;,]/number;/g]],
    [[%s/\v: '.*'/: string/g]],
    [[%s/\v: "[^"]*"/: string/g]],
    [[%s/\vfalse|true/boolean/g]],
    [[%s/\[\]/Array<unknown>/g]],
    [[%s/{}/Record<string, unknown>/g]],
    [[%s/\v\[(\_.+)\]/Array<\1>/g]],
  }

  for _, substitution in ipairs(substitutions) do
    local cmd = "silent! " .. substitution

    vim.cmd(cmd)
  end
  vim.cmd("normal! \\<Esc>")

  vim.notify("JSON to TS types conversion applied", vim.log.levels.INFO)
end, { desc = "Convert JSON to TypeScript types" })
