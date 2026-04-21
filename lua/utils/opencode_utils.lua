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

OC_DEBUG = false
M.OPENCODE_SERVER_USERNAME = "opencode"
M.OPENCODE_SERVER_PASSWORD = "open-sarc-code"
local OPENCODE_DB = vim.fn.expand("~/.local/share/opencode/opencode.db")
-- NOTE: Resolve MCP config path relative to this file's directory using Neovim's debug.getinfo
local OPENCODE_MCP_CONFIG_FILE = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
  .. "/opencode_nvim_mcps.jsonc"

-- NOTE: Runtime state for the current neovim instance.
-- These are NOT persisted — they live only for the lifetime of this neovim process.
-- Each neovim instance owns its own opencode server; state is never shared across instances.
-- _port        : port of the server started by THIS instance (read back from PORT_FILE after startup)
-- _server_pid  : PID of the `opencode serve` process started by this instance
-- _tunnel_*    : state for the optional cloudflare tunnel (npx untun)
-- _cleanup_registered : guard so VimLeavePre is only registered once
M._port = nil
M._server_pid = nil -- PID of the opencode serve process started by this instance
M._tunnel_handle = nil -- vim.loop.process handle for npx untun (NOT detached — dies with neovim)
M._tunnel_pid = nil
M._tunnel_url = nil
M._cleanup_registered = false -- guard: VimLeavePre registered at most once per nvim instance

-- NOTE: Path to the tempfile where the bash script writes the port after the server starts.
-- Namespaced by the neovim PID so every neovim instance has its own isolated set of files:
--   port.nvim<PID>            — the TCP port the server is listening on
--   port.nvim<PID>.serve.log  — stdout/stderr of `opencode serve`
--   port.nvim<PID>.server.pid — PID of the `opencode serve` process
-- All three files are deleted by register_cleanup() when neovim exits.
local function get_port_file()
  local nvim_pid = vim.fn.getpid()
  return vim.fn.expand(string.format("~/.local/share/opencode/port.nvim%d", nvim_pid))
end

-- NOTE: Registers a VimLeavePre autocmd that fully tears down everything this neovim instance
-- started: the opencode server, any attached client, and the cloudflare tunnel (if open).
-- Cleanup order:
--   1. Kill all processes bound to our port (covers both `opencode serve` and `opencode attach`)
--   2. Kill the server by its saved PID as a belt-and-suspenders fallback
--   3. Kill the tunnel process tree via pkill -f untun
--   4. Delete PORT_FILE, LOGFILE, and PID_FILE
-- Safe to call multiple times — the guard flag ensures the autocmd is only created once.
function M.register_cleanup()
  if M._cleanup_registered then
    return
  end
  M._cleanup_registered = true

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local port_file = get_port_file()
      local pid_file = port_file .. ".server.pid"

      -- NOTE: Try to recover the server PID from the PID_FILE in case M._server_pid
      -- was never populated (e.g. the server was started in a previous TUI session
      -- within the same neovim instance but the Lua state was not updated).
      local server_pid = M._server_pid
      if not server_pid then
        local pf = io.open(pid_file, "r")
        if pf then
          server_pid = pf:read("*a"):gsub("%s+", "")
          pf:close()
        end
      end

      -- NOTE: Primary kill: find every process listening on our port and send SIGKILL.
      -- This reliably kills both `opencode serve` and any `opencode attach` still running.
      local f = io.open(port_file, "r")
      if f then
        local port = f:read("*a"):gsub("%s+", "")
        f:close()
        if port ~= "" then
          vim.fn.system(string.format("lsof -ti tcp:%s | xargs kill -9 2>/dev/null || true", port))
        end
      end

      -- NOTE: Fallback kill by PID in case lsof missed the server (e.g. it already
      -- closed the port but the process is still alive).
      if server_pid and server_pid ~= "" then
        vim.fn.system(string.format("kill -9 %s 2>/dev/null || true", server_pid))
      end

      -- NOTE: Kill the entire untun/cloudflared process tree if a tunnel was started.
      -- pkill -f is used because npx spawns child processes that share the "untun" string.
      if M._tunnel_pid then
        vim.fn.system("pkill -f untun 2>/dev/null || true")
      end

      -- NOTE: Remove all files owned by this neovim instance.
      os.remove(port_file)
      os.remove(port_file .. ".serve.log")
      os.remove(pid_file)
    end,
  })
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

