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
-- These are NOT persisted — they die with neovim.
-- _port is written by get_cli_cmd's shell script into a tempfile and read back by Lua
-- for toggle_tunnel and show_info.
M._port = nil
M._tunnel_handle = nil -- vim.loop.process handle (non-detached, dies with neovim)
M._tunnel_pid = nil
M._tunnel_url = nil
M._refcount_registered = false -- tracks whether this instance already incremented the refcount

-- NOTE: Path to the tempfile where the shell script writes the captured port.
-- Namespaced by a hash of the working directory so each project gets its own server,
-- but multiple neovim instances in the same directory share the same server.
local function get_port_file()
  local cwd = vim.fn.getcwd()
  -- NOTE: Simple djb2 hash to avoid filesystem-unsafe characters from the path
  local hash = 5381
  for i = 1, #cwd do
    hash = ((hash * 33) + string.byte(cwd, i)) % 0x100000000
  end
  return vim.fn.expand(string.format("~/.local/share/opencode/port.%x", hash))
end

-- NOTE: Atomically adjust the refcount file for the current PORT_FILE.
-- Uses mkdir as an atomic lock (POSIX-portable, works on macOS without flock).
-- Returns the new refcount value.
local function adjust_refcount(delta)
  local refcount_file = get_port_file() .. ".refcount"
  local lock_dir = get_port_file() .. ".lock"
  local dir = vim.fn.fnamemodify(refcount_file, ":h")
  vim.fn.mkdir(dir, "p")

  -- NOTE: mkdir is atomic on all POSIX systems — it fails if the dir already exists.
  -- Spin with a short sleep until we acquire the lock.
  local cmd = string.format(
    [[
      LOCK="%s"
      RCFILE="%s"
      DELTA=%d
      tries=0
      while ! mkdir "$LOCK" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -gt 100 ] && echo "0" && exit 1
        sleep 0.01
      done
      trap 'rmdir "$LOCK" 2>/dev/null' EXIT
      count=0
      [ -f "$RCFILE" ] && count=$(cat "$RCFILE" 2>/dev/null || echo 0)
      count=$(( count + DELTA ))
      [ "$count" -lt 0 ] && count=0
      echo "$count" > "$RCFILE"
      echo "$count"
    ]],
    lock_dir,
    refcount_file,
    delta
  )
  local result = vim.fn.system({ "bash", "-c", cmd })
  return tonumber(result:match("%d+")) or 0
end

-- NOTE: Increment refcount and register a VimLeavePre autocmd to decrement on exit.
-- Safe to call multiple times — only registers once per nvim instance.
function M.register_refcount()
  if M._refcount_registered then
    return
  end
  M._refcount_registered = true
  adjust_refcount(1)

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local new_count = adjust_refcount(-1)
      if new_count <= 0 then
        local port_file = get_port_file()
        -- NOTE: Kill the server process before cleaning up files.
        -- Read the port and find the process listening on it.
        local f = io.open(port_file, "r")
        if f then
          local port = f:read("*a"):gsub("%s+", "")
          f:close()
          if port ~= "" then
            vim.fn.system(string.format("lsof -ti tcp:%s | xargs kill 2>/dev/null", port))
          end
        end
        os.remove(port_file)
        os.remove(port_file .. ".serve.log")
        os.remove(port_file .. ".refcount")
        vim.fn.delete(port_file .. ".lock", "d")
      end
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

-- NOTE: Returns the server URL using the port read from the tempfile.
-- Returns nil if the port has not been captured yet.
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

-- NOTE: Called by on_open hook in local_config.lua before cli-integration reads cli_cmd.
-- If we already know the port (from a previous open), write it to the port file
-- so the bash script can find it immediately and skip server startup.
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
  -- NOTE: Register refcount on first open so VimLeavePre cleanup is armed
  M.register_refcount()
end

