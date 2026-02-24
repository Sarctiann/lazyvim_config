-- NOTE: you need to set the DOCS_DIR environment variable to point to your docs directory
local DOCS_DIR = os.getenv("DOCS_DIR")
local plugin_dir = DOCS_DIR .. "/SARCTIANN/LuaCode/custom_plugins/cli-integration.nvim/"

-- Function to delete all Augment sessions with confirmation
local function delete_all_augment_sessions()
  vim.ui.select({ "Yes", "No" }, {
    prompt = "⚠️  Delete ALL Augment sessions? This action cannot be undone!",
  }, function(choice)
    if choice == "Yes" then
      vim.cmd("! auggie session delete --all")
      vim.notify("✓ All Augment sessions have been deleted", vim.log.levels.INFO)
    else
      vim.notify("Deletion cancelled", vim.log.levels.INFO)
    end
  end)
end

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
      window_width = 34,
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
        {
          name = "Augment",
          cli_cmd = "auggie",
          ready_text_flag = "Version",
          start_with_text = function(visual_text)
            if visual_text then
              return "Explain this code:\n```\n" .. visual_text .. "\n```\n"
            end
            -- If no visual selection, feed the keys to insert the current file path
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "t", false)
            return ""
          end,
          terminal_keys = {
            terminal_mode = {
              normal_mode = { "<M-q>" },
              insert_file_path = { "<C-o>" }, -- <C-p> is already taken by auggie
              insert_all_buffers = { "<C-o><C-o>" },
            },
          },
        },
      },
    },
    -- NOTE: Comment the two lines below to use the plugin from GitHub
    dev = true,
    dir = plugin_dir,
    keys = {
      {
        "<leader>a",
        ":CLIIntegration open_root Augment<CR>",
        desc = "Ask Augment",
        silent = true,
        mode = { "v" },
      },
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
        delete_all_augment_sessions,
        desc = "Delete ALL Augment sessions",
        silent = true,
      },
    },
  },
}
