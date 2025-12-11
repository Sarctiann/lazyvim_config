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

vim.keymap.set("n", "<space>bQ", function()
  Snacks.bufdelete.all()
end, { desc = "Delete all buffers", silent = true })

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

-- maximize toggle (is handled by the plugin)
-- vim.keymap.set("n", "<leader>m", "", { desc = "Minimap options (codewindow)", noremap = false })

vim.keymap.set("n", "<leader>o", "", { desc = "+open", noremap = false })

-- Added keymap to open lazyDocker
vim.keymap.set("n", "<leader>od", function()
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
    ---@diagnostic disable-next-line
    Snacks.terminal("LazyDocker")
  end
end, { desc = "Open LazyDocker (external)" })

vim.keymap.set({ "n", "v" }, "<leader>ct", function()
  local range_start = nil
  local range_end = nil
  local mode = vim.api.nvim_get_mode().mode
  if mode == "V" or mode == "v" or mode == "" then
    range_start = vim.fn.line("'<")
    range_end = vim.fn.line("'>")
  end

  local substitutions = {
    [[s/null/unknown/g]],
    [[s/\v\d+[;,]/number;/g]],
    [[s/\v: '[^']*'[;,]/: string;/g]],
    [[s/\v: "[^"]*"[;,]/: string;/g]],
    [[s/\vfalse|true/boolean/g]],
    [[s/\[\]/Array<unknown>/g]],
    [[s/{}/Record<string, unknown>/g]],
    [[s/\v\[(\_[a-zA-Z]+)\]/Array<\1>/g]],
    [[s/\vconst ([a-zA-Z0-9_]+)/type \1/g]],
  }

  for _, substitution in ipairs(substitutions) do
    local cmd = "silent! "
    if range_start and range_end then
      cmd = cmd .. range_start .. "," .. range_end .. substitution
    else
      cmd = cmd .. "%" .. substitution
    end
    vim.cmd(cmd)
  end

  if range_start and range_end then
    vim.cmd("normal! \\<Esc>")
  end

  vim.notify("JSON to TS types conversion applied", vim.log.levels.INFO)
end, { desc = "Convert JSON to TypeScript types" })

vim.keymap.set("n", "<leader>fC", function()
  local config_path = vim.fn.expand("~/.config/ghostty/config")
  local local_config_path = vim.fn.expand("~/.config/ghostty/local_config")

  local config_exists = vim.fn.bufexists(config_path) ~= 0
  local local_config_exists = vim.fn.bufexists(local_config_path) ~= 0

  if config_exists and local_config_exists then
    local config_bufnr = vim.fn.bufnr(config_path)
    local local_config_bufnr = vim.fn.bufnr(local_config_path)

    if config_bufnr ~= -1 then
      vim.cmd("bwipeout " .. config_bufnr)
    end
    if local_config_bufnr ~= -1 then
      vim.cmd("bwipeout " .. local_config_bufnr)
    end
    vim.notify("Ghostty config files closed", vim.log.levels.INFO)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(config_path))
    vim.cmd("edit " .. vim.fn.fnameescape(local_config_path))
    vim.notify("Ghostty config files opened", vim.log.levels.INFO)
  end
end, { desc = "Toggle Ghostty local config" })

vim.keymap.set("n", "<leader>gm", function()
  local pattern = "^<\\{7\\}\\|^=\\{7\\}\\|^>\\{7\\}"
  vim.fn.setreg("/", pattern)
  vim.fn.search(pattern, "W")
end, { desc = "Next git merge Conflict Marker" })

vim.keymap.set("n", "<leader>gM", function()
  local pattern = "^<\\{7\\}\\|^=\\{7\\}\\|^>\\{7\\}"
  vim.fn.setreg("/", pattern)
  vim.fn.cursor(1, 1)
  vim.fn.search(pattern, "W")
end, { desc = "First git merge Conflict Marker" })
