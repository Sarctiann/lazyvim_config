local M = {}

-- WARN:
-- configure your nvim-mcp-server to work with auggie by going to the directory
-- where you have your augment cache dir and running this command in your terminal (only needs to be done once):
--    auggie --augment-cache-dir .augment_work_profile mcp add nvim -- nvim-mcp --connect auto
-- It should result in the following entry in your ~/.gemini/settings.json file:
--   {
--     ...
--     "mcpServers": {
--       "nvim": {
--         "type": "stdio",
--         "command": "npx",
--         "args": [
--           "-y",
--           "nvim-mcp-server"
--          ],
--         "env": {
--           "NVIM": "$NVIM"
--         }
--       }
--     }
--     ...
--   }

-- NOTE: Helper function to get the augment cache directory
-- Returns the cache directory path based on current working directory and company_dirs
function M.get_augment_cache_dir()
  local current_dir = vim.fn.getcwd()
  local lc_ok, local_config = pcall(require, "local_config")
  local company_dirs = (lc_ok and local_config and local_config.company_dirs) or {}

  for _, dir in ipairs(company_dirs) do
    local _, found = string.find(current_dir, dir)
    if found then
      return string.sub(current_dir, 1, found) .. "/.augment_work_profile"
    end
  end

  -- Default to standard augment directory if no company dir is found
  return nil
end

-- NOTE: Function to delete all Augment sessions with confirmation
-- @param cache_dir (optional) The augment cache directory path. If nil, uses default or auto-detected path
function M.delete_all_augment_sessions(cache_dir)
  cache_dir = cache_dir or M.get_augment_cache_dir()

  vim.ui.select({ "Yes", "No" }, {
    prompt = "⚠️  Delete ALL Augment sessions? This action cannot be undone!",
  }, function(choice)
    if choice == "Yes" then
      local cmd = cache_dir and string.format("! auggie --augment-cache-dir %s session delete --all", cache_dir)
        or "! auggie session delete --all"
      vim.cmd(cmd)
      vim.notify("✓ All Augment sessions have been deleted", vim.log.levels.INFO)
    else
      vim.notify("Deletion cancelled", vim.log.levels.INFO)
    end
  end)
end

-- NOTE: Function to manage Augment sessions (Uses plugin hooks with Lazy Load)
-- @param show_all (optional) Whether to show all sessions or just current workspace
-- @param cache_dir (optional) The augment cache directory path. If nil, uses default or auto-detected path
function M.manage_augment_sessions(show_all, cache_dir)
  cache_dir = cache_dir or M.get_augment_cache_dir()

  local sessions_dir = cache_dir and (cache_dir .. "/sessions") or vim.fn.expand("~/.augment/sessions")

  local resume_cmd = "CLIIntegration open_root Augment session resume %s"

  require("cli-integration.hooks").manage_sessions({
    name = "Augment",
    resume_cmd = resume_cmd,
    show_all = show_all,
    get_sessions = function()
      local sessions = {}
      local files = vim.fn.glob(sessions_dir .. "/*.json", false, true)

      for _, file_path in ipairs(files) do
        local f = io.open(file_path, "r")
        if f then
          local content = f:read("*all")
          f:close()
          local ok, data = pcall(vim.json.decode, content)

          if ok and data then
            local modified = data.modified or data.created or "Unknown"
            local session_id = data.sessionId or vim.fn.fnamemodify(file_path, ":t:r")

            local session_workspace = "Unknown"
            if data.chatHistory and #data.chatHistory > 0 then
              local first_exchange = data.chatHistory[1].exchange
              if first_exchange and first_exchange.request_nodes then
                for _, node in ipairs(first_exchange.request_nodes) do
                  if node.ide_state_node and node.ide_state_node.workspace_folders then
                    local folders = node.ide_state_node.workspace_folders
                    if folders[1] and folders[1].repository_root then
                      session_workspace = folders[1].repository_root
                      break
                    end
                  end
                end
              end
            end

            local first_message = "No messages"
            if data.chatHistory and #data.chatHistory > 0 then
              local exchange = data.chatHistory[1].exchange
              if exchange then
                -- Try to use customTitle first, fallback to request_message
                if data.customTitle and data.customTitle ~= "" then
                  first_message = data.customTitle:gsub("\n", " "):sub(1, 60)
                  if #data.customTitle > 60 then
                    first_message = '" ' .. first_message .. '... "'
                  else
                    first_message = '" ' .. first_message .. ' "'
                  end
                elseif exchange.request_message then
                  first_message = exchange.request_message:gsub("\n", " "):sub(1, 60)
                  if #exchange.request_message > 60 then
                    first_message = first_message .. "..."
                  end
                end
              end
            end

            local date = modified:match("(%d%d%d%d%-%d%d%-%d%d)") or "Unknown"
            local time = modified:match("T(%d%d:%d%d)") or ""

            table.insert(sessions, {
              id = session_id,
              modified = modified,
              workspace = session_workspace,
              file_path = file_path,
              display = string.format("[%s %s] %s", date, time, first_message),
            })
          end
        end
      end
      return sessions
    end,
    delete_cmd = function(session)
      vim.fn.delete(session.file_path)
      vim.notify("✓ Session deleted: " .. session.id, vim.log.levels.INFO)
    end,
  })
end

-- NOTE: Function to inject env vars into augment's settings.json MCP server config
-- @param cache_dir string Path to the augment cache directory (contains settings.json)
-- @param env_vars table Table with structure { mcp_server_name = { VAR = value } }
--   Overwrites matching variables or adds them if they don't exist
function M.on_open_auggie(cache_dir, env_vars)
  local settings_path = cache_dir .. "/settings.json"
  local f = io.open(settings_path, "r")
  if not f then
    vim.notify("on_open_auggie: could not open " .. settings_path, vim.log.levels.WARN)
    return
  end

  local content = f:read("*all")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if ok and data then
    data.mcpServers = data.mcpServers or {}
    for server_name, vars in pairs(env_vars) do
      if data.mcpServers[server_name] then
        data.mcpServers[server_name].env = data.mcpServers[server_name].env or {}
        for var_name, value in pairs(vars) do
          data.mcpServers[server_name].env[var_name] = value
        end
      end
    end

    local new_content = vim.json.encode(data)
    local wf = io.open(settings_path, "w")
    if wf then
      wf:write(new_content)
      wf:close()
    else
      vim.notify("on_open_auggie: could not write " .. settings_path, vim.log.levels.ERROR)
    end
  else
    vim.notify("on_open_auggie: failed to parse settings.json", vim.log.levels.ERROR)
  end
end

return M
