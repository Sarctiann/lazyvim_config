local M = {}

-- NOTE: Function to delete Claude sessions
function M.delete_all_claude_sessions()
  local base_dir = vim.fn.expand("~/.claude/projects")
  local current_path = require("cli-integration.hooks").get_current_workspace()
  local project_dir_name = current_path:gsub("/", "-")
  local project_dir = base_dir .. "/" .. project_dir_name

  local options = { "Current Project Only", "ALL Projects", "Cancel" }
  vim.ui.select(options, { prompt = "⚠️ Delete Claude sessions?" }, function(choice)
    if not choice or choice == "Cancel" then
      return
    end
    local session_files = (choice == "Current Project Only") and vim.fn.glob(project_dir .. "/*.jsonl", false, true)
      or vim.fn.glob(base_dir .. "/*/*.jsonl", false, true)

    if #session_files == 0 then
      vim.notify("No Claude sessions found", vim.log.levels.INFO)
      return
    end

    vim.ui.select({ "Yes, Delete " .. #session_files .. " sessions", "No, Cancel" }, {
      prompt = "Confirm: Delete ALL " .. #session_files .. " sessions?",
    }, function(confirm)
      if confirm and confirm:match("^Yes") then
        for _, file in ipairs(session_files) do
          vim.fn.delete(file)
        end
        vim.notify("✓ Sessions deleted", vim.log.levels.INFO)
      end
    end)
  end)
end

-- NOTE: Claude session manager (Uses plugin hooks with Lazy Load)
function M.manage_claude_sessions(show_all)
  local base_dir = vim.fn.expand("~/.claude/projects")
  require("cli-integration.hooks").manage_sessions({
    name = "Claude",
    resume_cmd = "CLIIntegration open_root Claude --resume %s",
    show_all = show_all,
    get_sessions = function()
      local sessions = {}
      local project_dirs = vim.fn.glob(base_dir .. "/*", false, true)
      for _, dir in ipairs(project_dirs) do
        if vim.fn.isdirectory(dir) == 1 then
          local project_name = vim.fn.fnamemodify(dir, ":t")
          local workspace_path = project_name:gsub("-", "/")

          local files = vim.fn.glob(dir .. "/*.jsonl", false, true)
          for _, file_path in ipairs(files) do
            local f = io.open(file_path, "r")
            if f then
              local last_updated = "0000-00-00"
              local first_message = "No messages"
              local session_id = vim.fn.fnamemodify(file_path, ":t:r")

              for line in f:lines() do
                local ok, data = pcall(vim.json.decode, line)
                if ok and data then
                  if data.timestamp then
                    last_updated = data.timestamp
                  end
                  if data.type == "custom-title" and data.customTitle then
                    first_message = '" ' .. string.upper(data.customTitle) .. ' "'
                  end
                  if
                    (first_message == "No messages" or first_message == "<Message Content Too Complex>")
                    and data.type == "user"
                    and data.message
                  then
                    local text = data.message.content
                    if type(text) == "table" then
                      text = "<Message Content Too Complex>"
                    end
                    if type(text) == "string" and text ~= "" then
                      first_message = text:gsub("\n", " "):sub(1, 40)
                      if #text > 40 then
                        first_message = first_message .. "..."
                      end
                    end
                  end
                end
              end
              f:close()

              local date = last_updated:match("(%d%d%d%d%-%d%d%-%d%d)") or "Unknown"
              local time = last_updated:match("T(%d%d:%d%d)") or ""
              local display_project = project_name:gsub("^%-", ""):gsub("-", "/")
              if #display_project > 30 then
                display_project = "..." .. display_project:sub(-27)
              end

              table.insert(sessions, {
                id = session_id,
                modified = last_updated,
                workspace = workspace_path,
                file_path = file_path,
                display = string.format("[%s %s] (%s) %s", date, time, display_project, first_message),
              })
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
