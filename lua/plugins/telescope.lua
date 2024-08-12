-- Complete configuration for telescope here: https://www.lazyvim.org/plugins/editor#telescopenvim-optional

-- local TELESCOPE_IGNORE = {
--   ".venv/*",
--   "venv/*",
--   "__pycache__/*",
--   "node_modules/*",
--   "*.git/*",
--   "*.idea/*",
--   "*.vscode/*",
--   "*build/*",
--   "*dist/*",
--   "*.next/*",
--   "yarn.lock",
--   "package-lock.json",
-- }
--
-- local function map(tbl, func)
--   local newt = {}
--   for i, v in ipairs(tbl) do
--     newt[i] = func(v)
--   end
--   return newt
-- end
--
-- local telescope_ignore = map(TELESCOPE_IGNORE, function(entry)
--   return "--glob=!" .. entry
-- end)

return {
  -- "nvim-telescope/telescope.nvim",
  -- opts = function()
  --   local actions = require("telescope.actions")
  --
  --   local open_with_trouble = function(...)
  --     return require("trouble.providers.telescope").open_with_trouble(...)
  --   end
  --   local open_selected_with_trouble = function(...)
  --     return require("trouble.providers.telescope").open_selected_with_trouble(...)
  --   end
  --   local live_grep_all = function()
  --     local action_state = require("telescope.actions.state")
  --     local line = action_state.get_current_line()
  --     LazyVim.pick("live_grep", {
  --       hidden = true,
  --       no_ignore = true,
  --       default_text = line,
  --     })()
  --   end
  --   local find_files_all = function()
  --     local action_state = require("telescope.actions.state")
  --     local line = action_state.get_current_line()
  --     LazyVim.pick("find_files", {
  --       hidden = true,
  --       no_ignore = true,
  --       default_text = line,
  --     })()
  --   end
  --
  --   return {
  --     defaults = {
  --       prompt_prefix = " ",
  --       selection_caret = " ",
  --       -- open files in the first window that is an actual file.
  --       -- use the current window if no other window is available.
  --       get_selection_window = function()
  --         local wins = vim.api.nvim_list_wins()
  --         table.insert(wins, 1, vim.api.nvim_get_current_win())
  --         for _, win in ipairs(wins) do
  --           local buf = vim.api.nvim_win_get_buf(win)
  --           if vim.bo[buf].buftype == "" then
  --             return win
  --           end
  --         end
  --         return 0
  --       end,
  --       mappings = {
  --         i = {
  --           ["<c-t>"] = open_with_trouble,
  --           ["<M-t>"] = open_selected_with_trouble,
  --           ["<M-i>"] = live_grep_all,
  --           ["<M-h>"] = find_files_all,
  --           ["<C-Down>"] = actions.cycle_history_next,
  --           ["<C-Up>"] = actions.cycle_history_prev,
  --           ["<C-f>"] = actions.preview_scrolling_down,
  --           ["<C-b>"] = actions.preview_scrolling_up,
  --         },
  --         n = {
  --           ["q"] = actions.close,
  --         },
  --       },
  --       -- configure to use ripgrep
  --       vimgrep_arguments = {
  --         "rg",
  --         "-u",
  --         "--follow", -- Follow symbolic links
  --         "--hidden", -- Search for hidden files
  --         "--no-heading", -- Don't group matches by each file
  --         "--with-filename", -- Print the file path with the matched lines
  --         "--line-number", -- Show line numbers
  --         "--column", -- Show column numbers
  --         "--smart-case", -- Smart case search
  --
  --         -- Exclude some patterns from search
  --         unpack(telescope_ignore),
  --       },
  --     },
  --     pickers = {
  --       find_files = {
  --         -- needed to exclude some files & dirs from general search
  --         -- when not included or specified in .gitignore
  --         find_command = {
  --           "rg",
  --           "-u",
  --           "--files",
  --           "--hidden",
  --           -- Exclude some patterns from search
  --           unpack(telescope_ignore),
  --         },
  --       },
  --     },
  --   }
  -- end,
}
