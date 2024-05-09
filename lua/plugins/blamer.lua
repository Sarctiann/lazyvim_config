return {
  "APZelos/blamer.nvim",
  config = function()
    vim.g.blamer_enabled = true
  end,
  init = function()
    vim.cmd([[
      let g:blamer_prefix = '         '
      let g:blamer_show_in_visual_modes = 0
      let g:blamer_show_in_insert_modes = 0
    ]])
  end,
}
