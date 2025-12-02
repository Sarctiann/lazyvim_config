return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Extend existing configuration instead of overwriting it
      opts.servers = opts.servers or {}
      opts.servers.ruby_lsp = vim.tbl_deep_extend("force", opts.servers.ruby_lsp or {}, {
        mason = false,
        enabled = true,
        cmd = { vim.fn.expand("~/.rbenv/shims/ruby-lsp") },
      })

      -- Prevent RuboCop from being configured as an LSP server (only used as formatter)
      opts.setup = opts.setup or {}
      opts.setup.rubocop = function()
        -- Return true to prevent it from being configured with lspconfig
        return true
      end

      return opts
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      -- Configure RuboCop to use the command from rbenv instead of Mason
      -- Override the formatter in formatters with the correct configuration
      opts.formatters = opts.formatters or {}

      -- Correct configuration for RuboCop using temporary file instead of stdin
      -- This prevents RuboCop messages from being written directly to the file
      opts.formatters.rubocop = {
        command = vim.fn.expand("~/.rbenv/shims/rubocop"),
        args = { "-a", "$FILENAME" },
        stdin = false, -- Use temporary file instead of stdin
      }

      -- Ensure ruby uses rubocop (preserve existing configuration if any)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      if not opts.formatters_by_ft.ruby then
        opts.formatters_by_ft.ruby = { "rubocop" }
      elseif type(opts.formatters_by_ft.ruby) == "table" then
        -- If configuration already exists, ensure rubocop is included
        local has_rubocop = false
        for _, formatter in ipairs(opts.formatters_by_ft.ruby) do
          if formatter == "rubocop" then
            has_rubocop = true
            break
          end
        end
        if not has_rubocop then
          table.insert(opts.formatters_by_ft.ruby, "rubocop")
        end
      end

      return opts
    end,
  },
}
