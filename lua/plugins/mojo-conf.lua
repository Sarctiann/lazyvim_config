return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      mojo = {
        on_new_config = function(config)
          if vim.fn.executable("mojo-lsp-server") == 0 then
            -- try to run `magic shell`
            local result = vim.fn.system("magic shell")
            if vim.v.shell_error ~= 0 then
              vim.notify("LSP: " .. result, vim.log.levels.ERROR)
              vim.notify("(Run `magic shell` before entering neovim)", vim.log.levels.INFO)
              -- avoid trying to run mojo-lsp-server
              config.cmd = { "echo", "" }
              return
            end
          end
        end,
      },
    },
  },
}
