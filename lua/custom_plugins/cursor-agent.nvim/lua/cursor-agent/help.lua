--- Help system module
local M = {}

--- Show help notification with keymaps and commands
function M.show_help()
  Snacks.notify(
    [[Term Mode:
    · <C-s> | <CR>       : Submit
    · <M-q> | <Esc><Esc> : Normal Mode
    · <C-p>              : Add Buffer File Path
    · <C-p><C-p>         : Add All Open Buffer File Paths
    ---
    · <CR><CR>           : New Line
    · <M-?> | ?? | \\    : Show Help
    ---
    · <C-c>              : Clear/Stop/Close
    · <C-d>              : Close
    · <C-r>              : Review Changes

Norm Mode:
    · q | <Esc>          : Hide
    · <...>              (all other normal mode keys)

Cursor-Agent commands:
    · quit | exit        : (<CR>) Close Cursor-Agent
    ---
    · /                  : Show command list
    · @                  : Show file list to attach
    · !                  : To run in the shell
    ]],
    { title = "Keymaps", style = "compact", history = false, timeout = 5000 }
  )
end

--- Show quick help notification on terminal open
function M.show_quick_help()
  Snacks.notify(
    " Press: [<M-?>] | [??] | [\\\\] to Show Help ",
    { title = "", style = "compact", history = false, timeout = 3000 }
  )
end

return M
