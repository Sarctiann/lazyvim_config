return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      mojo = {
        -- This is required if you use magic-CLI instead of modular-CLI
        on_new_config = function()
          local result = vim.fn.system("magic shell")
          if vim.v.shell_error ~= 0 then
            vim.notify("Error running `magic shell`: " .. result, vim.log.levels.ERROR)
          end
        end,
      },
    },
  },
}
