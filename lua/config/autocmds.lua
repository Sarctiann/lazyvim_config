-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

if not vim.g.vscode then
  -- Single source of truth for cursor behavior in Neovim and on exit
  local nvim_cursor =
    "n:block,c:ver30-CmdTermCursor,ci:ver30-CmdTermCursor,cr:ver30-CmdTermCursor,sm:block,i:ver30-CursorL,t:ver30-CmdTermCursor,v-ve-o:hor30-VisualCursor,r:hor50-ReplaceCursor,a:blinkon100"
  local exit_cursor = "a:ver30-blinkon100-blinkoff400-blinkon250"

  -- Create a single cursor autocommand group
  local cursor_group = vim.api.nvim_create_augroup("Custom-Cursor", { clear = true })

  -- Apply cursor config immediately (autocmds.lua is loaded on VeryLazy,
  -- so VimEnter may already have happened).
  vim.opt.guicursor = nvim_cursor

  -- Restore terminal cursor on exit
  vim.api.nvim_create_autocmd("VimLeave", {
    group = cursor_group,
    callback = function()
      vim.opt.guicursor = exit_cursor
    end,
  })

  -- Change the color of unused code highlight
  vim.api.nvim_create_autocmd({ "DiagnosticChanged" }, {
    group = cursor_group,
    callback = function()
      vim.api.nvim_command("highlight! link DiagnosticUnnecessary UnusedCode")
    end,
  })
end
