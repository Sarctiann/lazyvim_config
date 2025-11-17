-- NOTE: Singleton terminal for Cursor-Agent
local cursor_agent_term = nil
local term_buf = nil
local working_dir = nil
local current_file = nil

-- NOTE: Insert text into the terminal
local function insert_text(text)
  if term_buf then
    local job_id = vim.b.terminal_job_id or vim.api.nvim_buf_get_var(term_buf, "terminal_job_id")

    if job_id and vim.fn.jobwait({ job_id }, 10)[1] == -1 then
      vim.fn.chansend(job_id, text)
    end
  end
end

-- NOTE: Attach current file to the terminal when cursor_agent is ready
local function attech_file_when_cursor_is_ready(file_path, tries)
  vim.defer_fn(function()
    tries = tries or 0
    local max_tries = 12

    if tries >= max_tries or not term_buf then
      return
    end

    local buf_lines = vim.api.nvim_buf_get_lines(term_buf, 0, 5, false)

    -- NOTE: Check if line 2 matches " Cursor Agent"
    if buf_lines[2] and buf_lines[2]:match(" Cursor Agent") then
      insert_text("@" .. file_path .. "\n\n")
      return
    end

    -- NOTE: Recursively retry after 300ms
    attech_file_when_cursor_is_ready(file_path, tries + 1)
  end, 300)
end

-- NOTE: Function to open or toggle the Cursor-Agent terminal
local function open_cursor_cli(args, keep_open)
  if cursor_agent_term and cursor_agent_term.toggle then
    cursor_agent_term:toggle()
  else
    local cmd = args and " " .. args or ""
    local current_file_abs = vim.fn.expand("%:p")

    local base_dir = working_dir or vim.fn.getcwd()
    current_file = vim.fn.expand("%")
    if base_dir and base_dir ~= "" then
      current_file = vim.fs.relpath(base_dir, current_file_abs) or vim.fn.fnamemodify(current_file_abs, ":.")
    end

    cursor_agent_term = Snacks.terminal("cursor-agent" .. cmd, {
      interactive = true,
      cwd = base_dir,
      win = {
        title = " Cursor-Agent " .. (args and " ( " .. args .. " ) " or ""),
        position = keep_open and "float" or "right",
        min_width = keep_open and nil or 60,
        border = "rounded",
        on_close = function()
          cursor_agent_term = {}
        end,
        resize = true,
      },
      auto_close = not keep_open,
      start_insert = not keep_open,
      auto_insert = not keep_open,
    })
    if cursor_agent_term.buf ~= term_buf then
      attech_file_when_cursor_is_ready(current_file)
    end
    term_buf = cursor_agent_term.buf
  end
end

-- NOTE: Cursor on the current file's directory
local function open_cursor_cwd()
  working_dir = vim.fn.expand("%:p:h")

  if working_dir == "" then
    working_dir = vim.fn.getcwd()
  end
  open_cursor_cli("--browser --approve-mcps")
end

-- NOTE: Cursor on the project root (git root)
local function open_cursor_git_root()
  current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")

  working_dir = vim.fs.find({ ".git" }, {
    path = current_file,
    upward = true,
  })[1]

  if working_dir then
    working_dir = vim.fn.fnamemodify(working_dir, ":h")
  else
    working_dir = current_dir ~= "" and current_dir or vim.fn.getcwd()
  end
  open_cursor_cli("--browser --approve-mcps")
end

-- NOTE: Show sessions function
local function open_cursor_show_sessions()
  current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")

  working_dir = vim.fs.find({ ".git" }, {
    path = current_file,
    upward = true,
  })[1]

  if working_dir then
    working_dir = vim.fn.fnamemodify(working_dir, ":h")
  else
    working_dir = current_dir ~= "" and current_dir or vim.fn.getcwd()
  end
  local custom_cmd = "ls"
  open_cursor_cli(custom_cmd)
end

