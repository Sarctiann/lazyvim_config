--- Commands module for opening Cursor-Agent in different modes
local terminal = require("cursor-agent.terminal")

local M = {}

--- Open Cursor-Agent in the current file's directory
function M.open_cwd()
  terminal.working_dir = vim.fn.expand("%:p:h")

  if terminal.working_dir == "" then
    terminal.working_dir = vim.fn.getcwd()
  end
  terminal.open_terminal("--browser --approve-mcps")
end

--- Open Cursor-Agent in the project root (git root)
function M.open_git_root()
  terminal.current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")

  terminal.working_dir = vim.fs.find({ ".git" }, {
    path = terminal.current_file,
    upward = true,
  })[1]

  if terminal.working_dir then
    terminal.working_dir = vim.fn.fnamemodify(terminal.working_dir, ":h")
  else
    terminal.working_dir = current_dir ~= "" and current_dir or vim.fn.getcwd()
  end
  terminal.open_terminal("--browser --approve-mcps")
end

--- Show Cursor-Agent sessions
function M.show_sessions()
  terminal.current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")

  terminal.working_dir = vim.fs.find({ ".git" }, {
    path = terminal.current_file,
    upward = true,
  })[1]

  if terminal.working_dir then
    terminal.working_dir = vim.fn.fnamemodify(terminal.working_dir, ":h")
  else
    terminal.working_dir = current_dir ~= "" and current_dir or vim.fn.getcwd()
  end
  local custom_cmd = "ls"
  terminal.open_terminal(custom_cmd)
end

--- Open Cursor-Agent with custom arguments
--- @param args string Custom arguments for cursor-agent
--- @param keep_open boolean|nil Whether to keep the terminal open
function M.open_custom(args, keep_open)
  terminal.open_terminal(args, keep_open)
end

return M
