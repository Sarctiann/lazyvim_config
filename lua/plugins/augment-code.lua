local function augment_input()
  vim.ui.input({
    prompt = "Augment Message: ",
    completion = "file",
  }, function(input)
    if input and input ~= "" then
      -- Add @ prefix to file paths
      local processed_input = input:gsub("([%w%.%/%-%_~]+%.%w+)", "`@%1`")
      vim.cmd("Augment chat " .. vim.fn.shellescape(processed_input))
    end
  end)
end

return {
  "augmentcode/augment.vim",

  init = function()
    -- This runs before the plugin loads
    local workspace_folders = {}
    table.insert(workspace_folders, vim.fn.getcwd())

    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
    if vim.v.shell_error == 0 and git_root ~= vim.fn.getcwd() then
      table.insert(workspace_folders, git_root)
    end

    vim.g.augment_workspace_folders = workspace_folders
  end,

  keys = {
    { "<leader>am", augment_input, desc = "AugmentCode Message Input", silent = true, noremap = true },
    { "<leader>a", augment_input, desc = "AugmentCode Ask Input", silent = false, noremap = true, mode = "v" },
    { "<leader>an", ":Augment chat-new<CR>", desc = "AugmentCode New", silent = true, noremap = true },
    { "<leader>at", ":Augment chat-toggle<CR>", desc = "AugmentCode Toggle", silent = true, noremap = true },

    -- NOTE: Control commands
    { "<leader>as", nil, desc = "AugmentCode Control Commands", silent = true, noremap = true },
    { "<leader>ase", ":Augment enable<CR>", desc = "AugmentCode Enable Suggestions", silent = true, noremap = true },
    { "<leader>asd", ":Augment disable<CR>", desc = "AugmentCode Disable Suggestions", silent = true, noremap = true },
    { "<leader>ass", ":Augment status<CR>", desc = "AugmentCode Status", silent = true, noremap = true },
    { "<leader>asl", ":Augment log<CR>", desc = "AugmentCode Log", silent = true, noremap = true },
    -- WARN: This command will open a "clickable link" in a nvim input.
    -- You might need to use vscode terminal or any other terminal that supports links navigation.
    { "<leader>asi", ":Augment signin<CR>", desc = "AugmentCode Sign In", silent = true, noremap = true },
    { "<leader>aso", ":Augment signout<CR>", desc = "AugmentCode Sign Out", silent = true, noremap = true },
  },
}
