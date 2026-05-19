local gemini_utils = require("utils.gemini_utils")
local augment_utils = require("utils.augment_utils")
local opencode_utils = require("utils.opencode_utils")

local current_dir = vim.fn.getcwd()
local company_dirs = { "dir1", "dir2" }

local keys_op = {
  -- NOTE: OpenCode keymaps
  -- NOTE: Start commands
  {
    "<leader>aa",
    ":CLIIntegration open_root OpenCode<CR>",
    desc = "OpenCode New Session",
    silent = true,
    mode = { "n", "v" },
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
    "<leader>asi",
    function()
      opencode_utils.show_info()
    end,
    desc = "OpenCode Status",
    silent = true,
  },
  {
    "<leader>ast",
    opencode_utils.toggle_tunnel,
    desc = "OpenCode Toggle Tunnel",
    silent = true,
  },
  {
    "<leader>ask",
    function()
      opencode_utils.inspect_opencode_processes()
    end,
    desc = "OpenCode Inspect Processes",
    silent = true,
  },
}

for _, dir in ipairs(company_dirs) do
  local _, found = string.find(current_dir, dir)
  if found then
    keys_op = {
      -- NOTE: Augment keymaps
      -- NOTE: Start commands
      {
        "<leader>aa",
        ":CLIIntegration open_root Augment --dont-save-session<CR>",
        desc = "Augment New Session",
        silent = true,
        mode = { "n", "v" },
      },
      {
        "<leader>aq",
        function()
          require("cli-integration").hooks.ask("Augment")
        end,
        desc = "Augment Ask (inline)",
        mode = { "n", "v" },
      },
      -- NOTE: Augment Sessions
      {
        "<leader>as",
        nil,
        desc = " Augment Code Sessions",
        silent = true,
      },
      {
        "<leader>asc",
        ":CLIIntegration open_root Augment -c<CR>",
        desc = "Augment Code Resume last session",
        silent = true,
      },
      {
        "<leader>asd",
        augment_utils.delete_all_augment_sessions,
        desc = "Augment Code Delete All sessions",
        silent = true,
      },
      {
        "<leader>asr",
        ":CLIIntegration open_root Augment session resume<CR>",
        desc = "Augment Code Resume Session list",
        silent = true,
      },
      {
        "<leader>ass",
        augment_utils.manage_augment_sessions,
        desc = "Augment Code Custom Session Manager",
        silent = true,
      },
    }
  end
end

return {
  company_dirs = { "dir1", "dir2" },
  integrations = {
    --- @type Cli-Integration.Integration[]
    integrations_implementations = {
      {
        name = "OpenCode",
        cli_cmd = opencode_utils.get_cli_cmd(),
        cli_ready_flags = { search_for = "Ask", from_line = 22, lines_amt = 12 },
        -- NOTE: on_open writes the port file from Lua memory so the bash script
        -- can skip server startup when reopening (instant fast path).
        on_open = function()
          opencode_utils.on_open()
        end,
        start_with_text = function(visual_text, integration)
          return require("cli-integration.hooks").insert_current_path_or_explain_selection()(visual_text, integration)
        end,
        format_paths = function(path)
          return "@" .. path
        end,
        on_ask_submit = function(data, actions)
          if data.selection then
            actions.send_line("```")
            actions.send_keys("@" .. data.relative_file)
            actions.wait(100)
            actions.send_keys("<CR>")
            actions.send_line(" L" .. data.start_line .. "-L" .. data.end_line)
            actions.send_line(data.selection)
            actions.send_line("```")
          else
            actions.send_keys("@" .. data.relative_file)
            actions.wait(100)
            actions.send_keys("<CR>")
            actions.send_line(" L" .. data.start_line)
          end
          actions.send_line()
          actions.send_line(data.question)
          actions.submit()
        end,
        keep_open = false,
        window_width = 45,
        terminal_keys = {
          terminal_mode = {
            normal_mode = { "<M-q>" },
            insert_file_path = { "<C-o>" }, -- NOTE: <C-p> is already taken by opencode
            insert_all_buffers = { "<C-o><C-o>" },
            toggle_width = { "<C-w>" },
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
      },
    },
    integrations_keys = vim.list_extend({
      -- NOTE: Gemini keymaps
      -- NOTE: Start commands
      {
        "<leader>ag",
        ":CLIIntegration open_root Gemini<CR>",
        desc = "Gemini New Session",
        silent = true,
        mode = { "n", "v" },
      },
      {
        "<leader>aQ",
        function()
          require("cli-integration").hooks.ask("Gemini")
        end,
        desc = "Gemini Ask (inline)",
        silent = true,
        mode = { "n", "v" },
      },
      -- NOTE: Gemini Sessions
      {
        "<leader>aS",
        nil,
        desc = " Gemini Sessions",
        silent = true,
      },
      {
        "<leader>aSc",
        ":CLIIntegration open_root Gemini --resume latest<CR>",
        desc = "Gemini Resume Latest",
        silent = true,
      },
      {
        "<leader>aSs",
        function()
          gemini_utils.manage_gemini_sessions(false)
        end,
        desc = "Gemini Session Manager",
        silent = true,
      },
      {
        "<leader>aSd",
        gemini_utils.delete_all_gemini_sessions,
        desc = "Gemini Delete Project Sessions",
        silent = true,
      },
    }, keys_op),
  },
}