-- NOTE: Returns the local network IP (192.168.x.x) for display in show_info.
-- Falls back to "127.0.0.1" if detection fails.
local function get_local_ip()
  local handle = io.popen("ipconfig getifaddr en0 2>/dev/null")
  if handle then
    local ip = handle:read("*a"):gsub("%s+", "")
    handle:close()
    if ip ~= "" then
      return ip
    end
  end
  return "127.0.0.1"
end

-- NOTE: Returns the server URL for this neovim instance.
-- Tries M._port first (already cached in Lua state), then falls back to reading
-- PORT_FILE from disk (set by the bash script after `opencode serve` starts).
-- Returns nil if the server has not been started yet for this instance.
function M.get_server_url()
  if M._port then
    return string.format("http://127.0.0.1:%d", M._port)
  end
  local f = io.open(get_port_file(), "r")
  if f then
    local p = f:read("*a"):gsub("%s+", "")
    f:close()
    local port = tonumber(p)
    if port then
      M._port = port
      return string.format("http://127.0.0.1:%d", port)
    end
  end
  return nil
end

-- NOTE: Called by the on_open hook in local_config.lua each time the OpenCode TUI is opened.
-- If M._port is already known (server was started earlier in this neovim session), we write
-- the port back to PORT_FILE so the bash script's fast path can find it immediately and
-- skip starting a new server. Also arms the VimLeavePre cleanup on the first call.
function M.on_open()
  if M._port then
    local port_file = get_port_file()
    local dir = vim.fn.fnamemodify(port_file, ":h")
    vim.fn.mkdir(dir, "p")
    local f = io.open(port_file, "w")
    if f then
      f:write(tostring(M._port))
      f:close()
    end
  end
  -- NOTE: Arm cleanup on first open. register_cleanup() is idempotent.
  M.register_cleanup()
end

