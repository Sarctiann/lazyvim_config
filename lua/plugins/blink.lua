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
        default = { "lsp", "path", "snippets", "buffer", "emoji", "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
            -- In terminal buffers, Copilot returns a range starting at col 0
            -- (including the shell prompt). Fix the range to start at the
            -- cursor column so only the typed text gets replaced.
            transform_items = function(_, items)
              if vim.bo.buftype ~= "terminal" then
                return items
              end
              local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
              local filtered = {}
              for _, item in ipairs(items) do
                if item.textEdit then
                  local text = item.textEdit.newText or ""
                  -- Skip items shorter than cursor position (would produce empty label)
                  if #text > cursor_col then
                    item.textEdit.range["start"].character = cursor_col
                    item.label = string.sub(text, cursor_col + 1)
                    item.textEdit.newText = item.label
                    table.insert(filtered, item)
                  end
                else
                  table.insert(filtered, item)
                end
              end
              return filtered
            end,
          },
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
        -- Trigger completion menu in terminal mode
        ["<C-Space>"] = { "show", "hide", "fallback" },
      },

      -- Enable blink in terminal buffers (disabled by default)
      term = {
        enabled = true,
        keymap = { preset = "inherit" },
        sources = { "copilot", "buffer" },
        completion = {
          list = { selection = { auto_insert = false } },
        },
      },
    },
  },
}
