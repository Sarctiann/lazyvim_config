local M = {}

-- NOTE: Function to delete all Augment sessions with confirmation
function M.delete_all_augment_sessions()
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

-- NOTE: Function to manage Augment sessions (Uses plugin hooks with Lazy Load)
function M.manage_augment_sessions(show_all)
  local sessions_dir = vim.fn.expand("~/.augment/sessions")

  require("cli-integration.hooks").manage_sessions({
    name = "Augment",
    resume_cmd = "CLIIntegration open_root Augment session resume %s",
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
              if exchange and exchange.request_message then
                first_message = exchange.request_message:gsub("\n", " "):sub(1, 60)
                if #exchange.request_message > 60 then
                  first_message = first_message .. "..."
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

return M
