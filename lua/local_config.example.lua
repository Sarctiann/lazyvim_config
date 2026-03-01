-- NOTE: Function to delete all Gemini sessions for the current project
local function delete_all_gemini_sessions()
  vim.ui.select({ "Yes", "No" }, {
    prompt = "⚠️  Delete ALL Gemini sessions for this project? This action cannot be undone!",
  }, function(choice)
    if choice == "Yes" then
      local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
      local current_path = git_root and git_root or vim.fn.getcwd()

      -- Get project name from projects.json
      local projects_file = vim.fn.expand("~/.gemini/projects.json")
      local f = io.open(projects_file, "r")
      if not f then
        vim.notify("Could not read projects.json", vim.log.levels.ERROR)
        return
      end
      local content = f:read("*all")
      f:close()

      local ok, projects_data = pcall(vim.json.decode, content)
      if not ok or not projects_data or not projects_data.projects then
        vim.notify("Error parsing projects.json", vim.log.levels.ERROR)
        return
      end

      local project_name = projects_data.projects[current_path]
      if not project_name then
        vim.notify("Could not find project name for: " .. current_path, vim.log.levels.ERROR)
        return
      end

      local chats_dir = vim.fn.expand("~/.gemini/tmp/" .. project_name .. "/chats")
      if vim.fn.isdirectory(chats_dir) == 0 then
        vim.notify("No sessions directory found for " .. project_name, vim.log.levels.INFO)
        return
      end

      local session_files = vim.fn.glob(chats_dir .. "/*.json", false, true)
      local deleted_count = 0
      for _, file in ipairs(session_files) do
        local success = vim.fn.delete(file)
        if success == 0 then
          deleted_count = deleted_count + 1
        end
      end

      vim.notify("✓ " .. deleted_count .. " session(s) for " .. project_name .. " deleted", vim.log.levels.INFO)
    else
      vim.notify("Deletion cancelled", vim.log.levels.INFO)
    end
  end)
end

