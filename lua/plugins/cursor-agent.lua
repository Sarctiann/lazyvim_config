-- Cursor on the current file's directory
local cursor_agent_term = nil
vim.keymap.set("n", "<leader>aj", function()
  local current_dir = vim.fn.expand("%:p:h")
  if current_dir == "" then
    current_dir = vim.fn.getcwd()
  end
  if cursor_agent_term then
    cursor_agent_term:toggle()
  else
    cursor_agent_term = Snacks.terminal("cursor-agent", {
      interactive = true,
      cwd = current_dir,
      win = {
        on_close = function()
          cursor_agent_term = nil
        end,
        position = "right",
        min_width = 60,
      },
    })
  end
end, { desc = "Toggle Cursor-Agent (Current Dir)" })

-- Cursor on the project root
vim.keymap.set("n", "<leader>aJ", function()
  local current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")

  local root_patterns = {
    ".git",
    ".gitignore",
  }
  local root_dir = vim.fs.find(root_patterns, {
    path = current_file,
    upward = true,
  })[1]

  if root_dir then
    root_dir = vim.fn.fnamemodify(root_dir, ":h")
  else
    root_dir = current_dir ~= "" and current_dir or vim.fn.getcwd()
  end

  if cursor_agent_term then
    cursor_agent_term:toggle()
  else
    cursor_agent_term = Snacks.terminal("cursor-agent", {
      interactive = true,
      cwd = root_dir,
      win = {
        on_close = function()
          cursor_agent_term = nil
        end,
        position = "right",
        min_width = 60,
      },
    })
  end
end, { desc = "Toggle Cursor-Agent (Project Root)" })

local function close_term()
  if cursor_agent_term then
    vim.cmd("q")
    cursor_agent_term = nil
  end
end

-- Handle terminal mode keymaps for cursor-agent terminal buffers
vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter" }, {
  pattern = "term://*cursor-agent*",
  callback = function()
    local opts = { buffer = 0, silent = true }
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)
    vim.keymap.set("t", "<C-c>", [[<C-\><C-n>]], opts)
    vim.keymap.set("t", "<C-d>", [[<C-\><C-n>]], opts)
    vim.keymap.set("n", "<Esc>", close_term, opts)
    vim.keymap.set("n", "<C-c>", close_term, opts)
    vim.keymap.set("n", "<C-d>", close_term, opts)
  end,
})

return {}
