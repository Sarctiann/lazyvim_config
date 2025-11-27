return {
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = { ensure_installed = { "v-analyzer" } },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "v" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        v_analyzer = {},
        -- vls = {}, -- you should have only one installed
      },
    },
  },
}
