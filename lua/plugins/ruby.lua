return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      ruby_lsp = {
        mason = false,
        enabled = true,
        cmd = { vim.fn.expand("~/.rbenv/shims/ruby-lsp") },
      },
      rubocop = {
        mason = false,
        enabled = true,
        cmd = { vim.fn.expand("~/.rbenv/shims/rubocop") },
      },
    },
  },
}
