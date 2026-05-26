# Neovim Integration Rules

This file only adds rules for OpenCode sessions launched from Neovim. Global user rules live in the parent `AGENTS.md`.

## Source-First Workflow

- `~/.config/opencode/opencode-neovim/` is the source of truth for this integration.
- Make all changes in this directory first.
- Do not modify files under `~/.config/nvim/` unless the user explicitly asks.
- After the commit is created, sync the source to the Neovim mirror:

```bash
rsync -av --exclude='node_modules' --exclude='.git' \
  ~/.config/opencode/opencode-neovim/ \
  ~/.config/nvim/lua/utils/opencode-neovim/
```

## MCP Availability Check (RUN FIRST)

Before applying ANY Neovim integration rules or invoking ANY Neovim skills:

1. Try `neovim_vim_status`.
2. **If it succeeds and returns valid data** → Neovim MCP is active. Continue with rules below.
3. **If it fails, times out, or the tool is not available** → Neovim MCP is NOT active:
   - Do **NOT** invoke any Neovim skills (`using-neovim`, `using-neovim-lsp`, `using-quickfix`).
   - Do **NOT** attempt any `neovim_vim_*` tool calls.
   - Fall back to standard tools only: use native `edit`/`write` for file modifications, `glob`/`grep`/`read` for file search and reading.
   - Skip the rest of this file entirely.

## When MCP is Active

Invoke the `using-neovim` skill to configure editor-integrated behavior.

## Editor Interaction

When `neovim_vim_*` tools are available (Neovim MCP active), follow these rules:

- Before any MCP tool call that depends on buffer context (`neovim_vim_status`, `neovim_vim_buffer`, LSP commands, `neovim_vim_search`, `neovim_vim_search_replace`, `neovim_vim_grep`), run the Window Focus Step to switch focus away from the OpenCode terminal window to a file buffer:
  ```vim
  :lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == "" and bn ~= "" then vim.api.nvim_set_current_win(w) break end end
  ```
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
