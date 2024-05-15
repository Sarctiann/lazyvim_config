return {
  "ovikrai/mojo-syntax",
  config = function()
    require("lspconfig").mojo.setup({})
    require("nvim-web-devicons").set_icon({
      mojo = {
        icon = "󰈸",
        color = "#d75f00",
        cterm_color = "166",
        name = "Mojo",
      },
    })
  end,
}