-- NOTE: Returns the full bash script used as cli_cmd for cli-integration.
-- WARN: cli-integration appends extra args (e.g. " -s <session_id>") as raw text after
-- cli_cmd. The script is wrapped in a shell function so those appended args become
-- positional parameters ($@) forwarded to `opencode attach`.
--
-- Lifecycle per neovim instance:
--   Fast path  — PORT_FILE exists AND the server responds on that port:
--                skip startup, exec `opencode attach` immediately.
--                This is the normal case when the TUI is closed (Ctrl+C kills the client
--                but leaves the server running) and then re-opened.
--   Slow path  — PORT_FILE absent or server unreachable:
--                start `opencode serve --port 0` in background, poll LOGFILE for the
--                assigned port (up to 5s), write PORT_FILE and PID_FILE, then attach.
--
-- Files written (all under ~/.local/share/opencode/, namespaced by nvim PID):
--   PORT_FILE        — the TCP port the server is listening on
--   LOGFILE          — stdout/stderr of `opencode serve`
--   PID_FILE         — PID of the `opencode serve` process (read by register_cleanup)
function M.get_cli_cmd()
  local username = M.OPENCODE_SERVER_USERNAME
  local password = M.OPENCODE_SERVER_PASSWORD
  local mcp_config = OPENCODE_MCP_CONFIG_FILE

  -- NOTE: The script body is wrapped in oc__main() so cli-integration's appended args
  -- (e.g. "-s <session_id>") become positional parameters and can be forwarded via "$@"
  -- to `opencode attach` without any string manipulation.
  return string.format(
    [[oc__main() {
    echo "\n\n\n\n\n\n\n\n\n\n\n"
    export OPENCODE_SERVER_USERNAME=%s
    export OPENCODE_SERVER_PASSWORD=%s
    PORT_FILE="%s"

    # NOTE: Set OC_DEBUG=1 to enable debug logging to /tmp/opencode-debug-<pid>.log.
    # Useful for diagnosing server startup, port detection, and health-check issues.
    OC_DEBUG=%d
    OC_DEBUG_LOG="/tmp/opencode-debug-$$.log"

    # NOTE: Conditional logger — writes timestamped entries only when OC_DEBUG=1.
    # Uses "|| true" to ensure the function never returns a non-zero exit code,
    # which would affect the script's final exit status.
    _oc_log() { [ "$OC_DEBUG" = "1" ] && echo "[$(date '+%%H:%%M:%%S')] $*" >> "$OC_DEBUG_LOG" || true; }

    _oc_log "=== oc__main started ==="
    _oc_log "PORT_FILE=$PORT_FILE"
    _oc_log "SHELL=$SHELL (pid=$$)"
    _oc_log "args=$*"

    # NOTE: Each neovim instance has its own PORT_FILE (namespaced by nvim PID),
    # so multiple neovim instances never share a server — each owns and cleans up its own.
    # LOGFILE receives stdout/stderr from `opencode serve` and is parsed to detect the port.
    # PID_FILE stores the server PID so the Lua cleanup can kill it even if M._server_pid
    # was never populated (e.g. neovim crashed and was reopened with the same PID file present).
    LOGFILE="${PORT_FILE}.serve.log"
    PID_FILE="${PORT_FILE}.server.pid"

    # NOTE: Portable TCP health-check — tries nc first (works on macOS and most Linux),
    # then bash /dev/tcp (bash builtin, no external tool needed), then python3 as last resort.
    _oc_port_alive() {
      local port="$1"
      nc -z 127.0.0.1 "$port" 2>/dev/null && return 0
      bash -c "(echo >/dev/tcp/127.0.0.1/$port)" 2>/dev/null && return 0
      python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1',$port)); s.close()" 2>/dev/null && return 0
      return 1
    }

    # NOTE: Fast path — if PORT_FILE exists and the server is alive, attach immediately.
    # This is the common case: the TUI was closed (Ctrl+C kills `opencode attach` but
    # leaves `opencode serve` running), and the user re-opens it with <leader>aa.
    # on_open() in Lua also pre-writes the PORT_FILE when M._port is already known,
    # ensuring the fast path succeeds even if PORT_FILE was removed by an earlier cleanup.
    if [ -f "$PORT_FILE" ]; then
      EXISTING_PORT=$(cat "$PORT_FILE" 2>/dev/null)
      _oc_log "PORT_FILE exists, EXISTING_PORT=$EXISTING_PORT"
      if [ -n "$EXISTING_PORT" ] && _oc_port_alive "$EXISTING_PORT"; then
        _oc_log "FAST PATH: server alive on port $EXISTING_PORT, attaching"
        echo "Server already running. Attaching OpenCode CLI..."
        exec opencode attach "http://127.0.0.1:$EXISTING_PORT" "$@"
      else
        _oc_log "SLOW PATH: port check failed (port=$EXISTING_PORT)"
      fi
    else
      _oc_log "SLOW PATH: PORT_FILE does not exist"
    fi

    # NOTE: Slow path — no running server found. Start a fresh `opencode serve`.
    # nohup + /dev/null stdin + redirect to LOGFILE ensures the process survives
    # terminal detach. `disown` removes it from the shell's job table so it won't
    # receive SIGHUP when the shell exits. The server PID is written to PID_FILE
    # immediately so register_cleanup() can kill it on neovim exit even if the
    # server crashes before writing the port.
    _oc_log "Starting server, LOGFILE=$LOGFILE"
    echo "Starting OpenCode server. Please wait..."

    # NOTE: nohup + stdin from /dev/null + stdout/stderr to LOGFILE ensures the server
    # survives terminal close. setsid is unnecessary because nohup already ignores SIGHUP.
    nohup env OPENCODE_CONFIG=%s opencode serve --port 0 --hostname 0.0.0.0 --mdns --print-logs </dev/null >"$LOGFILE" 2>&1 &
    SERVER_PID=$!
    disown $SERVER_PID 2>/dev/null
    echo "$SERVER_PID" > "$PID_FILE"
    _oc_log "Server PID=$SERVER_PID (nohup + disown), PID_FILE written"

    # NOTE: Poll LOGFILE for up to 5s (50 × 100ms) waiting for the "listening on" line
    # that contains the dynamically assigned port. Port 0 means the OS picks a free port,
    # so we must parse it from the log rather than using a fixed value.
    PORT=""
    for i in $(seq 1 50); do
      sleep 0.1
      PORT=$(grep -o 'listening on http[s]*://[^:]*:\([0-9]*\)' "$LOGFILE" 2>/dev/null | grep -o '[0-9]*$' | head -1)
      [ -n "$PORT" ] && break
    done

    if [ -z "$PORT" ]; then
      _oc_log "ERROR: could not detect port after 5s"
      echo "ERROR: Could not detect opencode server port after 5s" >&2
      exit 1
    fi
    mkdir -p $(dirname "$PORT_FILE")
    echo "$PORT" > "$PORT_FILE"
    _oc_log "Server started on port $PORT, PORT_FILE written"

    echo "Starting OpenCode CLI..."

    opencode attach "http://127.0.0.1:$PORT" "$@"
    _oc_log "opencode attach exited with code $?"
  }
  oc__main]],
    username,
    password,
    get_port_file(),
    OC_DEBUG and 1 or 0,
    mcp_config
  )
