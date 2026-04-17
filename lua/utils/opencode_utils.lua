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

M.OPENCODE_SERVER_USERNAME = "opencode"
M.OPENCODE_SERVER_PASSWORD = "open-sarc-code"
local OPENCODE_DB = vim.fn.expand("~/.local/share/opencode/opencode.db")
local OPENCODE_MCP_CONFIG_FILE = vim.fn.expand("~/.config/opencode/opencode_nvim_mcps.jsonc")
-- Precompute paths and JSON helpers at module load time to avoid calling
-- vim.fn.expand or vim.fn.json_* inside fast event contexts.
local STATE_FILE = vim.fn.expand("~/.local/share/opencode/state.json")

local json = nil
if vim.json and vim.json.encode and vim.json.decode then
  json = { encode = vim.json.encode, decode = vim.json.decode }
else
  -- Fallback to vim.fn functions (may error in fast event contexts on older Neovim)
  json = {
    encode = function(t)
      return vim.fn.json_encode(t)
    end,
    decode = function(s)
      return vim.fn.json_decode(s)
    end,
  }
end

local function load_credentials()
  local cred_file = vim.fn.expand("~/.config/opencode/.server_credentials")
  local handle = io.open(cred_file, "r")
  if handle then
    for line in handle:lines() do
      local username = line:match('^OPENCODE_SERVER_USERNAME="([^"]+)"')
      local password = line:match('^OPENCODE_SERVER_PASSWORD="([^"]+)"')
      if username and password then
        M.OPENCODE_SERVER_USERNAME = username
        M.OPENCODE_SERVER_PASSWORD = password
        break
      end
    end
    handle:close()
  end
end

load_credentials()
M.OPENCODE_HOST = "127.0.0.1"
M.OPENCODE_PORT = 4096

function M.get_server_url()
  return string.format("http://%s:%d", M.OPENCODE_HOST, M.OPENCODE_PORT)
end

-- State file for sharing server/tunnel info between instances
function M.state_file_path()
  return STATE_FILE
end

function M.read_state()
  local path = M.state_file_path()
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return nil
  end
  local ok, tbl = pcall(json.decode, content)
  if ok and type(tbl) == "table" then
    return tbl
  end
  return nil
end

function M.write_state(tbl)
  local path = M.state_file_path()
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  -- Use libuv API to get pid (vim.loop.os_getpid) instead of deprecated getpid
  local pid_for_tmp = (vim.loop and vim.loop.os_getpid and vim.loop.os_getpid() or 0)
  local tmp = path .. ".tmp." .. tostring(pid_for_tmp)
  local content = json.encode(tbl or {})
  -- Try to acquire lock before writing
  local acquired = M._acquire_state_lock()

  local f, err = io.open(tmp, "w")
  if not f then
    vim.notify("Failed to open temp state file: " .. (err or "unknown"), vim.log.levels.ERROR)
    if acquired then
      M._release_state_lock()
    end
    return
  end
  f:write(content)
  f:close()
  -- atomic replace
  os.rename(tmp, path)
  -- Release lock if we acquired it
  if acquired then
    M._release_state_lock()
  end
end

-- Simple file lock implementation (best-effort)
function M._acquire_state_lock()
  local lock = STATE_FILE .. ".lock"
  if vim.loop and vim.loop.fs_open then
    local fd = vim.loop.fs_open(lock, "wx", 438)
    if fd then
      local pid = (vim.loop and vim.loop.os_getpid and vim.loop.os_getpid()) or 0
      pcall(function()
        vim.loop.fs_write(fd, tostring(pid), -1)
      end)
      vim.loop.fs_close(fd)
      -- mark owned
      M._state_lock_path = lock
      return true
    end
    return false
  else
    -- fallback: create file if not exists
    local f = io.open(lock, "r")
    if f then
      f:close()
      return false
    end
    local w = io.open(lock, "w")
    if w then
      w:write(tostring(os.time()))
      w:close()
      M._state_lock_path = lock
      return true
    end
    return false
  end
end

function M._release_state_lock()
  local lock = M._state_lock_path or (STATE_FILE .. ".lock")
  pcall(function()
    os.remove(lock)
  end)
  M._state_lock_path = nil
end

function M.clear_tunnel_state()
  local s = M.read_state() or {}
  s.tunnel = nil
  M.write_state(s)
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

