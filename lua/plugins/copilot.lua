return {
  {
    "zbirenbaum/copilot.lua",
    -- Add TermOpen so the plugin loads when a terminal buffer opens
    event = { "BufReadPost", "TermOpen" },
    opts = {
      filetypes = {
        markdown = true,
        help = true,
        -- Allow empty filetype (terminal buffers have filetype = "")
        [""] = true,
      },
      should_attach = function(bufnr, _)
        local buftype = vim.bo[bufnr].buftype
        return buftype == "" or buftype == "terminal"
      end,
    },
    init = function()
      -- Force-attach copilot after TermOpen (buftype is set after BufEnter)
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(ev)
          local client = require("copilot.client")
          -- ensure_client_started handles not-yet-initialized and auth-pending states
          client.ensure_client_started()
          client.buf_attach(true, ev.buf)
        end,
      })
    end,
  },
}
