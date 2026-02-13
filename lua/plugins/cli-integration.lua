-- NOTE: you need to set the DOCS_DIR environment variable to point to your docs directory
local DOCS_DIR = os.getenv("DOCS_DIR")
local plugin_dir = DOCS_DIR .. "/SARCTIANN/LuaCode/custom_plugins/cli-integration.nvim/"

return {
  --- @module 'cli-integration'
  {
    "Sarctiann/cli-integration.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    --- @type Cli-Integration.Config
    opts = {
      -- NOTE: Global config
      show_help_on_open = true,
      new_lines_amount = 1,
      window_width = 64,
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
      integrations = {
        { name = "Augment", cli_cmd = "auggie" },
      },
    },
    -- NOTE: Comment the two lines below to use the plugin from GitHub
    dev = true,
    dir = plugin_dir,
    keys = {
      {
        "<leader>aa",
        ":CLIIntegration open_root Augment<CR>",
        desc = "Open Augment Code",
        silent = true,
      },
      {
        "<leader>aA",
        ":CLIIntegration open_root Augment session resume<CR>",
        desc = "Open (try) Augment Session Panel",
        silent = true,
      },
      {
        "<leader>aD",
        ":! auggie session delete --all",
        desc = "Delete ALL Augment sessions",
        silent = true,
      },
    },
  },
}
