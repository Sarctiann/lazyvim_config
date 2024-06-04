return {
  "LuaLS/lua-language-server",
  config = function()
    require("lspconfig").lua_ls.setup({
      on_init = function(client)
        local path = client.workspace_folders[1].name
        if vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc") then
          return
        end

        client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
          runtime = {
            version = "Lua 5.4",
          },
          workspace = {
            checkThirdParty = false,
            library = {
              vim.env.VIMRUNTIME,
              path,
              "~/.local/share/nvim/lazy/luvit-meta/library",
            },
          },
          diagnostics = {
            globals = { "vim", "LazyVim" },
          },
        })
      end,
      settings = {
        Lua = {},
      },
    })
  end,
}