-- NOTE: Get paths of all open buffers
local function get_open_buffers_paths()
  local buffers = vim.api.nvim_list_bufs()
  local paths = {}

  local exclude_patterns = {
    "//",
    "neo-tree",
  }

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)

      local should_exclude = false
      for _, pattern in ipairs(exclude_patterns) do
        if buf_name:match(pattern) then
          should_exclude = true
          break
        end
      end

      if buf_name ~= "" and not should_exclude then
        local file_path = vim.fn.fnamemodify(buf_name, ":p")
        if file_path ~= "" then
          if working_dir and working_dir ~= "" then
            file_path = vim.fs.relpath(working_dir, file_path) or vim.fn.fnamemodify(file_path, ":.")
          end
          table.insert(paths, file_path)
        end
      end
    end
  end

  return paths
end

-- NOTE: Create user command to open Cursor-Agent
vim.api.nvim_create_user_command("CursorAgent", function(opts)
  local args = opts.args

  if args == "open_cwd" or args == "" or not args then
    open_cursor_cwd()
  elseif args == "open_root" then
    open_cursor_git_root()
  elseif args == "session_list" then
    open_cursor_show_sessions()
  else
    open_cursor_cli(args, true)
  end
end, {
  nargs = "?",
  complete = function()
    return { "open_cwd", "open_root", "session_list" }
  end,
  desc = "Open Cursor-Agent",
})
-- ----------------------------------------------

-- NOTE: Keymaps to open Cursor-Agent
vim.keymap.set("n", "<leader>aJ", function()
  open_cursor_cwd()
end, { desc = "Toggle Cursor-Agent (Current Dir)" })
vim.keymap.set("n", "<leader>aj", function()
  open_cursor_git_root()
end, { desc = "Toggle Cursor-Agent (Project Root)" })
vim.keymap.set("n", "<leader>al", function()
  open_cursor_show_sessions()
end, { desc = "Toggle Cursor-Agent (Show Sessions)" })
-- ----------------------------------

-- NOTE: Show help function
local function show_help()
  Snacks.notify(
    [[Term Mode:
    · <M-q>      : Normal Mode
    · <Esc><Esc> : Normal Mode
    · <C-j>      : New Line
    · <M-j>      : New paragraph
    · <C-p>      : Add Buffer File Path
    · <C-p><C-p> : Add All Open Buffer File Paths
    ---
    · <M-?>      : Show Help
    · ??         : Show Help
    · \\         : Show Help
    ---
    · <C-c>      : Clear/Stop/Close
    · <C-d>      : Close
    · <C-r>      : Review Changes

Norm Mode:
    · q          : Hide
    · <Esc>      : Hide
    · <...>      (all other normal mode keys)

Cursor-Agent commands:
    · quit       : (<CR>) Close Cursor-Agent
    · exit       : (<CR>) Close Cursor-Agent
    ---
    · /          : Show command list
    · @          : Show file list to attach
    · !          : To run in the shell
    ]],
    { title = "Keymaps", style = "compact", history = false, timeout = 5000 }
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
    vim.keymap.set("t", "<M-q>", [[<C-\><C-n>5(]], opts)

    vim.keymap.set("t", "<C-j>", function()
      insert_text("\n")
    end, opts)
    vim.keymap.set("t", "<M-j>", function()
      insert_text("\n\n")
    end, opts)
    vim.keymap.set("t", "<C-p>", function()
      if current_file then
        insert_text("@" .. current_file .. " ")
      end
    end, { noremap = true, silent = true })
    vim.keymap.set("t", "<C-p><C-p>", function()
      local paths = get_open_buffers_paths()
      for _, path in ipairs(paths) do
        insert_text("@" .. path .. "\n")
      end
    end, { noremap = true, silent = true })

    vim.keymap.set("t", "<M-?>", show_help, opts)
    vim.keymap.set("t", "??", show_help, opts)
    vim.keymap.set("t", "\\\\", show_help, opts)

    vim.keymap.set("n", "<Esc>", function()
      vim.cmd("q")
    end, opts)
  end,
})

-- NOTE: Show help when opening the terminal
vim.api.nvim_create_autocmd("TermOpen", {
  group = cursor_agent_opens_group,
  pattern = "term://*cursor-agent",
  callback = function()
    Snacks.notify(" Press: [<M-?>], [??], or [\\\\] to Show Help ", { title = "", style = "compact", history = false })
  end,
})

return {}
