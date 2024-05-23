require("nvim-web-devicons").set_icon({
  mojo = {
    icon = "󰈸",
    color = "#d75f00",
    cterm_color = "166",
    name = "Mojo",
  },
})

return {
  "neovim/nvim-lspconfig",
  event = "VeryLazy",
  opts = { servers = { mojo = {} } },
}
