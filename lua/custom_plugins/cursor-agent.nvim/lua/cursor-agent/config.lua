--- @class Cursor-Agent.Config
--- @field use_default_mappings boolean|nil # Whether to use default key mappings (default: true)

local M = {}

--- Default configuration
M.defaults = {
  use_default_mappings = true,
}

--- Current configuration
M.options = {}

--- @param config Cursor-Agent.Config
function M.setup(config)
  M.options = vim.tbl_deep_extend("force", M.defaults, config or {})
  return M.options
end

return M
