local M = {}

-- WARN:
-- You will want to add the following MCP entries to your `~/.config/opencode/opencode.jsonc`
-- if you have an `opencode.json` instead, remove the comments.
--
--  // MCP servers configuration
--  "mcp": {
--    // Neovim MCP server for buffer access and editing (bigcodegen)
--    "nvim-complete": {
--      "type": "local",
--      "command": ["npx", "-y", "mcp-neovim-server"],
--      "enabled": true,
--      "environment": {
--        // Enable shell commands execution through vim
--        "ALLOW_SHELL_COMMANDS": "true",
--        // Socket path for neovim connection (uses NVIM env var)
--        "NVIM_SOCKET_PATH": "{env:NVIM}",
--      },
--    },
--    // Alternative Neovim MCP server (nvim-mcp)
--    "nvim-fast": {
--      "type": "local",
--      "command": ["nvim-mcp", "--connect", "auto"],
--      "enabled": true,
--      "environment": {
--        // Socket path for neovim connection (uses NVIM env var)
--        "NVIM": "{env:NVIM}",
--      },
--    },
--  }

M.OPENCODE_HOST = "127.0.0.1"
M.OPENCODE_PORT = 4096

function M.get_server_url()
  return string.format("http://%s:%d", M.OPENCODE_HOST, M.OPENCODE_PORT)
end

local OPENCODE_DB = vim.fn.expand("~/.local/share/opencode/opencode.db")

-- NOTE: Convert a Unix millisecond timestamp to a sortable ISO-like string
-- and a formatted display pair (date, time).
local function parse_timestamp(ts_ms)
  local n = tonumber(ts_ms)
  if not n or n == 0 then
    return "0000-00-00T00:00:00", "Unknown", ""
  end
  local epoch = n / 1000
  -- iso string used for sorting (comparable with string comparison)
  local iso = os.date("!%Y-%m-%dT%H:%M:%S", epoch)
  local date = os.date("!%Y-%m-%d", epoch)
  local time = os.date("!%H:%M", epoch)
  return iso, date, time
end

-- NOTE: Query all sessions from the SQLite database.
-- Returns a list of Cli-Integration.Session objects.
local function get_sessions()
  local sessions = {}
  local cmd = string.format(
    'sqlite3 %s "SELECT id, title, directory, time_updated FROM session ORDER BY time_updated DESC;"',
    vim.fn.shellescape(OPENCODE_DB)
  )
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 or result == "" then
    return sessions
  end

  for line in vim.gsplit(result, "\n", { trimempty = true }) do
    -- Use a safe split on | that handles pipes in titles by anchoring on the
    -- known-format trailing fields: directory (starts with /) and numeric timestamp.
    -- Pattern: capture everything up to the last two | fields.
    local id, rest = line:match("^(ses_[^|]+)|(.+)$")
    if id and rest then
      -- Split the rest from the right: last field is the numeric timestamp,
      -- second-to-last is the directory (starts with /), the remainder is title.
      local ts = rest:match("|(%d+)$")
      local without_ts = rest:match("^(.+)|%d+$")
      local directory = without_ts and without_ts:match("|(/[^|]+)$")
      local title = (without_ts and directory) and without_ts:match("^(.+)|" .. vim.pesc(directory) .. "$")

      if ts and directory and title then
        local iso, date, time = parse_timestamp(ts)
        local project_name = vim.fn.fnamemodify(directory, ":t")
        if #project_name > 30 then
          project_name = "..." .. project_name:sub(-27)
        end
        local display_title = title:gsub("\n", " "):sub(1, 50)
        if #title > 50 then
          display_title = display_title .. "..."
        end

        table.insert(sessions, {
          id = id,
          modified = iso,
          workspace = directory,
          display = string.format("[%s %s] (%s) %s", date, time, project_name, display_title),
        })
      end
    end
  end
  return sessions
end

-- NOTE: OpenCode session manager (uses cli-integration hooks engine)
function M.manage_opencode_sessions(show_all)
  local hooks = require("cli-integration.hooks")
  hooks.manage_sessions({
    name = "OpenCode",
    resume_cmd = "CLIIntegration open_root OpenCode -s %s",
    show_all = show_all,
    get_sessions = get_sessions,
    delete_cmd = function(session)
      local cmd =
        string.format("sqlite3 %s \"DELETE FROM session WHERE id='%s';\"", vim.fn.shellescape(OPENCODE_DB), session.id)
      vim.fn.system(cmd)
      vim.notify("✓ Session deleted: " .. session.id, vim.log.levels.INFO)
    end,
  })
end