end

-- NOTE: Toggles the cloudflare tunnel via `npx untun`.
-- If a tunnel is already active (M._tunnel_handle is set), kills the entire untun/cloudflared
-- process tree and clears state. Otherwise starts a new tunnel pointing at this instance's
-- server port (M._port). The tunnel handle is NOT detached so it dies if neovim exits
-- without an explicit stop; register_cleanup() also kills it via pkill -f untun.
function M.toggle_tunnel()
  -- NOTE: SIGTERM to the npx handle alone does NOT propagate to the cloudflared child process.
  -- pkill -f untun kills the entire process tree reliably.
  if M._tunnel_handle then
    vim.fn.jobstart({ "pkill", "-f", "untun" }, {
      on_exit = function()
        vim.schedule(function()
          M._tunnel_handle = nil
          M._tunnel_pid = nil
          M._tunnel_url = nil
          vim.notify("Tunnel stopped", vim.log.levels.INFO)
        end)
      end,
    })
    return
  end

  local server_url = M.get_server_url()
  if not server_url then
    vim.notify("OpenCode server not running. Open OpenCode first with <leader>aa", vim.log.levels.WARN)
    return
  end

  local tunnel_target_url = string.format("http://localhost:%d", M._port)

  local stdin_pipe = vim.loop.new_pipe(false)
  local stdout_pipe = vim.loop.new_pipe(false)
  local stderr_pipe = vim.loop.new_pipe(false)

  if not stdin_pipe or not stdout_pipe or not stderr_pipe then
    vim.notify("Failed to create pipes for tunnel", vim.log.levels.ERROR)
    return
  end

  local handle, pid
  handle, pid = vim.loop.spawn("npx", {
    args = { "untun", "tunnel", tunnel_target_url },
    -- NOTE: NOT detached — tunnel dies when neovim exits
    stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
    -- Explicitly provide optional uv.spawn options to satisfy static checkers
    env = nil,
    cwd = nil,
    uid = nil,
    gid = nil,
    verbatim = false,
    detached = false,
    hide = false,
  }, function()
    vim.schedule(function()
      M._tunnel_handle = nil
      M._tunnel_pid = nil
      M._tunnel_url = nil
    end)
    if handle then
      handle:close()
    end
    stdin_pipe:close()
    stdout_pipe:close()
    stderr_pipe:close()
  end)

  if not handle then
    vim.notify("Failed to start tunnel", vim.log.levels.ERROR)
    stdin_pipe:close()
    stdout_pipe:close()
    stderr_pipe:close()
    return
  end

  M._tunnel_handle = handle
  M._tunnel_pid = pid

  -- NOTE: Accept cloudflared/untun license terms automatically
  stdin_pipe:write("y\n", function() end)

  vim.notify("Starting tunnel...", vim.log.levels.INFO)

  local url_buffer = ""

  local function try_capture_url(data)
    if not data or M._tunnel_url then
      return
    end
    url_buffer = url_buffer .. data
    local url = url_buffer:match("https://[%w%-]+%.trycloudflare%.com")
    if url then
      vim.schedule(function()
        M._tunnel_url = url
        vim.fn.setreg("+", url)
        vim.notify("Tunnel active: " .. url .. " (copied to clipboard)", vim.log.levels.INFO)
      end)
    end
  end

  -- NOTE: untun may output the URL to stdout or stderr depending on version
  vim.loop.read_start(stdout_pipe, function(err, data)
    if not err then
      try_capture_url(data)
    end
  end)

  vim.loop.read_start(stderr_pipe, function(err, data)
    if not err then
      try_capture_url(data)
    end
  end)
end

