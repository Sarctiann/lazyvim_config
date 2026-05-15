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
            -- NOTE: In terminal buffers, Copilot returns a range starting at col 0
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
                  -- NOTE: Skip items shorter than cursor position (would produce empty label)
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
        -- NOTE: Trigger completion menu in terminal mode
        ["<C-Space>"] = { "show", "hide", "fallback" },
        -- NOTE: Override super-tab preset's `fallback_to_mappings` with `fallback` for these keys.
        -- `fallback_to_mappings` does not reach terminal-mode keymaps (e.g. cli-integration's
        -- `<C-p>` / `<C-n>` / `<C-f>`). `fallback` sends the raw key event, which does.
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },

      -- NOTE: Enable blink in terminal buffers (disabled by default)
      term = {
        enabled = true,
        keymap = { preset = "inherit" },
        sources = { "copilot" },
        completion = {
          list = { selection = { auto_insert = false } },
        },
      },
    },
    -- NOTE: Override Tab in terminal buffers for word-by-word Copilot acceptance.
    -- Instead of accepting the full suggestion, Tab inserts only the next word.
    -- blink then detects the text change and updates the remaining suggestion,
    -- so pressing Tab again accepts the next word, and so on.
    init = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(ev)
          vim.api.nvim_buf_set_keymap(ev.buf, "t", "<Tab>", "", {
            callback = function()
              local cmp = require("blink.cmp")
              -- If blink's completion menu is visible, accept one word at a time
              if cmp.is_visible() then
                local item = cmp.get_selected_item()
                if item and item.textEdit and item.textEdit.newText then
                  local text = item.textEdit.newText
                  -- Skip leading whitespace (find first non-whitespace char)
                  local word_start = text:find("[%S]") or 1
                  -- Find end of word (one or more whitespace chars after the word)
                  local ws_start, ws_end = text:find("[%s]+", word_start)
                  -- Extract word including trailing whitespace for proper word separation
                  local word
                  if ws_start then
                    word = text:sub(word_start, ws_end)
                  else
                    word = text:sub(word_start)
                  end
                  if #word > 0 then
                    -- Insert the word into the terminal
                    vim.api.nvim_feedkeys(word, "t", false)
                    -- Only show if not already visible (avoid flickering)
                    vim.defer_fn(function()
                      if not cmp.is_visible() then
                        cmp.show()
                      end
                    end, 30)
                    return ""
                  end
                end
              end
              -- No completion visible or no item selected: pass Tab through to the terminal
              return vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
            end,
            expr = true,
            silent = false,
            noremap = true,
            desc = "blink.cmp: Word-by-word Copilot acceptance in terminal",
          })
        end,
      })
    end,
  },
}
