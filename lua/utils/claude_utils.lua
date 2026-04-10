local M = {}

-- WARN:
-- configure your nvim-mcp-server to work with claude by running
-- this command in your terminal (only needs to be done once):
--     claude mcp add nvim -s user -e NVIM=\$NVIM -- "npx" -y nvim-mcp-server
-- It should result in the following entry in your ~/.claude/settings.json file:
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

-- NOTE: Function to delete Claude sessions
function M.delete_all_claude_sessions()
  local base_dir = vim.fn.expand("~/.claude/projects")
  local current_path = require("cli-integration.hooks").get_current_workspace()
  local project_dir_name = current_path:gsub("[/._]", "-")
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

-- NOTE: Convert a UTC ISO-8601 timestamp to local date and time strings.
-- os.time() treats a time table as *local* time, so feeding UTC values yields
-- an epoch shifted by the UTC offset. Adding the offset back gives the true UTC
-- epoch; os.date() then renders it in the system's local timezone.
local function parse_timestamp_local(utc_timestamp)
  local year, month, day, hour, min =
    utc_timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+)")
  if not year then
    return "Unknown", ""
  end

  -- Compute current UTC offset in seconds (e.g. -10800 for UTC-3)
  local now = os.time()
  local utc_offset = (tonumber(os.date("%H", now)) - tonumber(os.date("!%H", now))) * 3600
    + (tonumber(os.date("%M", now)) - tonumber(os.date("!%M", now))) * 60
  if utc_offset > 43200 then
    utc_offset = utc_offset - 86400
  elseif utc_offset < -43200 then
    utc_offset = utc_offset + 86400
  end

  local pseudo_epoch = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = 0,
    isdst = false,
  })
  local true_utc_epoch = pseudo_epoch + utc_offset
  return os.date("%Y-%m-%d", true_utc_epoch), os.date("%H:%M", true_utc_epoch)
end

-- NOTE: Claude session manager (Uses plugin hooks with Lazy Load)
function M.manage_claude_sessions(show_all)
  local base_dir = vim.fn.expand("~/.claude/projects")
  local hooks = require("cli-integration.hooks")
  hooks.manage_sessions({
    name = "Claude",
    resume_cmd = "CLIIntegration open_root Claude --resume %s",
    show_all = show_all,
    get_sessions = function()
      local sessions = {}
      local current_ws = hooks.get_current_workspace()
      local current_ws_dir = current_ws:gsub("[/._]", "-")
      local project_dirs = vim.fn.glob(base_dir .. "/*", false, true)
      for _, dir in ipairs(project_dirs) do
        if vim.fn.isdirectory(dir) == 1 then
          local project_name = vim.fn.fnamemodify(dir, ":t")
          -- Claude encodes paths as dir names by replacing "/" with "-", which is ambiguous
          -- (can't distinguish path separators from actual dashes in dir names).
          -- Use the real workspace path only when we can confirm the match; otherwise keep raw dir name.
          local workspace_path = (project_name == current_ws_dir) and current_ws or project_name

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

              local date, time = parse_timestamp_local(last_updated)
              local display_project = project_name:gsub("^%-", "")
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