-- NOTE: Shows a floating window in the top-right corner with the server local URL and tunnel status.
-- Keymaps shown in the title: u copies the local URL, t copies the tunnel URL.
-- <CR> and <Esc> close the window.
function M.show_info()
  local server_url = M.get_server_url()
  if not server_url then
    vim.notify("OpenCode server not running", vim.log.levels.WARN)
    return
  end

  local local_ip = get_local_ip()
  local local_url = string.format("http://%s:%d", local_ip, M._port)
  local tunnel_status = M._tunnel_url or "Closed"

  local lines = {
    " Local:  " .. local_url,
    " Tunnel: " .. tunnel_status,
  }

  local width = 0
  for _, line in ipairs(lines) do
    if #line > width then
      width = #line
    end
  end
  width = width + 2

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = 1,
    col = vim.o.columns - width - 2,
    width = math.max(width, 48),
    height = #lines,
    style = "minimal",
    border = "rounded",
    -- NOTE: Using Nerd Font CircleInfo glyph directly as requested
    title = "    u: Copy local URL │ t: Copy tunnel URL ",
    title_pos = "center",
  })

  local opts = { nowait = true, noremap = true, silent = true, buffer = buf }

  vim.keymap.set("n", "u", function()
    vim.fn.setreg("+", local_url)
    vim.notify("Local URL copied: " .. local_url, vim.log.levels.INFO)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, opts)

  vim.keymap.set("n", "t", function()
    if M._tunnel_url then
      vim.fn.setreg("+", M._tunnel_url)
      vim.notify("Tunnel URL copied: " .. M._tunnel_url, vim.log.levels.INFO)
    else
      vim.notify("No tunnel active", vim.log.levels.WARN)
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, opts)

  local timer = nil
  local function close()
    if timer then
      pcall(function()
        timer:stop()
        timer:close()
      end)
      timer = nil
    end
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  vim.keymap.set("n", "<CR>", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)

  -- Auto-close after 5 seconds to avoid lingering UI
  timer = vim.loop.new_timer()
  if timer then
    timer:start(
      5000,
      0,
      vim.schedule_wrap(function()
        close()
      end)
    )
  end
end

-- NOTE: Convert a Unix millisecond timestamp to a sortable ISO-like string
-- and a formatted display pair (date, time).
local function parse_timestamp(ts_ms)
  local n = tonumber(ts_ms)
  if not n or n == 0 then
    return "0000-00-00T00:00:00", "Unknown", ""
  end
  local epoch = n / 1000
  local iso = os.date("!%Y-%m-%dT%H:%M:%S", epoch)
  local date = os.date("!%Y-%m-%d", epoch)
  local time = os.date("!%H:%M", epoch)
  return iso, date, time
end

-- NOTE: Query all sessions from the SQLite database.
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
    local id, rest = line:match("^(ses_[^|]+)|(.+)$")
    if id and rest then
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

-- NOTE: Helper — returns the cwd of a process (macOS + Linux).
-- Uses lsof on macOS, /proc on Linux. Returns "" on failure.
-- `is_darwin` must be passed by the caller to avoid repeated uname calls.
local function get_proc_cwd(pid, is_darwin)
  if is_darwin then
    local lines = vim.fn.systemlist(string.format("lsof -a -d cwd -p %s -F n 2>/dev/null", pid))
    for _, l in ipairs(lines) do
      local path = l:match("^n(.+)$")
      if path then
        return path
      end
    end
  else
    local link = vim.fn.resolve(string.format("/proc/%s/cwd", pid))
    if link ~= "" then
      return link
    end
  end
  return ""
end

