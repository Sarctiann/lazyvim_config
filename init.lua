-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Neovide config here
if vim.g.neovide then
  vim.g.neovide_scale_factor = 1.01
  vim.opt.linespace = -1

  vim.g.neovide_transparency = 0.9

  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0

  vim.g.neovide_cursor_vfx_mode = "ripple"
  vim.g.neovide_cursor_animation_length = 0.05
  vim.g.neovide_cursor_trail_size = 0.7

  vim.g.neovide_input_macos_alt_is_meta = true

  vim.g.neovide_remember_window_size = true

  vim.keymap.set("n", "<C-7>", function()
    LazyVim.terminal(nil, { cwd = LazyVim.root() })
  end, { desc = "which_key_ignore" })
end

print(vim.api.nvim_win_get_width(0))
