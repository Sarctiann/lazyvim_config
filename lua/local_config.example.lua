local gemini_utils = require("utils.gemini_utils")
local opencode_utils = require("utils.opencode_utils")

return {
  company_dirs = { "dir1", "dir2" },
  integrations = {
    --- @type Cli-Integration.Integration[]
    integrations_implementations = {
      {
        name = "OpenCode",
        cli_cmd = "export OPENCODE_SERVER_PASSWORD="
          .. opencode_utils.OPENCODE_SERVER_PASSWORD
          .. " && sleep .1 && opencode attach "
          .. opencode_utils.get_server_url()
          .. " --dir .",
        cli_ready_flags = { search_for = "Ask", from_line = 22, lines_amt = 12 },
        on_open = function(_, _)
          opencode_utils.start_opencode_server()
        end,
        start_with_text = function(visual_text, integration)
          return require("cli-integration.hooks").insert_current_path_or_explain_selection()(visual_text, integration)
        end,
        format_paths = function(path)
          return "@" .. path .. " "
        end,
        format_ask_query = function(data, integration)
          local parts = { data.question, "" }
          if data.selection then
            table.insert(parts, "```" .. data.relative_file .. ":" .. data.start_line .. "-" .. data.end_line)
            table.insert(parts, data.selection)
            table.insert(parts, "```")
          else
            table.insert(parts, data.relative_file .. ":" .. data.start_line)
          end
          return table.concat(parts, "\n")
        end,
        terminal_keys = {
          terminal_mode = {
            normal_mode = { "<M-q>" },
            insert_file_path = { "<C-o>" },
            insert_all_buffers = { "<C-o><C-o>" },
          },
        },
      },
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
        format_ask_query = function(data, integration)
          local parts = { data.question, "" }
          if data.selection then
            table.insert(parts, "```" .. data.relative_file .. ":" .. data.start_line .. "-" .. data.end_line)
            table.insert(parts, data.selection)
            table.insert(parts, "```")
          else
            local ref = data.relative_file .. ":" .. data.start_line
            table.insert(parts, (integration.format_paths and integration.format_paths(ref)) or ("@" .. ref))
          end
          return table.concat(parts, "\n")
        end,
      },
    },
    integrations_keys = {
      -- NOTE: OpenCode keymaps
      -- NOTE: Visual Mode
      {
        "<leader>aa",
        ":CLIIntegration open_root OpenCode <CR>",
        desc = "OpenCode Ask",
        silent = true,
        mode = { "v" },
      },
      -- NOTE: Normal mode
      {
        "<leader>aa",
        ":CLIIntegration open_root OpenCode<CR>",
        desc = "OpenCode New Session",
        silent = true,
      },
      {
        "<leader>aq",
        function()
          require("cli-integration").hooks.ask("OpenCode")
        end,
        desc = "OpenCode Ask (inline)",
        mode = { "n", "v" },
      },
      -- NOTE: OpenCode Sessions
      {
        "<leader>as",
        nil,
        desc = " OpenCode Sessions & Server",
        silent = true,
      },
      {
        "<leader>asc",
        ":CLIIntegration open_root OpenCode --continue<CR>",
        desc = "OpenCode Resume Latest",
        silent = true,
      },
      {
        "<leader>ass",
        function()
          opencode_utils.manage_opencode_sessions(false)
        end,
        desc = "OpenCode Session Manager",
        silent = true,
      },
      {
        "<leader>asd",
        opencode_utils.delete_all_opencode_sessions,
        desc = "OpenCode Delete Project Sessions",
        silent = true,
      },
      {
        "<leader>asr",
        opencode_utils.restart_opencode_server,
        desc = "OpenCode Restart Server",
        silent = true,
      },
      {
        "<leader>ask",
        opencode_utils.kill_opencode_server,
        desc = "OpenCode Kill Server",
        silent = true,
      },
      -- NOTE: Gemini keymaps
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
      {
        "<leader>aQ",
        function()
          require("cli-integration").hooks.ask("Gemini")
        end,
        desc = "Gemini Ask (inline)",
        mode = { "n", "v" },
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
