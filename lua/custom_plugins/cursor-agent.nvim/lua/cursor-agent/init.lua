-- TODO:
-- - replace Snacks with native Neovim APIs
-- - Improve terminal management (wins and bufs)
-- - Write and type options:
--   - Make keymaps configurable
--   - Add more commands and options ???

--- @module 'Cursor-Agent'

local config = require("cursor-agent.config")
local commands = require("cursor-agent.commands")
local autocmds = require("cursor-agent.autocmds")

local M = {}

--- Setup function for the plugin
--- @param user_config Cursor-Agent.Config
function M.setup(user_config)
  -- Setup configuration
  local opts = config.setup(user_config)

  -- Create user command to open Cursor-Agent
  vim.api.nvim_create_user_command("CursorAgent", function(cmd_opts)
    local args = cmd_opts.args

    if args == "open_cwd" or args == "" or not args then
      commands.open_cwd()
    elseif args == "open_root" then
      commands.open_git_root()
    elseif args == "session_list" then
      commands.show_sessions()
    else
      commands.open_custom(args, true)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "open_cwd", "open_root", "session_list" }
    end,
    desc = "Open Cursor-Agent",
  })

  -- Setup default keymaps if enabled
  if opts.use_default_mappings then
    vim.keymap.set("n", "<leader>aJ", commands.open_cwd, { desc = "Toggle Cursor-Agent (Current Dir)" })
    vim.keymap.set("n", "<leader>aj", commands.open_git_root, { desc = "Toggle Cursor-Agent (Project Root)" })
    vim.keymap.set("n", "<leader>al", commands.show_sessions, { desc = "Toggle Cursor-Agent (Show Sessions)" })
  end

  -- Setup autocommands
  autocmds.setup()
end

return M
