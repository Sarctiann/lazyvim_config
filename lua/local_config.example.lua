local gemini_utils = require("utils.gemini_utils")

return {
  company_dirs = { "dir1", "dir2" },
  integrations = {
    --- @type Cli-Integration.Integration[]
    integrations_implementations = {
      {
        name = "Gemini",
        cli_cmd = "gemini",
        cli_ready_flags = { search_for = "Type your", from_line = 15, lines_amt = 10 },
        start_with_text = function(visual_text, integration)
          return require("cli-integration.hooks").insert_current_path_or_explain_selection()(visual_text, integration)
        end,
        format_paths = function(path)
          return "@" .. path
        end,
      },
    },
    integrations_keys = {
      -- NOTE: Visual Mode
      {
        "<leader>A",
        ":CLIIntegration open_root Gemini --dont-save-session<CR>",
        desc = "Gemini Ask",
        silent = true,
        mode = { "v" },
      },
      -- NOTE: Normal mode
      {
        "<leader>ag",
        ":CLIIntegration open_root Gemini<CR>",
        desc = "Gemini New Session",
        silent = true,
      },
      -- NOTE: Gemini Sessions
      {
        "<leader>aG",
        nil,
        desc = " Gemini Sessions",
        silent = true,
      },
      {
        "<leader>aGc",
        ":CLIIntegration open_root Gemini --resume latest<CR>",
        desc = "Gemini Resume Latest",
        silent = true,
      },
      {
        "<leader>aGs",
        function()
          gemini_utils.manage_gemini_sessions(false)
        end,
        desc = "Gemini Session Manager",
        silent = true,
      },
      {
        "<leader>aGd",
        gemini_utils.delete_all_gemini_sessions,
        desc = "Gemini Delete Project Sessions",
        silent = true,
      },
    },
  },
}
