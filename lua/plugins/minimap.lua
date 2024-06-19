return {
  "gorbit99/codewindow.nvim",
  config = function()
    local codewindow = require("codewindow")
    codewindow.setup({
      auto_enable = true,
      window_border = "rounded",
      exclude_filetypes = { "NvimTree", "minimap", "dashboard", "help" },
    })
    codewindow.apply_default_keybinds()
  end,
}
