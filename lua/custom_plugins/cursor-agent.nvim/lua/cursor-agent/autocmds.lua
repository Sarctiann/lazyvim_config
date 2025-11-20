--- Autocommands module
local keymaps = require("cursor-agent.keymaps")
local help = require("cursor-agent.help")

local M = {}

--- Setup autocommands for Cursor-Agent
function M.setup()
  local cursor_agent_group = vim.api.nvim_create_augroup("Cursor-Agent", { clear = true })
  local cursor_agent_opens_group = vim.api.nvim_create_augroup("Cursor-Agent-Opens", { clear = true })

  -- Setup keymaps when terminal opens or is entered
  vim.api.nvim_create_autocmd({ "TermOpen", "TermEnter" }, {
    group = cursor_agent_group,
    pattern = "term://*cursor-agent*",
    callback = keymaps.setup_terminal_keymaps,
  })

  -- Show help notification when opening the terminal
  vim.api.nvim_create_autocmd("TermOpen", {
    group = cursor_agent_opens_group,
    pattern = "term://*cursor-agent*",
    callback = help.show_quick_help,
  })
end

return M
