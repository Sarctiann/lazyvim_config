return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    style = "night",
    transparent = true,
    styles = {
      sidebars = "dark",
      -- floats = "transparent",
    },
    on_highlights = function(hl, c)
      hl.NeoTreeOffset = {
        fg = c.fg_dark,
        bg = c.bg_dark,
      }
    end,
  },
}
