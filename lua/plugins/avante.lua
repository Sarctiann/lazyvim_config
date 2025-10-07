-- ⚠️ Avante requires you to run: `:AvanteBuild`

return {
  {
    "saghen/blink.cmp",
    dependencies = {
      "Kaiser-Yang/blink-cmp-avante",
      -- ... Other dependencies
    },
    opts = {
      sources = {
        -- Add 'avante' to the list
        default = { "avante", "lsp", "path", "snippets", "buffer" },
        providers = {
          avante = {
            module = "blink-cmp-avante",
            name = "Avante",
            opts = {
              -- options for blink-cmp-avante
            },
          },
        },
      },
    },
  },

  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    build = "npm install -g mcp-hub@latest", -- Installs `mcp-hub` node binary globally
    config = function()
      require("mcphub").setup({
        auto_approve = true,
        extensions = {
          avante = {
            make_slash_commands = true, -- make /slash commands from MCP server prompts
          },
        },
      })
    end,
  },

  {
    "yetone/avante.nvim",
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    -- ⚠️ must add this setting! ! !
    build = vim.fn.has("win32") ~= 0 and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",
    event = "VeryLazy",
    version = false, -- Never set this value to "*"! Never!
    config = function()
      require("avante").setup({
        -- system_prompt as function ensures LLM always has latest MCP server state
        -- This is evaluated for every message, even in existing chats
        system_prompt = function()
          local hub = require("mcphub").get_hub_instance()
          return hub and hub:get_active_servers_prompt() or ""
        end,
        -- Using function prevents requiring mcphub before it's loaded
        custom_tools = function()
          return {
            require("mcphub.extensions.avante").mcp_tool(),
          }
        end,
        provider = "copilot", -- Set provider to copilot
        auto_suggestions_provider = "copilot",
        disabled_tools = {
          -- "list_files", -- Built-in file operations
          -- "search_files",
          -- "read_file",
          -- "create_file",
          -- "rename_file",
          -- "delete_file",
          -- "create_dir",
          -- "rename_dir",
          -- "delete_dir",
          -- "bash", -- Built-in terminal access
        },
        windows = {
          ---@type "right" | "left" | "top" | "bottom"
          position = "right", -- the position of the sidebar
          wrap = true, -- similar to vim.o.wrap
          width = 35,
          sidebar_header = {
            enabled = true, -- true, false to enable/disable the header
            align = "left", -- left, center, right for title
            rounded = true,
          },
          input = {
            prefix = "> ",
            height = 15, -- Height of the input window in vertical layout
          },
        },
      })
    end,
    dependencies = {
      "ravitemer/mcphub.nvim",
      "saghen/blink.cmp",

      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",

      --- The below dependencies are optional,

      "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions

      "nvim-mini/mini.pick", -- for file_selector provider mini.pick
      -- "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      -- "ibhagwan/fzf-lua", -- for file_selector provider fzf

      "folke/snacks.nvim", -- for input provider snacks
      -- "stevearc/dressing.nvim", -- for input provider dressing

      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons

      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
