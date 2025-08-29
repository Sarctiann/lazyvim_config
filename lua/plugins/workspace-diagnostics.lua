return {
  {
    "folke/trouble.nvim",
    opts = { open_no_results = true, warn_no_results = false },
  },
  {
    "artemave/workspace-diagnostics.nvim",
    config = function()
      require("workspace-diagnostics").setup({})
    end,
    keys = {
      {
        "<leader>xw",
        function()
          for _, client in ipairs(vim.lsp.get_clients()) do
            if client.name ~= "copilot" then
              require("workspace-diagnostics").populate_workspace_diagnostics(client, 0)
            end
          end
          require("trouble").open({ mode = "diagnostics", refresh = true })
        end,
        desc = "Workspace Diagnostics",
      },
    },
  },
}
