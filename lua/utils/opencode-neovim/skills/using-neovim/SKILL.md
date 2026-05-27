---
name: using-neovim
description: Use when the neovim MCP is available, or when the user mentions neovim, opening/closing/reading files in an editor, buffer navigation, text editing via editor, or any interaction with a text editor integrated session.
---

# Using Neovim MCP

## Purpose

Neovim MCP exists for **visualization and context sharing**, not for executing file operations.

- **Native tools** (`edit`, `write`, `grep`, `read`, `glob`) handle ALL file operations.
- **MCP tools** are used ONLY to show results in Neovim and read user context.
- Do NOT use MCP to edit, search, or navigate files — native tools are faster and more reliable.

## Tools Reference

| Tool | MCP Name | Purpose |
|------|----------|---------|
| File operations | — | Use native `edit`/`write`/`grep`/`read`/`glob` |
| `vim_status` | `neovim_vim_status` | Current buffer, cursor, LSP clients |
| `vim_buffer` | `neovim_vim_buffer` | Read buffer the user has open (for context) |
| `vim_file_open` | `neovim_vim_file_open` | Open a file in Neovim (show results) |
| `vim_command` | `neovim_vim_command` | Run Vim commands (`:e`, `:copen`, `:checktime`, `:lua ...`) |
| `vim_grep` | `neovim_vim_grep` | Populate quickfix for user navigation |
| `vim_window` | `neovim_vim_window` | Split/vsplit management for showing files |
| `vim_health` | `neovim_vim_health` | Connection health check |

## Deprecated Tools

Do NOT use these MCP tools — native alternatives are superior:

- `neovim_vim_edit` — use native `edit`/`write`
- `neovim_vim_buffer_save` — use native `write`
- `neovim_vim_search` / `neovim_vim_search_replace` — use native `grep`/`edit`
- `neovim_vim_mark` / `neovim_vim_visual` — broken (MCP server bug)

## Workflows

### Edit a file

1. Use native `edit`/`write` to modify the file on disk.
2. Run the formatter (if configured).
3. Open in Neovim so the user sees the result:
   - `neovim_vim_file_open(<path>)` or
   - `neovim_vim_command(":e <path>")`

### "What is the user looking at?"

When the user says "this line", "this file", or "here" without specifying a path:

1. `neovim_vim_status` → returns active buffer filename, cursor position, LSP clients.
2. `neovim_vim_buffer(<filename>)` → read the buffer content if you need more context.
3. Respond. No window focus switching needed.

### Project-wide search (show results in quickfix)

1. Use native `grep` to find matches.
2. Optionally populate quickfix so the user can navigate results:
   - `neovim_vim_grep(<pattern>)`
   - `neovim_vim_command(":copen")`
3. Apply edits with native tools.

### Reload buffers after native edits

- Current buffer only: `neovim_vim_command(":e")`
- All changed buffers: `neovim_vim_command(":checktime")`

### Open related files side by side

1. `neovim_vim_file_open(<path>)` for each file.
2. `neovim_vim_window("split")` or `neovim_vim_window("vsplit")` to arrange.

## LSP Integration

`neovim_vim_status` returns attached LSP clients via the `lspInfo` field. Use this to check which language server is active. For detailed LSP operations, see the `using-neovim-lsp` skill.

## Quickfix List

Populate quickfix when you want the user to navigate multi-file results:

```
neovim_vim_grep(<pattern>)
neovim_vim_command(":copen")
```

See the `using-quickfix` skill for details.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `neovim_vim_edit` instead of native tools | Use native `edit`/`write` |
| Using `neovim_vim_search` for buffer search | Use native `grep`/`read` |
| Using `neovim_vim_search_replace` | Use native `edit` |
| Not opening the file after editing | Call `neovim_vim_file_open` so the user sees the result |
| Using MCP for code navigation | Use native `read`/`grep`/`glob` |
| Switching window focus before MCP calls | No need — MCP is for showing results, not doing work |
