# Neovim Integration Rules

At session start, invoke the `using-neovim` skill to configure editor-integrated behavior.

## Editor Interaction

When `vim_*` tools are available (Neovim MCP active), follow these rules:

- Prefer `vim_buffer` / `vim_edit` / `vim_buffer_save` over native `read` / `write` / `edit` tools.
- After any edit, call `vim_buffer_save` and leave the edited buffer focused in Neovim.
- When the user refers to "this line", "this file", or "here", call `vim_status` first to get the active buffer and cursor position.
- For any multi-file search, use `vim_grep` and then `vim_command :copen` to populate and show the quickfix list before making changes.
- When opening multiple related files, prefer `vim_window split` or `vsplit` to show them side by side.
- Always check LSP clients from `vim_status` before reasoning about symbols, diagnostics, or references.
