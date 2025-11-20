--- Buffer management module
local M = {}

--- Get paths of all open buffers visible in bufline
--- @param working_dir string|nil The working directory to make paths relative to
--- @return table List of buffer file paths
function M.get_open_buffers_paths(working_dir)
  local buffers = vim.api.nvim_list_bufs()
  local paths = {}

  local exclude_patterns = {
    "//",
    "neo-tree",
  }

  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      -- Only include buffers that are listed (visible in bufline)
      local is_listed = vim.api.nvim_get_option_value("buflisted", { buf = buf })
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })

      -- Only include listed buffers with empty buftype (normal files)
      if is_listed and buftype == "" then
        local buf_name = vim.api.nvim_buf_get_name(buf)

        local should_exclude = false
        for _, pattern in ipairs(exclude_patterns) do
          if buf_name:match(pattern) then
            should_exclude = true
            break
          end
        end

        if buf_name ~= "" and not should_exclude then
          local file_path = vim.fn.fnamemodify(buf_name, ":p")
          if file_path ~= "" then
            if working_dir and working_dir ~= "" then
              file_path = vim.fs.relpath(working_dir, file_path) or vim.fn.fnamemodify(file_path, ":.")
            end
            table.insert(paths, file_path)
          end
        end
      end
    end
  end

  return paths
end

return M