-- Return consolidated status via callback(status_table)
-- status_table: { server_running=bool, server_url=string, tunnel_url=string|nil, tunnel_pid=number|nil, tunnel_stale=bool, raw_state=table }
function M.get_status(callback)
  is_opencode_server_running(function(running)
    local state = M.read_state() or {}
    local tunnel = state.tunnel
    local tunnel_url = nil
    local tunnel_pid = nil
    local stale = false
    if tunnel and tunnel.pid then
      tunnel_pid = tonumber(tunnel.pid)
      if tunnel_pid then
        local ok = pcall(function()
          -- kill with 0 checks if process exists (POSIX)
          -- use uv.os_kill if available, fallback to vim.loop.kill
          if vim.loop and vim.loop.kill then
            vim.loop.kill(tunnel_pid, 0)
          else
            vim.loop.kill(tunnel_pid, 0)
          end
        end)
        if ok then
          tunnel_url = tunnel.url
        else
          stale = true
        end
      end
    end

    local res = {
      server_running = running,
      server_url = M.get_server_url(),
      tunnel_url = tunnel_url,
      tunnel_pid = tunnel_pid,
      tunnel_stale = stale,
      raw_state = state,
    }
    callback(res)
  end)
end

-- statusline helper removed per user request

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

    -- Build the environment by extending the current one
    local env = {}
    for k, v in pairs(vim.fn.environ()) do
      table.insert(env, string.format("%s=%s", k, v))
    end
    table.insert(env, "OPENCODE_CONFIG=" .. OPENCODE_MCP_CONFIG_FILE)
    table.insert(env, "OPENCODE_SERVER_USERNAME=" .. M.OPENCODE_SERVER_USERNAME)
    table.insert(env, "OPENCODE_SERVER_PASSWORD=" .. M.OPENCODE_SERVER_PASSWORD)

    local uv = vim.loop
    local handle, pid
    handle, pid = uv.spawn("opencode", {
      args = { "serve", "--hostname", "0.0.0.0", "--port", tostring(M.OPENCODE_PORT), "--mdns" },
      env = env,
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

M._tunnel_pid = nil
M._tunnel_url = nil

function M.start_tunnel()
  if not M.OPENCODE_SERVER_PASSWORD or M.OPENCODE_SERVER_PASSWORD == "" then
    vim.notify(
      "OPENCODE_SERVER_PASSWORD not set. Configure it in ~/.config/opencode/.server_credentials",
      vim.log.levels.ERROR
    )
    return
  end

  is_opencode_server_running(function(running)
    if not running then
      vim.notify("OpenCode server not running. Start it first with <leader>asr", vim.log.levels.WARN)
      return
    end
    -- Helper that kills any existing untun and starts a new tunnel process
    local function launch_new_tunnel()
      vim.fn.jobstart({ "pkill", "-f", "untun" }, {
        stdout = "/dev/null",
        stderr = "/dev/null",
        on_exit = function()
          local uv = vim.loop
          local stdin = uv.new_pipe(false)
          local stdout = uv.new_pipe(false)
          local stderr = uv.new_pipe(false)

          if not stdin or not stdout or not stderr then
            vim.notify("Failed to create pipes for tunnel", vim.log.levels.ERROR)
            return
          end

          local function cleanup()
            stdin:close()
            stdout:close()
            stderr:close()
          end

          local handle, pid = uv.spawn("npx", {
            args = { "untun", "tunnel", "http://localhost:4096" },
            stdio = { stdin, stdout, stderr },
            detached = true,
          }, function()
            M._tunnel_pid = nil
            M._tunnel_url = nil
            cleanup()
          end)

          if not handle then
            vim.notify("Failed to start untun", vim.log.levels.ERROR)
            cleanup()
            return
          end

          -- Auto-accept the cloudflared license/terms prompt
          stdin:write("y\n", function() end)

          vim.loop.unref(handle)
          M._tunnel_pid = pid

          local url_buffer = ""
          local found_url = false

          uv.read_start(stdout, function(err, data)
            if err or not data then
              return
            end
            url_buffer = url_buffer .. data

            local url = url_buffer:match("https://[%w%-]+%.trycloudflare%.com")
            if url and not found_url then
              found_url = true
              M._tunnel_url = url
              -- schedule UI and IO work on main loop to avoid fast-event errors
              vim.schedule(function()
                vim.fn.setreg("+", url)
                vim.notify("Tunnel active: " .. url .. " (copied to clipboard)", vim.log.levels.INFO)

                -- Persist tunnel state so other instances can see it
                local state = M.read_state() or {}
                state.server = state.server or { host = M.OPENCODE_HOST, port = M.OPENCODE_PORT }
                state.tunnel = {
                  pid = pid,
                  url = url,
                  started_at = os.time() * 1000,
                  owner = (os.getenv and os.getenv("USER") or "unknown") .. ":" .. tostring(pid),
                }
                M.write_state(state)
              end)
            end
          end)

          uv.read_start(stderr, function(err, data)
            if err or not data then
              return
            end
          end)

          vim.notify("Starting tunnel... waiting for URL", vim.log.levels.INFO)
        end,
      })
    end

    -- Check persisted global state for an active tunnel (so this prompt works across instances)
    local persisted = M.read_state() or {}
    local existing = persisted.tunnel
    local existing_alive = false
    local existing_url = nil
    if existing and existing.pid then
      local epid = tonumber(existing.pid)
      if epid then
        local ok = pcall(function()
          if vim.loop and vim.loop.kill then
            vim.loop.kill(epid, 0)
          elseif vim.loop and vim.loop.kill then
            vim.loop.kill(epid, 0)
          end
        end)
        if ok then
          existing_alive = true
          existing_url = existing.url
        end
      end
    end

    if existing_alive then
      -- Show a one-line floating prompt with keybindings in the title.
      local buf = vim.api.nvim_create_buf(false, true)
      local width = math.min(80, vim.o.columns - 10)
      local height = 1
      local row = math.min(vim.o.lines, 2)
      local col = math.floor((vim.o.columns - width) / 2)
      local title = string.format("[y] New  [c] Copy  [s] Stop  [N] Cancel")
      local win_opts = {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "single",
        title = title,
        title_pos = "center",
      }
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.format(" Active tunnel: %s", existing_url or "unknown") })
      local win = vim.api.nvim_open_win(buf, true, win_opts)

      -- helper to close and cleanup
      local function close_prompt()
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end

      -- Action: start new tunnel
      local function on_new()
        close_prompt()
        launch_new_tunnel()
      end

      -- Action: copy URL to clipboard
      local function on_copy()
        if existing_url then
          vim.fn.setreg("+", existing_url)
          vim.notify("Tunnel URL copied to clipboard", vim.log.levels.INFO)
        else
          vim.notify("No tunnel URL available", vim.log.levels.WARN)
        end
        close_prompt()
      end

      -- Action: stop global tunnel (pkill and clear state)
      local function on_stop()
        close_prompt()
        vim.fn.jobstart({ "pkill", "-f", "untun" }, {
          stdout = "/dev/null",
          stderr = "/dev/null",
          on_exit = function(_, exit_code)
            vim.schedule(function()
              if exit_code == 0 then
                M.clear_tunnel_state()
                vim.notify("Tunnel stopped", vim.log.levels.INFO)
              else
                vim.notify("No active tunnel found", vim.log.levels.WARN)
              end
            end)
          end,
        })
      end

      -- Map keys in buffer
      local opts = { nowait = true, noremap = true, silent = true }
      vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "y",
        string.format(":lua require('utils.opencode_utils')._prompt_action(%q)<CR>", "new"),
        opts
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "c",
        string.format(":lua require('utils.opencode_utils')._prompt_action(%q)<CR>", "copy"),
        opts
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "s",
        string.format(":lua require('utils.opencode_utils')._prompt_action(%q)<CR>", "stop"),
        opts
      )
      local cancel_str = string.format(":lua require('utils.opencode_utils')._prompt_action(%q)<CR>", "cancel")
      vim.api.nvim_buf_set_keymap(buf, "n", "N", cancel_str, opts)
      vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", cancel_str, opts)
      vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", cancel_str, opts)

      -- Register handlers accessible via module-level function
      M._prompt_handlers = M._prompt_handlers or {}
      M._prompt_handlers.new = on_new
      M._prompt_handlers.copy = on_copy
      M._prompt_handlers.stop = on_stop
      M._prompt_handlers.cancel = close_prompt
    else
      launch_new_tunnel()
    end
  end)
