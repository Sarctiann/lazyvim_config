--- Keymaps module for terminal interactions
local terminal = require("cursor-agent.terminal")
local buffers = require("cursor-agent.buffers")
local help = require("cursor-agent.help")

local M = {}

--- Setup keymaps for the Cursor-Agent terminal
function M.setup_terminal_keymaps()
  local keymap_opts = { buffer = 0, silent = true }

  -- Normal mode keymaps
  vim.keymap.set("t", "<M-q>", [[<C-\><C-n>5(]], keymap_opts)

  -- Insert current file path
  vim.keymap.set("t", "<C-p>", function()
    if terminal.current_file then
      terminal.insert_text("@" .. terminal.current_file .. " ")
    end
  end, keymap_opts)

  -- Insert all open buffer paths
  vim.keymap.set("t", "<C-p><C-p>", function()
    local paths = buffers.get_open_buffers_paths(terminal.working_dir)
    for _, path in ipairs(paths) do
      terminal.insert_text("@" .. path .. "\n")
    end
  end, keymap_opts)

  -- Submit commands
  vim.keymap.set("t", "<CR><CR>", function()
    terminal.insert_text("\n")
  end, keymap_opts)

  vim.keymap.set("t", "<C-s>", function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Enter>", true, false, true), "n")
  end, keymap_opts)

  -- Enter key
  vim.keymap.set("t", "<CR>", function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Enter>", true, false, true), "n")
  end, keymap_opts)

  -- Help keymaps
  vim.keymap.set("t", "<M-?>", help.show_help, keymap_opts)
  vim.keymap.set("t", "??", help.show_help, keymap_opts)
  vim.keymap.set("t", "\\\\", help.show_help, keymap_opts)

  -- Escape to hide
  vim.keymap.set("n", "<Esc>", function()
    vim.cmd("q")
  end, keymap_opts)
end

return M
