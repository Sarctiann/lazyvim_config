local M = {}

-- NOTE: Function to delete Gemini sessions (current project or all)
function M.delete_all_gemini_sessions()
  local base_dir = vim.fn.expand("~/.gemini/tmp")
  local projects_file = vim.fn.expand("~/.gemini/projects.json")

  -- 1. Identify current project
  -- Lazy load hooks to get workspace
  local current_path = require("cli-integration.hooks").get_current_workspace()
  local project_name = nil

  local pf = io.open(projects_file, "r")
  if pf then
    local content = pf:read("*all")
    pf:close()
    local ok, projects_data = pcall(vim.json.decode, content)
    if ok and projects_data and projects_data.projects then
      project_name = projects_data.projects[current_path]
    end
  end

  -- 2. Ask for scope
  local options = { "Current Project Only", "ALL Projects", "Cancel" }
  local prompt_text = "⚠️  Delete Gemini sessions?"
  if project_name then
    prompt_text = "⚠️  Delete Gemini sessions for [" .. project_name .. "] or ALL projects?"
  end

  vim.ui.select(options, {
    prompt = prompt_text,
  }, function(choice)
    if not choice or choice == "Cancel" then
      return
    end

    local session_files = {}
    local scope_desc = ""

    if choice == "Current Project Only" then
      if not project_name then
        vim.notify("Could not identify project for: " .. current_path, vim.log.levels.ERROR)
        return
      end
      local chats_dir = base_dir .. "/" .. project_name .. "/chats"
      session_files = vim.fn.glob(chats_dir .. "/*.json", false, true)
      scope_desc = "project " .. project_name
    else
      session_files = vim.fn.glob(base_dir .. "/*/chats/*.json", false, true)
      scope_desc = "ALL projects"
    end

    if #session_files == 0 then
      vim.notify("No Gemini sessions found for " .. scope_desc, vim.log.levels.INFO)
      return
    end

    -- 3. Final confirmation
    vim.ui.select({ "Yes, Delete " .. #session_files .. " sessions", "No, Cancel" }, {
      prompt = "Confirm: Delete ALL " .. #session_files .. " sessions for " .. scope_desc .. "?",
    }, function(confirm)
      if confirm and confirm:match("^Yes") then
        local deleted_count = 0
        for _, file in ipairs(session_files) do
          if vim.fn.delete(file) == 0 then
            deleted_count = deleted_count + 1
          end
        end
        vim.notify("✓ " .. deleted_count .. " session(s) for " .. scope_desc .. " deleted", vim.log.levels.INFO)
      else
        vim.notify("Deletion cancelled", vim.log.levels.INFO)
      end
    end)
  end)
end

-- NOTE: Optimized Gemini session manager (Uses plugin hooks with Lazy Load)
function M.manage_gemini_sessions(show_all)
  local base_dir = vim.fn.expand("~/.gemini/tmp")
  local projects_file = vim.fn.expand("~/.gemini/projects.json")

  require("cli-integration.hooks").manage_sessions({
    name = "Gemini",
    resume_cmd = "CLIIntegration open_root Gemini --resume %s",
    show_all = show_all,
    get_sessions = function()
      -- Load project mapping to resolve workspace -> project_name
      local projects_data = {}
      local pf = io.open(projects_file, "r")
      if pf then
        local content = pf:read("*all")
        pf:close()
        local ok, data = pcall(vim.json.decode, content)
        if ok and data then
          projects_data = data.projects or {}
        end
      end

      local sessions = {}
      -- Scan all project directories
      local tmp_dirs = vim.fn.glob(base_dir .. "/*", false, true)
      for _, dir in ipairs(tmp_dirs) do
        if vim.fn.isdirectory(dir) == 1 then
          local project_name = vim.fn.fnamemodify(dir, ":t")
          if project_name ~= "bin" then
            -- Find workspace path for this project
            local workspace_path = nil
            for path, name in pairs(projects_data) do
              if name == project_name then
                workspace_path = path
                break
              end
            end

            local chats_dir = dir .. "/chats"
            local files = vim.fn.glob(chats_dir .. "/*.json", false, true)
            for _, file_path in ipairs(files) do
              local f = io.open(file_path, "r")
              if f then
                local content = f:read("*all")
                f:close()
                local ok, data = pcall(vim.json.decode, content)
                if ok and data then
                  local last_updated = data.lastUpdated or data.startTime or "0000-00-00"
                  local session_id = data.sessionId or vim.fn.fnamemodify(file_path, ":t:r")

                  local first_message = "No messages"
                  if data.messages then
                    for _, msg in ipairs(data.messages) do
                      if msg.type == "user" and msg.content then
                        local text = ""
                        if type(msg.content) == "string" then
                          text = msg.content
                        elseif type(msg.content) == "table" and msg.content[1] then
                          text = msg.content[1].text or ""
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
                    modified = last_updated,
                    workspace = workspace_path,
                    file_path = file_path,
                    display = string.format("[%s %s] (%s) %s", date, time, project_name, first_message),
                  })
                end
              end
            end
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