end

function M.stop_tunnel()
  if M._tunnel_pid then
    vim.fn.jobstart({ "pkill", "-f", "untun" }, {
      stdout = "/dev/null",
      stderr = "/dev/null",
      on_exit = function()
        M._tunnel_pid = nil
        M._tunnel_url = nil
        -- clear persisted state when tunnel stops
        M.clear_tunnel_state()
        vim.notify("Tunnel stopped", vim.log.levels.INFO)
      end,
    })
  else
    vim.notify("No active tunnel", vim.log.levels.WARN)
  end
end

function M.get_tunnel_url()
  if M._tunnel_url then
    return M._tunnel_url
  end
  -- Fallback: read persisted state so other instances can see the URL
  local s = M.read_state()
  if not s or not s.tunnel then
    return nil
  end
  local pid = tonumber(s.tunnel.pid)
  if pid then
    local ok = pcall(function()
      if vim.loop and vim.loop.kill then
        vim.loop.kill(pid, 0)
      elseif vim.loop and vim.loop.kill then
        vim.loop.kill(pid, 0)
      end
    end)
    if ok then
      return s.tunnel.url
    end
  end
  return nil
end

-- Entry point used by the floating prompt keymaps to dispatch actions.
function M._prompt_action(action)
  local h = M._prompt_handlers and M._prompt_handlers[action]
  if h and type(h) == "function" then
    h()
  end
end

return M
