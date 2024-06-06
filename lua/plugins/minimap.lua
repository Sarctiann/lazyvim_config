return {
  "gorbit99/codewindow.nvim",
  config = function()
    local codewindow = require("codewindow")
    codewindow.setup({
      window_border = "rounded",
    })
    codewindow.apply_default_keybinds()
  end,
}
