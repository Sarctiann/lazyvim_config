return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
    },
  },
  {
    "saghen/blink.cmp",
    -- NOTE: Less than Augment
    priority = 900,
    dependencies = {
      "moyiz/blink-emoji.nvim",
    },
    opts = {
      completion = {
        ghost_text = {
          enabled = false,
        },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer", "emoji" },
        providers = {
          emoji = {
            module = "blink-emoji",
            name = "Emoji",
            score_offset = 15,
            opts = {
              insert = true,
              ---@type string|table|fun():table
              trigger = function()
                return { ":" }
              end,
            },
            should_show_items = function()
              return vim.tbl_contains({
                "gitcommit",
                "markdown",
                "yaml",
                "text",
                "json",
                "html",
                "lua",
                "python",
                "javascript",
                "typescript",
              }, vim.o.filetype)
            end,
          },
        },
      },

      cmdline = {
        enabled = false,
      },

      keymap = {
        preset = "super-tab",
        ["<C-y>"] = { nil },
      },
    },
  },
}
