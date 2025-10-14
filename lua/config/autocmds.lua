-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Define cursor styles
local default_cursor = "n-c-ci-cr-sm:block,i:ver30-CursorL,v-ve-o:hor30-VisualCursor,r:hor50-ReplaceCursor,a:blinkon100"
local vertical_cursor = "a:ver30"
local exit_cursor = "a:ver30-blinkon100-blinkoff400-blinkon250"

-- Create a single cursor autocommand group
local cursor_group = vim.api.nvim_create_augroup("Custom-Cursor", { clear = true })

-- Set cursor for different modes (enter events)
vim.api.nvim_create_autocmd({ "CmdlineEnter", "TermEnter", "WinEnter" }, {
  group = cursor_group,
  callback = function(args)
    local event = args.event

    if
      (event == "WinEnter" and (vim.bo.buftype == "nofile" or vim.bo.buftype == ""))
      and not (vim.bo.ft == "snacks_terminal")
    then
      return
    end
    vim.opt_local.guicursor = vertical_cursor
  end,
})

-- Restore cursor (leave events)
vim.api.nvim_create_autocmd({ "WinLeave", "CmdlineLeave", "TermLeave", "VimLeave" }, {
  group = cursor_group,
  callback = function(args)
    local event = args.event

    -- Special case for VimLeave
    if event == "VimLeave" then
      vim.opt.guicursor = exit_cursor
      return
    end

    -- For all other leave events
    vim.opt.guicursor = default_cursor
  end,
})

-- Change the color of unused code highlight
vim.api.nvim_create_autocmd({ "DiagnosticChanged" }, {
  group = cursor_group,
  callback = function()
    vim.api.nvim_command("highlight! link DiagnosticUnnecessary UnusedCode")
  end,
})
