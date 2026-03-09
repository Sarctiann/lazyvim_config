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

-- NOTE: Function to manage Augment sessions (list, delete, resume)
function M.manage_augment_sessions(show_all)
  local sessions_dir = vim.fn.expand("~/.augment/sessions")

  if vim.fn.isdirectory(sessions_dir) == 0 then
    vim.notify("No sessions directory found at " .. sessions_dir, vim.log.levels.WARN)
    return
  end

  local session_files = vim.fn.glob(sessions_dir .. "/*.json", false, true)

  if #session_files == 0 then
    vim.notify("No Augment sessions found", vim.log.levels.INFO)
    return
  end

  -- NOTE: Get current git root
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  local current_workspace = git_root and git_root or vim.fn.getcwd()

  local sessions = {}
  for _, file_path in ipairs(session_files) do
    local file = io.open(file_path, "r")
    if file then
      local content = file:read("*all")
      file:close()

      local ok, session_data = pcall(vim.json.decode, content)
      if ok and session_data then
        local modified = session_data.modified or session_data.created or "Unknown"
        local session_id = session_data.sessionId or vim.fn.fnamemodify(file_path, ":t:r")

        -- NOTE: Get workspace from session data
        local session_workspace = "Unknown"
        if session_data.chatHistory and #session_data.chatHistory > 0 then
          local first_exchange = session_data.chatHistory[1].exchange
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

        -- NOTE: Filter by workspace if not showing all
        local should_include = show_all or session_workspace == current_workspace

        if should_include then
          local first_message = "No messages"
          if session_data.chatHistory and #session_data.chatHistory > 0 then
            local first_exchange = session_data.chatHistory[1].exchange
            if first_exchange and first_exchange.request_message then
              first_message = first_exchange.request_message:gsub("\n", " "):sub(1, 60)
              if #first_exchange.request_message > 60 then
                first_message = first_message .. "..."
              end
            end
          end

          local modified_date = modified:match("(%d%d%d%d%-%d%d%-%d%d)") or modified
          local modified_time = modified:match("T(%d%d:%d%d)") or ""

          table.insert(sessions, {
            id = session_id,
            file_path = file_path,
            display = string.format("[%s %s] %s", modified_date, modified_time, first_message),
            modified = modified,
          })
        end
      end
    end
  end

  -- NOTE: If no sessions found for current workspace and not showing all, show all sessions
  if #sessions == 0 and not show_all then
    vim.notify("No sessions found for this workspace, showing all sessions", vim.log.levels.INFO)
    vim.schedule(function()
      manage_augment_sessions(true)
    end)
    return
  end

  if #sessions == 0 then
    vim.notify("No Augment sessions found", vim.log.levels.INFO)
    return
  end

  -- NOTE: Sort by modified date (most recent first)
  table.sort(sessions, function(a, b)
    return a.modified > b.modified
  end)

  local display_items = {}
  for _, session in ipairs(sessions) do
    table.insert(display_items, session.display)
  end

  -- NOTE: Add special items at the beginning
  table.insert(display_items, 1, ">>> 🔄 Toggle All Sessions")
  table.insert(display_items, 2, ">>> ➕ Create New Session")

  local scope_text = show_all and "[All Sessions]" or "[Current Workspace]"

  -- NOTE: Schedule moving to the third item (first session) after the select opens
  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-j><C-j>", true, false, true), "n", false)
  end)

  vim.ui.select(display_items, {
    prompt = "Augment Sessions " .. scope_text .. " (Esc: Cancel)",
  }, function(choice, idx)
    if not choice or not idx then
      return
    end

    -- NOTE: Handle special items
    if idx == 1 then
      -- NOTE: Toggle all sessions
      manage_augment_sessions(not show_all)
      return
    elseif idx == 2 then
      -- NOTE: Create new session
      vim.cmd("CLIIntegration open_root Augment")
      vim.notify("Creating new Augment session", vim.log.levels.INFO)
      return
    end

    -- NOTE: Adjust index for actual sessions (subtract special items)
    local session_idx = idx - 2
    if session_idx < 1 or session_idx > #sessions then
      return
    end

    local session = sessions[session_idx]

    -- NOTE: Show action menu
    vim.ui.select({ "Resume", "Delete", "Go Back" }, {
      prompt = "Action for session (Esc: Cancel)",
    }, function(action)
      if action == "Resume" then
        vim.cmd("CLIIntegration open_root Augment session resume " .. session.id)
        vim.notify("Resuming session: " .. session.id, vim.log.levels.INFO)
        -- NOTE: Focus the CLI integration window after it opens
        vim.defer_fn(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            -- NOTE: Check if it's a terminal buffer (CLI integration uses terminal)
            if vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal" then
              vim.api.nvim_set_current_win(win)
              vim.cmd("startinsert")
              break
            end
          end
        end, 100)
      elseif action == "Delete" then
        vim.ui.select({ "Yes", "No" }, {
          prompt = "⚠️  Delete this session? This action cannot be undone!",
        }, function(confirm)
          if confirm == "Yes" then
            vim.fn.delete(session.file_path)
            vim.notify("✓ Session deleted: " .. session.id, vim.log.levels.INFO)
            vim.schedule(function()
              manage_augment_sessions(show_all)
            end)
          else
            vim.notify("Deletion cancelled", vim.log.levels.INFO)
            vim.schedule(function()
              manage_augment_sessions(show_all)
            end)
          end
        end)
      elseif action == "Go Back" then
        vim.schedule(function()
          manage_augment_sessions(show_all)
        end)
      end
    end)
  end)
end

return M