-- NOTE: Optimized Gemini session manager (Reads JSON directly for speed)
local function manage_gemini_sessions(show_all)
  local base_dir = vim.fn.expand("~/.gemini/tmp")
  local projects_file = vim.fn.expand("~/.gemini/projects.json")

  -- Load project mapping
  local pf = io.open(projects_file, "r")
  if not pf then
    vim.notify("Could not read projects.json", vim.log.levels.ERROR)
    return
  end
  local p_content = pf:read("*all")
  pf:close()

  local p_ok, projects_data = pcall(vim.json.decode, p_content)
  if not p_ok or not projects_data or not projects_data.projects then
    vim.notify("Error parsing projects.json", vim.log.levels.ERROR)
    return
  end

  -- Get current project name
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  local current_path = git_root and git_root or vim.fn.getcwd()
  local current_project = projects_data.projects[current_path]

  -- Collect session files
  local sessions = {}
  local projects_to_scan = {}

  if show_all then
    for _, name in pairs(projects_data.projects) do
      table.insert(projects_to_scan, name)
    end
    -- Also scan directories in tmp that might not be in projects.json
    local tmp_dirs = vim.fn.glob(base_dir .. "/*", false, true)
    for _, dir in ipairs(tmp_dirs) do
      if vim.fn.isdirectory(dir) == 1 then
        local name = vim.fn.fnamemodify(dir, ":t")
        local found = false
        for _, p in ipairs(projects_to_scan) do
          if p == name then
            found = true
            break
          end
        end
        if not found and name ~= "bin" then
          table.insert(projects_to_scan, name)
        end
      end
    end
  elseif current_project then
    table.insert(projects_to_scan, current_project)
  end

  for _, project_name in ipairs(projects_to_scan) do
    local chats_dir = base_dir .. "/" .. project_name .. "/chats"
    if vim.fn.isdirectory(chats_dir) == 1 then
      local session_files = vim.fn.glob(chats_dir .. "/*.json", false, true)
      for _, file_path in ipairs(session_files) do
        local f = io.open(file_path, "r")
        if f then
          local content = f:read("*all")
          f:close()
          local ok, data = pcall(vim.json.decode, content)
          if ok and data then
            local last_updated = data.lastUpdated or data.startTime or "0000-00-00"
            local session_id = data.sessionId or vim.fn.fnamemodify(file_path, ":t:r")

            -- Extract first message snippet
            local first_message = "No messages"
            if data.messages and #data.messages > 0 then
              for _, msg in ipairs(data.messages) do
                if msg.type == "user" and msg.content then
                  local text = ""
                  if type(msg.content) == "table" then
                    for _, part in ipairs(msg.content) do
                      if part.text then
                        text = text .. part.text
                      end
                    end
                  elseif type(msg.content) == "string" then
                    text = msg.content
                  end

                  if text ~= "" then
                    first_message = text:gsub("\n", " "):sub(1, 60)
                    if #text > 60 then
                      first_message = first_message .. "..."
                    end
                    break
                  end
                end
              end
            end

            local date = last_updated:match("(%d%d%d%d%-%d%d%-%d%d)") or "Unknown"
            local time = last_updated:match("T(%d%d:%d%d)") or ""

            table.insert(sessions, {
              id = session_id,
              file_path = file_path,
              modified = last_updated,
              display = string.format("[%s %s] (%s) %s", date, time, project_name, first_message),
            })
          end
        end
      end
    end
  end

  if #sessions == 0 and not show_all then
    vim.notify("No sessions for current project, showing all", vim.log.levels.INFO)
    return manage_gemini_sessions(true)
  end

  if #sessions == 0 then
    vim.notify("No Gemini sessions found", vim.log.levels.INFO)
    return
  end

  -- Sort by most recent
  table.sort(sessions, function(a, b)
    return a.modified > b.modified
  end)

  local display_items = { ">>> 🔄 Toggle All Sessions", ">>> ➕ Create New Session" }
  for _, s in ipairs(sessions) do
    table.insert(display_items, s.display)
  end

  vim.schedule(function()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-j><C-j>", true, false, true), "n", false)
  end)

  vim.ui.select(display_items, {
    prompt = "Gemini Sessions " .. (show_all and "[All]" or "[Project]") .. " (Esc: Cancel)",
  }, function(choice, idx)
    if not choice or not idx then
      return
    end
    if idx == 1 then
      return manage_gemini_sessions(not show_all)
    end
    if idx == 2 then
      return vim.cmd("CLIIntegration open_root Gemini")
    end

    local session = sessions[idx - 2]
    vim.ui.select({ "Resume", "Delete", "Go Back" }, {
      prompt = "Action for session: " .. session.id,
    }, function(action)
      if action == "Resume" then
        vim.cmd("CLIIntegration open_root Gemini --resume " .. session.id)
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
          prompt = "⚠️  Delete session " .. session.id .. "?",
        }, function(confirm)
          if confirm == "Yes" then
            local success = vim.fn.delete(session.file_path)
            if success == 0 then
              vim.notify("✓ Session deleted: " .. session.id, vim.log.levels.INFO)
            else
              vim.notify("✗ Failed to delete session: " .. session.id, vim.log.levels.ERROR)
            end
            vim.schedule(function()
              manage_gemini_sessions(show_all)
            end)
          else
            vim.notify("Deletion cancelled", vim.log.levels.INFO)
            vim.schedule(function()
              manage_gemini_sessions(show_all)
            end)
          end
        end)
      elseif action == "Go Back" then
        vim.schedule(function()
          manage_gemini_sessions(show_all)
        end)
      end
    end)
  end)
end

return {
  integrations = {
    integrations_overrides = {
      {
        name = "Gemini",
        cli_cmd = "gemini",
        ready_text_flag = "Logged in with Google",
        start_with_text = function(visual_text)
          if visual_text then
            return "Explain this code:\n```\n" .. visual_text .. "\n```\n"
          end
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), "t", false)
          return ""
        end,
        format_paths = function(path)
          return "@" .. path
        end,
      },
    },
    keys_overrides = {
      { "<leader>ag", nil, desc = "Gemini Code Assistant" },
      {
        "<leader>aga",
        ":CLIIntegration open_root Gemini<CR>",
        desc = "Gemini New Session",
        silent = true,
      },
      {
        "<leader>agc",
        ":CLIIntegration open_root Gemini --resume latest<CR>",
        desc = "Gemini Resume Latest",
        silent = true,
      },
      {
        "<leader>ags",
        function()
          manage_gemini_sessions(false)
        end,
        desc = "Gemini Session Manager",
        silent = true,
      },
      {
        "<leader>agd",
        delete_all_gemini_sessions,
        desc = "Gemini Delete Project Sessions",
        silent = true,
      },
      {
        "<leader>ag",
        ":CLIIntegration open_root Gemini --dont-save-session<CR>",
        desc = "Gemini Ask",
        silent = true,
        mode = { "v" },
      },
    },
  },
}
