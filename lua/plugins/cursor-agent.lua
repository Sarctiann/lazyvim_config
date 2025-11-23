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
      show_help_on_open = false,
    },
    -- NOTE: Comment the two lines below to use the plugin from GitHub
    dev = true,
    dir = plugin_dir,
  },
}
