return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      mojo = {
        -- this is required if you use magic-cli instead of modular-cli
        on_new_config = function()
          local result = vim.fn.system("magic shell")
          if vim.v.shell_error ~= 0 then
            vim.notify("error running `magic shell`: " .. result, vim.log.levels.error)
          end
        end,
      },
    },
  },
}
