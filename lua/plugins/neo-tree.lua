return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.popup_border_style = "rounded"
    opts.filesystem = {
      bind_to_cwd = false,
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      filtered_items = { visible = true },
    }
  end,
}
