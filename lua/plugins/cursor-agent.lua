-- NOTE: you need to set the DOCS_DIR environment variable to point to your docs directory
local DOCS_DIR = os.getenv("DOCS_DIR")
local plugin_dir = DOCS_DIR .. "/SARCTIANN/LuaCode/custom_plugins/cursor-agent.nvim/"

return {
  --- @module 'cursor-agent'
  {
    "Sarctiann/cursor-agent.nvim",
    dependencies = {
      "folke/snacks.nvim",
    },
    --- @type Cursor-Agent.Config
    opts = {
      use_default_mappings = true,
      show_help_on_open = true,
      new_lines_amount = 1,
      window_width = 64,
      open_mode = "plan",
      cursor_window_keys = {
        terminal_mode = {
          normal_mode = { "<M-q>" },
          insert_file_path = { "<C-p>" },
          insert_all_buffers = { "<C-p><C-p>" },
          new_lines = { "<CR>" },
          submit = { "<C-s>" },
          enter = { "<tab>" },
          help = { "<M-?>", "??", "\\\\" },
          toggle_width = { "<C-f>" },
        },
        normal_mode = {
          hide = { "<Esc>" },
          toggle_width = { "<C-f>" },
        },
      },
    },
    -- NOTE: Comment the two lines below to use the plugin from GitHub
    dev = true,
    dir = plugin_dir,
  },
}
