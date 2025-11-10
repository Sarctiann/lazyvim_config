-- NOTE: Singleton terminal for Cursor-Agent
local cursor_agent_term = nil

-- NOTE: Function to open or toggle the Cursor-Agent terminal
local function opern_cursor_cli(cwd)
  if cursor_agent_term then
    cursor_agent_term:toggle()
  else
    cursor_agent_term = Snacks.terminal("cursor-agent", {
      interactive = true,
      cwd = cwd,
      win = {
        on_close = function()
          cursor_agent_term = nil
        end,
        position = "right",
        min_width = 60,
      },
    })
  end
end

-- NOTE: Cursor on the current file's directory
vim.keymap.set("n", "<leader>aj", function()
  local current_dir = vim.fn.expand("%:p:h")
  if current_dir == "" then
    current_dir = vim.fn.getcwd()
  end
  opern_cursor_cli(current_dir)
end, { desc = "Toggle Cursor-Agent (Current Dir)" })

-- NOTE: Cursor on the project root
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
  opern_cursor_cli(root_dir)
end, { desc = "Toggle Cursor-Agent (Project Root)" })

-- NOTE: Hide terminal function
local function hide_term()
  if cursor_agent_term then
    vim.cmd("q")
    cursor_agent_term = nil
  end
end

-- NOTE: Insert newline function
local function insert_newline()
  local bufnr = vim.api.nvim_get_current_buf()
  local job_id = vim.b.terminal_job_id or vim.api.nvim_buf_get_var(bufnr, "terminal_job_id")

  if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
    vim.fn.chansend(job_id, "\n")
  end
end

-- NOTE: Show help function
local function show_help()
  Snacks.notify(
    [[Term Mode:
    · <Esc> : Normal Mode
    · <C-j> : Newline
    · <M-j> : Newline
    ---
    · <M-?> : Show Help
    · ??    : Show Help
    · \\    : Show Help
    ---
    · <C-c> : Stop/Close
    · <C-d> : Close

Norm Mode:
    · q     : Hide
    · <Esc> : Hide

Cursor-Agent commands:
    · quit  : (<CR>) Close Cursor-Agent
    · exit  : (<CR>) Close Cursor-Agent
    ---
    · /     : Show command list
    · @     : Show file list to attach
    · !     : To run in the shell
    ]],
    { title = "keymaps", style = "compact", history = false, timeout = 5000 }
  )
end

local cursor_agent_group = vim.api.nvim_create_augroup("Cursor-Agent", { clear = true })
local cursor_agent_opens_group = vim.api.nvim_create_augroup("Cursor-Agent-Opens", { clear = true })

-- NOTE: Keymaps for the Cursor-Agent terminal
vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter" }, {
  group = cursor_agent_group,
  pattern = "term://*cursor-agent*",
  callback = function()
    local opts = { buffer = 0, silent = true }
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)

    vim.keymap.set("t", "<C-j>", insert_newline, opts)
    vim.keymap.set("t", "<M-j>", insert_newline, opts)

    vim.keymap.set("t", "<M-?>", show_help, opts)
    vim.keymap.set("t", "??", show_help, opts)
    vim.keymap.set("t", "\\\\", show_help, opts)

    vim.keymap.set("n", "<Esc>", hide_term, opts)
  end,
})

-- NOTE: Show help when opening the terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = cursor_agent_opens_group,
  pattern = "term://*cursor-agent*",
  callback = function()
    Snacks.notify(" Press: [<M-?>], [??], or [\\\\] to Show Help ", { title = "", style = "compact", history = false })
  end,
})

return {}