-- NOTE: Delete OpenCode sessions (current project or all)
function M.delete_all_opencode_sessions()
  local all_sessions = get_sessions()

  local options = { "Current Project Only", "ALL Projects", "Cancel" }
  vim.ui.select(options, { prompt = "⚠️ Delete OpenCode sessions?" }, function(choice)
    if not choice or choice == "Cancel" then
      return
    end

    local hooks = require("cli-integration.hooks")
    local current_ws = hooks.get_current_workspace()

    local session_ids = {}
    local scope_desc = ""

    if choice == "Current Project Only" then
      for _, sess in ipairs(all_sessions) do
        if sess.workspace == current_ws then
          table.insert(session_ids, sess.id)
        end
      end
      scope_desc = "current project"
    else
      for _, sess in ipairs(all_sessions) do
        table.insert(session_ids, sess.id)
      end
      scope_desc = "ALL projects"
    end

    if #session_ids == 0 then
      vim.notify("No OpenCode sessions found for " .. scope_desc, vim.log.levels.INFO)
      return
    end

    vim.ui.select({ "Yes, Delete " .. #session_ids .. " sessions", "No, Cancel" }, {
      prompt = "Confirm: Delete " .. #session_ids .. " sessions for " .. scope_desc .. "?",
    }, function(confirm)
      if confirm and confirm:match("^Yes") then
        local deleted = 0
        for _, id in ipairs(session_ids) do
          local cmd =
            string.format("sqlite3 %s \"DELETE FROM session WHERE id='%s';\"", vim.fn.shellescape(OPENCODE_DB), id)
          vim.fn.system(cmd)
          if vim.v.shell_error == 0 then
            deleted = deleted + 1
          end
        end
        vim.notify("✓ " .. deleted .. " session(s) deleted", vim.log.levels.INFO)
      else
        vim.notify("Deletion cancelled", vim.log.levels.INFO)
      end
    end)
  end)
end

local function is_opencode_server_running(callback)
  local uv = vim.loop
  local socket = uv.new_tcp()
  local timer = uv.new_timer()
  local finished = false

  local function finish(running)
    if finished then
      return
    end
    finished = true
    if timer then
      timer:stop()
      timer:close()
    end
    if socket then
      socket:close()
    end
    vim.schedule(function()
      callback(running)
    end)
  end

  if socket then
    socket:connect(M.OPENCODE_HOST, M.OPENCODE_PORT, function(err)
      if err then
        finish(false)
        return
      end
      finish(true)
    end)
  else
    print("Failed to create socket")
  end

  if timer then
    timer:start(1000, 0, function()
      finish(false)
    end)
  else
    print("Failed to create timer")
  end
end

function M.start_opencode_server()
  if M._server_starting then
    return
  end

  if vim.fn.executable("opencode") ~= 1 then
    vim.notify("OpenCode binary not found in PATH", vim.log.levels.WARN)
    return
  end

  is_opencode_server_running(function(running)
    if running then
      return
    end

    M._server_starting = true

    local uv = vim.loop
    local handle, pid
    handle, pid = uv.spawn("opencode", {
      args = { "serve", "--hostname", "0.0.0.0", "--port", tostring(M.OPENCODE_PORT), "--mdns" },
      stdio = { nil, nil, nil }, -- Completely detached stdio
      detached = true,
    }, function()
      M._server_starting = false
      if handle then
        handle:close()
      end
    end)

    if handle then
      uv.unref(handle) -- Key: Don't keep the event loop alive for this process
      M._server_starting = false -- PID spawned successfully
      vim.notify("OpenCode server started independently (PID: " .. pid .. ")", vim.log.levels.INFO)
    else
      M._server_starting = false
      vim.notify("Failed to spawn OpenCode server", vim.log.levels.ERROR)
    end
  end)
end

function M.restart_opencode_server()
  vim.fn.jobstart({ "pkill", "-f", "opencode serve" }, {
    stdout = "/dev/null",
    stderr = "/dev/null",
    on_exit = function()
      vim.defer_fn(function()
        M.start_opencode_server()
        vim.notify("OpenCode server restart command sent", vim.log.levels.INFO)
      end, 500)
    end,
  })
end

function M.kill_opencode_server()
  vim.fn.jobstart({ "pkill", "-f", "opencode serve" }, {
    stdout = "/dev/null",
    stderr = "/dev/null",
    on_exit = function(_, exit_code)
      vim.defer_fn(function()
        if exit_code == 0 then
          vim.notify("OpenCode server stopped", vim.log.levels.INFO)
        else
          vim.notify("No OpenCode server was running", vim.log.levels.WARN)
        end
      end, 100)
    end,
  })
end

return M