-- NOTE: Returns the full bash script used as cli_cmd for cli-integration.
-- WARN: cli-integration concatenates extra args (e.g. " -s <session_id>") as raw text
-- after cli_cmd. To ensure those args reach `opencode attach`, the script stores them
-- in EXTRA_ARGS by capturing everything after a sentinel comment, then passes them
-- to both the fast path and the normal path.
-- The script:
--   1. Checks if a port file exists and the server responds via /dev/tcp (fast path)
--   2. If not, starts `opencode serve` in background and polls for the port (max 5s)
--   3. Writes the captured port to a tempfile so Lua can read it (for toggle_tunnel / show_info)
--   4. Runs `opencode attach` with the correct URL and any extra args
function M.get_cli_cmd()
  local username = M.OPENCODE_SERVER_USERNAME
  local password = M.OPENCODE_SERVER_PASSWORD
  local mcp_config = OPENCODE_MCP_CONFIG_FILE

  -- NOTE: The script is wrapped in a function so cli-integration's appended args
  -- become shell arguments to that function. This is the cleanest way to forward
  -- extra args (like "-s <session_id>") to `opencode attach`.
  return string.format(
    [[oc__main() {
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

    # NOTE: Portable TCP health-check — tries nc -z first (works on macOS BSD nc and most
    # Linux distros), falls back to bash /dev/tcp (bash-only builtin), then to python3 socket
    # as a last resort. This covers macOS, Debian/Ubuntu, Arch, Alpine, and minimal containers.
    _oc_port_alive() {
      local port="$1"
      local rc
      nc -z 127.0.0.1 "$port" 2>/dev/null; rc=$?; _oc_log "  nc -z exit=$rc"
      [ "$rc" -eq 0 ] && return 0
      bash -c "(echo >/dev/tcp/127.0.0.1/$port)" 2>/dev/null; rc=$?; _oc_log "  bash /dev/tcp exit=$rc"
      [ "$rc" -eq 0 ] && return 0
      python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1',$port)); s.close()" 2>/dev/null; rc=$?; _oc_log "  python3 exit=$rc"
      [ "$rc" -eq 0 ] && return 0
      return 1
    }

    # NOTE: Fast path — if port file exists and server responds, skip server startup
    # and attach immediately. This is the common case after the first open.
    if [ -f "$PORT_FILE" ]; then
      EXISTING_PORT=$(cat "$PORT_FILE" 2>/dev/null)
      _oc_log "PORT_FILE exists, EXISTING_PORT=$EXISTING_PORT"
      if [ -n "$EXISTING_PORT" ] && _oc_port_alive "$EXISTING_PORT"; then
        _oc_log "FAST PATH: server alive on port $EXISTING_PORT, attaching"
        echo "\n\nThe Server already exist. Attaching OpenCode CLI...\n\n"
        exec opencode attach "http://127.0.0.1:$EXISTING_PORT" "$@"
      else
        _oc_log "SLOW PATH: port check failed (port=$EXISTING_PORT)"
      fi
    else
      _oc_log "SLOW PATH: PORT_FILE does not exist"
    fi

    # NOTE: Slow path — start a new server in the background.
    # The logfile is per-project (derived from PORT_FILE) so it persists across terminal reopens.
    LOGFILE="${PORT_FILE}.serve.log"
    _oc_log "Starting server, LOGFILE=$LOGFILE"

    echo "\n\nStarting OpenCode server. Please wait...\n\n"

    # NOTE: nohup + stdin from /dev/null + stdout/stderr to logfile ensures the server
    # survives terminal close in both bash and zsh. setsid (Linux) or lack thereof (macOS)
    # is not needed because nohup already ignores SIGHUP.
    nohup env OPENCODE_CONFIG=%s opencode serve --port 0 --hostname 0.0.0.0 --mdns --print-logs </dev/null >"$LOGFILE" 2>&1 &
    SERVER_PID=$!
    disown $SERVER_PID 2>/dev/null
    _oc_log "Server PID=$SERVER_PID (nohup + disown)"

    # NOTE: Poll the server log for up to 5s waiting for the "listening on" line
    # that contains the dynamically assigned port number.
    PORT=""
    for i in $(seq 1 50); do
      sleep 0.1
      PORT=$(grep -o 'listening on http[s]*://[^:]*:\([0-9]*\)' "$LOGFILE" 2>/dev/null | grep -o '[0-9]*$' | head -1)
      [ -n "$PORT" ] && break
    done

    if [ -z "$PORT" ]; then
      _oc_log "ERROR: could not detect port after 5s"
      echo "\n\nERROR: Could not detect opencode server port after 5s\n\n" >&2
      exit 1
    fi
    mkdir -p $(dirname "$PORT_FILE")
    echo "$PORT" > "$PORT_FILE"
    _oc_log "Server started on port $PORT, PORT_FILE written"

    echo "\n\nStarting OpenCode CLI...\n\n"

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

-- NOTE: Toggles the cloudflare tunnel via npx untun.
-- If a tunnel is already active, kills it. Otherwise starts a new one.
-- Reads the port from the tempfile written by the cli_cmd shell script.
function M.toggle_tunnel()
  -- NOTE: Kill existing tunnel if active.
  -- WARN: SIGTERM to the npx handle alone does NOT propagate to the cloudflared child process.
  -- We must pkill -f untun to kill the entire process tree, same approach used in main branch.
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

return M
