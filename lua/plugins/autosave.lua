return {
  "okuuva/auto-save.nvim", -- [Docs](https://neovimcraft.com/plugin/okuuva/auto-save.nvim)
  -- cmd = "ASToggle", -- optional for lazy loading on command
  -- event = { "InsertLeave", "TextChange" }, -- optional for lazy loading on trigger events
  enabled = true,
  opts = {
    -- VSCode behavior
    trigger_events = {
      immediate_save = { "BufLeave" },
      defer_save = { "FocusLost" },
      cancel_defered_save = { "BufLeave" },
    },
    debounce_delay = 100,
  },
}
