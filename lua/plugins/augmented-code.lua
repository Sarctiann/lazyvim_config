local function setup_augment_workspace()
  -- Auto-detect workspace folders
  local workspace_folders = {}

  -- Add current working directory
  table.insert(workspace_folders, vim.fn.getcwd())

  -- Add git root if available
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error == 0 and git_root ~= vim.fn.getcwd() then
    table.insert(workspace_folders, git_root)
  end

  -- Set the workspace folders
  vim.g.augment_workspace_folders = workspace_folders
end

local function augment_with_workspace(command)
  setup_augment_workspace()
  vim.cmd("Augment " .. command)
end

return {
  "augmentcode/augment.vim",
  keys = {
    {
      "<leader>am",
      function()
        augment_with_workspace("chat")
      end,
      desc = "AugmentCode Input Message",
      silent = false,
      noremap = true,
    },
    {
      "<leader>an",
      function()
        augment_with_workspace("chat-new")
      end,
      desc = "AugmentCode New",
      silent = true,
      noremap = true,
    },
    {
      "<leader>at",
      function()
        augment_with_workspace("chat-toggle")
      end,
      desc = "AugmentCode Toggle",
      silent = true,
      noremap = true,
    },

    -- NOTE: Control commands
    { "<leader>as", nil, desc = "AugmentCode Control Commands", silent = true, noremap = true },
    { "<leader>ase", ":Augment enable<CR>", desc = "AugmentCode Enable", silent = true, noremap = true },
    { "<leader>asd", ":Augment disable<CR>", desc = "AugmentCode Disable", silent = true, noremap = true },
    { "<leader>ass", ":Augment status<CR>", desc = "AugmentCode Status", silent = true, noremap = true },
    { "<leader>asl", ":Augment log<CR>", desc = "AugmentCode Log", silent = true, noremap = true },
    -- WARN: This command will open a "clickable link" in a nvim input.
    -- You might need to use vscode terminal or any other terminal that supports links navigation.
    { "<leader>asi", ":Augment signin<CR>", desc = "AugmentCode Sign In", silent = true, noremap = true },
    { "<leader>aso", ":Augment signout<CR>", desc = "AugmentCode Sign Out", silent = true, noremap = true },
  },
}

-- Config sample: let g:augment_workspace_folders = ['/path/to/project', '~/another-project']
