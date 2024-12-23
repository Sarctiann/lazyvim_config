local project_root = vim.fn.getcwd()
local lsp_path = project_root .. "/.magic/envs/default/bin/mojo-lsp-server"
local libs_path = project_root .. "/.magic/envs/default/lib/mojo"

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      mojo = {
        cmd = { lsp_path, "-I", libs_path },
      },
    },
  },
}
