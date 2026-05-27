return {
  "akinsho/bufferline.nvim",
  opts = function(_, opts)
    opts.options.offsets = {
      {
        filetype = "neo-tree",
        text = "Neo-Tree",
        highlight = "NeoTreeOffset",
        text_align = "center",
      },
    }
  end,
}
