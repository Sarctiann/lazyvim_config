-- NOTE: The basic plugin implementation was enabled, to have autocompletions

-- -- NOTE: Create floating window
-- local function augment_floating_input()
--   local current_mode = vim.api.nvim_get_mode().mode
--
--   local width = math.floor(vim.o.columns * 0.5)
--   local height = math.floor(vim.o.lines * 0.3)
--   local win_col = math.floor((vim.o.columns - width) / 2)
--
--   local buf = vim.api.nvim_create_buf(false, true)
--   local win = vim.api.nvim_open_win(buf, true, {
--     row = 2,
--     col = win_col,
--     width = width,
--     height = height,
--     style = "minimal",
--     border = "rounded",
--     relative = "editor",
--     title_pos = "center",
--     title = "   Augment Message ( Submit: <C-s> | Add files: @@ ) ",
--   })
--
--   -- NOTE: Set buffer options (updated API)
--   vim.bo[buf].filetype = "markdown"
--   vim.bo[buf].buftype = "nofile"
--
--   -- NOTE: Enable Tab for Augment suggestions in this buffer only
--   vim.keymap.set("i", "<Tab>", "<cmd>call augment#Accept()<cr>", { buffer = buf, silent = true, noremap = true })
--
--   -- NOTE: Enter insert mode
--   vim.cmd("startinsert")
--
--   local function restore_mode_and_close()
--     vim.api.nvim_win_close(win, true)
--     -- NOTE: Restore original mode
--     if current_mode == "v" or current_mode == "V" or current_mode == "\22" then
--       vim.cmd("normal! gv")
--     elseif current_mode == "i" then
--       vim.cmd("startinsert")
--     else
--       vim.cmd("stopinsert")
--     end
--   end
--
--   local function open_fuzzy_finder()
--     require("fzf-lua").files({
--       file_icons = false,
--       actions = {
--         ["default"] = function(selection)
--           if selection and #selection > 0 then
--             local formatted_files = {}
--             for _, file_path in ipairs(selection) do
--               table.insert(formatted_files, "`@" .. file_path .. "`")
--             end
--             local files_text = " " .. table.concat(formatted_files, ", ") .. " "
--             local row, col = unpack(vim.api.nvim_win_get_cursor(0))
--             vim.api.nvim_buf_set_text(buf, row - 1, col - 1, row - 1, col, { files_text })
--             vim.api.nvim_win_set_cursor(0, { row, col + #files_text })
--             vim.api.nvim_feedkeys("a", "n", false)
--           end
--         end,
--       },
--     })
--   end
--
--   -- NOTE: Add files to the context
--   vim.keymap.set({ "n", "i" }, "@@", open_fuzzy_finder, { buffer = buf })
--
--   local function submit()
--     local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
--     local content = table.concat(lines, " - ")
--     restore_mode_and_close()
--
--     if content and content ~= "" then
--       vim.cmd("Augment chat " .. vim.fn.shellescape(content))
--     end
--   end
--
--   -- NOTE: Submit
--   vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf })
--   vim.keymap.set({ "n", "i" }, "<C-CR>", submit, { buffer = buf })
--   vim.keymap.set("n", "<CR>", submit, { buffer = buf })
--
--   -- NOTE: Close
--   vim.keymap.set("n", "<Esc>", restore_mode_and_close, { buffer = buf })
--   vim.keymap.set({ "n", "i" }, "<C-c>", restore_mode_and_close, { buffer = buf })
-- end
--
-- -- NOTE: Quick input
-- local function augment_input(is_visual)
--   vim.ui.input({
--     prompt = "Augment Message: ",
--     default = is_visual and "What is this code doing? " or "",
--     completion = "file",
--   }, function(input)
--     if input and input ~= "" then
--       -- NOTE: Add @ prefix to files
--       local processed_input = input:gsub("([%.%w%.%/%-%_~]*%.?[%w%.%/%-%_~]*%.[%w-_]+)", "`@%1`")
--       vim.cmd((is_visual and "'<,'>" or "") .. "Augment chat " .. vim.fn.shellescape(processed_input))
--     end
--   end)
-- end
--
-- local function augment_input_visual()
--   augment_input(true)
-- end

return {
  "augmentcode/augment.vim",
  lazy = false,
  -- NOTE: Highier than Blink
  priority = 1000,
  init = function()
    -- NOTE: This runs before the plugin loads
    local workspace_folders = {}
    table.insert(workspace_folders, vim.fn.getcwd())

    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if vim.v.shell_error == 0 and git_root ~= vim.fn.getcwd() then
      table.insert(workspace_folders, git_root)
    end

    vim.g.augment_workspace_folders = workspace_folders
    -- NOTE: If you have keymapping conflicts you can disable tab mapping
    --
    -- vim.g.augment_disable_tab_mapping = true
  end,
  keys = {
    -- { "<leader>am", augment_floating_input, desc = "AugmentCode Message Input", silent = true, noremap = true },
    -- { "<leader>aM", augment_input, desc = "AugmentCode Quick Input", silent = true, noremap = true },
    -- { "<leader>a", augment_input_visual, desc = "AugmentCode Ask Input", silent = false, noremap = true, mode = "v" },
    -- { "<leader>an", ":Augment chat-new<CR>", desc = "AugmentCode New", silent = true, noremap = true },
    -- { "<leader>at", ":Augment chat-toggle<CR>", desc = "AugmentCode Toggle", silent = true, noremap = true },
    --
    -- -- NOTE: Control commands
    -- { "<leader>as", nil, desc = "AugmentCode Control Commands", silent = true, noremap = true },
    -- { "<leader>ase", ":Augment enable<CR>", desc = "AugmentCode Enable Suggestions", silent = true, noremap = true },
    -- { "<leader>asd", ":Augment disable<CR>", desc = "AugmentCode Disable Suggestions", silent = true, noremap = true },
    -- { "<leader>ass", ":Augment status<CR>", desc = "AugmentCode Status", silent = true, noremap = true },
    -- { "<leader>asl", ":Augment log<CR>", desc = "AugmentCode Log", silent = true, noremap = true },
    -- -- WARN: This command will open a "clickable link" in a nvim input.
    -- -- You might need to use vscode terminal or any other terminal that supports links navigation.
    -- -- Some terminals algo supports this functionality by pressing Alt+Shift / Cmd+Shift and click.
    -- { "<leader>asi", ":Augment signin<CR>", desc = "AugmentCode Sign In", silent = true, noremap = true },
    -- { "<leader>aso", ":Augment signout<CR>", desc = "AugmentCode Sign Out", silent = true, noremap = true },

    -- NOTE: Accept Suggestions
    { "<C-y>", "<cmd>call augment#Accept()<cr>", mode = "i", silent = true, noremap = true },
    { "<C-l>", "<cmd>call augment#Accept()<cr>", mode = "i", silent = true, noremap = true },
  },
}