-- NOTE: Interactive inspector for ALL opencode-related processes on the machine.
-- Lists: opencode serve (server), opencode attach (client), and npx untun (tunnel).
-- Shows type, PID, directory, and allows killing one-by-one or all at once.
function M.inspect_opencode_processes()
  local entries = {}
  local is_darwin = vim.fn.system("uname -s"):gsub("%s+", "") == "Darwin"

  -- Collect all opencode processes (server + client) via ps
  local oc_lines = vim.fn.systemlist("ps -eo pid,args | grep -E 'opencode (serve|attach)' | grep -v grep 2>/dev/null")
  for _, line in ipairs(oc_lines) do
    local pid, cmd = line:match("^%s*(%d+)%s+(.*)$")
    if pid and cmd then
      local kind
      if cmd:find("opencode serve", 1, true) then
        kind = "server"
      elseif cmd:find("opencode attach", 1, true) then
        kind = "client"
      end
      if kind then
        local cwd = get_proc_cwd(pid, is_darwin)
        local dir = cwd ~= "" and vim.fn.fnamemodify(cwd, ":~") or "?"
        table.insert(entries, { kind = kind, pid = pid, dir = dir, cmd = cmd })
      end
    end
  end

  -- Collect all untun tunnel processes.
  -- NOTE: npx untun spawns two processes (npx parent + cloudflared child), both
  -- matching "untun". We keep only the npx/node parent (the one whose command
  -- starts with "npx" or "node") and count siblings so we can show "(+N children)"
  -- in the label. When killing we use pkill -f untun to kill the whole tree.
  local tun_lines = vim.fn.systemlist("ps -eo pid,args | grep untun | grep -v grep 2>/dev/null")
  local tun_all = {}
  for _, line in ipairs(tun_lines) do
    local pid, cmd = line:match("^%s*(%d+)%s+(.*)$")
    if pid and cmd then
      table.insert(tun_all, { pid = pid, cmd = cmd })
    end
  end
  -- Identify the parent: npm/npx is the top-level launcher
  local tun_parent = nil
  for _, t in ipairs(tun_all) do
    if t.cmd:match("^npm") or t.cmd:match("^npx") then
      tun_parent = t
      break
    end
  end
  -- Fallback: if no npx/node found, take the lowest PID as parent
  if not tun_parent and #tun_all > 0 then
    table.sort(tun_all, function(a, b)
      return tonumber(a.pid) < tonumber(b.pid)
    end)
    tun_parent = tun_all[1]
  end
  if tun_parent then
    local child_count = #tun_all - 1
    local cwd = get_proc_cwd(tun_parent.pid, is_darwin)
    local dir = cwd ~= "" and vim.fn.fnamemodify(cwd, ":~") or "?"
    local extra = child_count > 0 and string.format(" (+%d child)", child_count) or ""
    table.insert(
      entries,
      { kind = "tunnel", pid = tun_parent.pid, dir = dir, cmd = tun_parent.cmd, extra = extra, kill_tree = true }
    )
  end

  if #entries == 0 then
    vim.notify("No opencode processes found", vim.log.levels.INFO)
    return
  end

  -- NOTE: Helper to reset this instance's runtime state if the killed pid matches.
  local function maybe_clear_state(e)
    if e.kind == "server" and M._port then
      -- If the killed server was the one we track for this project, clear port state.
      -- We can't know for certain (different project may share port), so clear conservatively.
      M._port = nil
    elseif e.kind == "tunnel" and M._tunnel_pid == tonumber(e.pid) then
      M._tunnel_pid = nil
      M._tunnel_handle = nil
      M._tunnel_url = nil
    end
  end

  local function kill_entry(e)
    if e.kill_tree then
      vim.fn.system("pkill -f untun 2>/dev/null || true")
    else
      vim.fn.system(string.format("kill %s 2>/dev/null || true", e.pid))
    end
    maybe_clear_state(e)
  end

  -- Build display strings: [type] pid  dir  (extra)
  local options = { "Kill All", "Cancel" }
  for _, e in ipairs(entries) do
    local label = string.format("[%-6s] pid %-6s  %s%s", e.kind, e.pid, e.dir, e.extra or "")
    table.insert(options, label)
  end

  vim.ui.select(
    options,
    { prompt = "Inspect OpenCode processes (Kill All / select to kill one):" },
    function(choice, idx)
      if not choice or choice == "Cancel" then
        return
      end

      if choice == "Kill All" then
        vim.ui.select(
          { "Yes, kill all", "No, cancel" },
          { prompt = string.format("Confirm: kill ALL %d processes?", #entries) },
          function(confirm)
            if not confirm or not confirm:match("^Yes") then
              vim.notify("Cancelled", vim.log.levels.INFO)
              return
            end
            for _, e in ipairs(entries) do
              kill_entry(e)
            end
            vim.notify(string.format("Killed %d process(es)", #entries), vim.log.levels.INFO)
          end
        )
        return
      end

      -- Single selection: idx 1 = "Kill All", 2 = "Cancel", 3+ = entries
      local entry = entries[idx - 2]
      if not entry then
        vim.notify("Selection error", vim.log.levels.ERROR)
        return
      end

      vim.ui.select(
        { "Yes, kill", "No, cancel" },
        { prompt = string.format("Kill [%s] pid %s  %s ?", entry.kind, entry.pid, entry.dir) },
        function(confirm)
          if not confirm or not confirm:match("^Yes") then
            vim.notify("Cancelled", vim.log.levels.INFO)
            return
          end
          kill_entry(entry)
          vim.notify(string.format("Killed [%s] pid %s", entry.kind, entry.pid), vim.log.levels.INFO)
        end
      )
    end
  )
end

return M
