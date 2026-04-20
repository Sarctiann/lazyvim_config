return {
  "linw1995/nvim-mcp",
  build = "cargo install --path .",
  config = function()
    -- Build a unique pipe path: same logic as the plugin (git root + pid).
    -- Including the PID ensures no two Neovim instances share the same socket.
    local socket_dir = os.getenv("XDG_RUNTIME_DIR") or os.getenv("TMPDIR") or "/tmp"
    -- Strip trailing slash from socket_dir so paths are consistent
    socket_dir = socket_dir:gsub("/$", "")

    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("%s+$", "")
    if git_root == "" then
      git_root = vim.fn.getcwd()
    end
    local escaped = git_root:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/", "%%")
    local own_pid = tostring(vim.fn.getpid())
    local pipe_path = string.format("%s/nvim-mcp.%s.%s.sock", socket_dir, escaped, own_pid)

    -- Clean up stale sockets for this project prefix (old format without PID,
    -- or sockets from previous PIDs that are no longer running).
    local prefix = string.format("%s/nvim-mcp.%s", socket_dir, escaped)
    local stale = vim.fn.glob(prefix .. "*", false, true)
    for _, sock in ipairs(stale) do
      if sock ~= pipe_path then
        -- Only remove if not held by any live process
        vim.fn.system(string.format("lsof -U 2>/dev/null | grep -qF '%s'", sock))
        if vim.v.shell_error ~= 0 then
          vim.uv.fs_unlink(sock)
        end
      end
    end

    -- Remove our own pipe if it exists but is NOT already in serverlist
    -- (can happen if Neovim crashed before cleaning up the socket file).
    local in_serverlist = vim.tbl_contains(vim.fn.serverlist(), pipe_path)
    if not in_serverlist and vim.uv.fs_stat(pipe_path) then
      vim.uv.fs_unlink(pipe_path)
    end

    -- Skip setup if this instance already registered the pipe (idempotent guard).
    if in_serverlist then
      return
    end

    local ok, err = pcall(function()
      require("nvim-mcp").setup({ pipe = pipe_path })
    end)
    if not ok then
      local msg = tostring(err)
      -- Silence the common "address already in use" failure which occurs when
      -- another MCP server is already active for this workspace. It's non-fatal
      -- and noisy when opening many projects; ignore it silently.
      if not msg:match("address already in use") and not msg:match("Failed to start server") then
        vim.notify("nvim-mcp: failed to start RPC server: " .. msg, vim.log.levels.WARN)
      else
        -- Optionally expose debug info when OC_DEBUG env var is set
        if os.getenv("OC_DEBUG") == "1" then
          vim.notify("nvim-mcp (debug): suppressed start error: " .. msg, vim.log.levels.DEBUG)
        end
      end
    end
  end,
}
