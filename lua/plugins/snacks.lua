local win_width = vim.o.columns
local logo_padding = string.rep(" ", math.floor(win_width / 4))

local logo = [[
{padding} ███████╗ █████╗ ██████╗  ██████╗     ███╗   ██╗██╗   ██╗██╗███╗   ███╗
{padding} ██╔════╝██╔══██╗██╔══██╗██╔════╝     ████╗  ██║██║   ██║██║████╗ ████║
{padding} ███████╗███████║██████╔╝██║          ██╔██╗ ██║██║   ██║██║██╔████╔██║
{padding} ╚════██║██╔══██║██╔══██╗██║          ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
{padding} ███████║██║  ██║██║  ██║╚██████╗  ██╗██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
{padding} ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
{padding} {greet}
]]

local function get_day()
  return ", Have a nice " .. os.date("%A") .. "!\n"
end
local sub_header = "\n\nWelcome " .. os.getenv("USER"):lower():gsub("^%l", string.upper) .. get_day()

return {
  "snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        pick = function(cmd, opts)
          return LazyVim.pick(cmd, opts)()
        end,
        header = (logo:gsub("{(%w+)}", { greet = sub_header, padding = logo_padding })),
        -- stylua: ignore
        ---@type snacks.dashboard.Item[]
        keys = {
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "s", desc = "Restore Session", section = "session" },
          { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
          { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          pane = 2,
          icon = string.rep("\n", 8) .. string.rep(" ", 20) .. " ",
          title = string.rep("\n", 8) .. "Projects\n",
          section = "projects",
          indent = 2,
          padding = 1,
        },
        {
          pane = 2,
          icon = string.rep(" ", 20) .. " ",
          title = "Recent Files\n",
          section = "recent_files",
          indent = 2,
          padding = 1,
        },
        {
          pane = 2,
          icon = string.rep(" ", 20) .. " ",
          title = "Git Status\n",
          section = "terminal",
          enabled = function()
            return Snacks.git.get_root() ~= nil
          end,
          cmd = "git status --short --branch --renames",
          height = 7,
          padding = 1,
          indent = 3,
          ttl = 5 * 60,
        },
        { section = "startup" },
      },
    },
  },
}
