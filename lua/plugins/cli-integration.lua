-- NOTE: you need to set the DOCS_DIR environment variable to point to your docs directory
local DOCS_DIR = os.getenv("DOCS_DIR")
local plugin_dir = DOCS_DIR and (DOCS_DIR .. "/SARCTIANN/LuaCode/custom_plugins/cli-integration.nvim/") or nil

local lc_ok, local_config = pcall(require, "local_config")
local integrations = (lc_ok and local_config and local_config.integrations)
  or {
    integrations_implementations = {},
    integrations_keys = {},
  }

return {
  --- @module 'cli-integration'
  {
    "Sarctiann/cli-integration.nvim",
    --- @type Cli-Integration.Config
    opts = {
      -- NOTE: Global config
      show_help_on_open = true,
      new_lines_amount = 1,
      start_insert_on_click = true,
      list_buffer = false,
      window_width = 40,
      window_padding = 1,
      terminal_keys = {
        terminal_mode = {
          normal_mode = { "<M-q>" },
          insert_file_path = { "<C-p>" },
          insert_all_buffers = { "<C-p><C-p>" },
          new_lines = { "<S-CR>" },
          submit = { "<C-s>", "<C-CR>" },
          enter = { "<CR>" },
          help = { "<M-?>", "??", "\\\\" },
          toggle_width = { "<C-f>" },
        },
        normal_mode = {
          hide = { "<Esc>" },
          toggle_width = { "<C-f>" },
        },
      },
      -- NOTE: Each integration can override global configs
      --
      --- @type Cli-Integration.Integration[]
      integrations = integrations.integrations_implementations,
    },
    keys = integrations.integrations_keys,
    -- NOTE: Comment the two lines below to use the plugin from GitHub
    dev = true,
    dir = plugin_dir,
  },
}
