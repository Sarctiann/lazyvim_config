# Neovim Integration Rules

At session start, invoke the `using-neovim` skill to configure editor-integrated behavior.

## Editor Interaction

When `neovim_vim_*` tools are available (Neovim MCP active), follow these rules:

- Use native `edit`/`write` tools to modify files on disk.
- After any edit: run the formatter, then reload the buffer with `neovim_vim_command(":e")` or `:checktime`.
- Open the edited file in Neovim with `neovim_vim_file_open` so the user sees the result.
- When the user refers to "this line", "this file", or "here", call `neovim_vim_status` first to get the active buffer and cursor position.
- For any multi-file search, use `neovim_vim_grep` and then `neovim_vim_command(":copen")` to populate and show the quickfix list before making changes.
- When opening multiple related files, prefer `neovim_vim_window split` or `vsplit` to show them side by side.
- Always check LSP clients from `neovim_vim_status` (look at `lspInfo` field) before reasoning about symbols, diagnostics, or references.

## Deprecated Tools

Do NOT use these MCP tools for editing — they are unreliable:
- `neovim_vim_edit` — use native `edit`/`write` + `:e` to reload instead
- `neovim_vim_buffer_save` — use native `write` instead
- `neovim_vim_mark` / `neovim_vim_visual` — broken (MCP server bug), use `neovim_vim_command` equivalents
