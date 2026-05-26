---
name: using-neovim
description: Use when the neovim MCP is available, or when the user mentions neovim, opening/closing/reading files in an editor, buffer navigation, text editing via editor, or any interaction with a text editor integrated session.
---

# Using Neovim MCP

## Overview

When the `neovim` MCP server is available, Neovim IS the primary user interface. Treat it as the canonical view of the user's workspace: always reflect changes there, open relevant files for context, and leverage Vim-native features (quickfix, LSP, marks, etc.) for a seamless editing experience.

## Detecting Neovim MCP Availability

At session start, call `neovim_vim_health` or `neovim_vim_status`. If it succeeds, the Neovim MCP is active — follow this skill for all file and editor interactions.

If it fails or the tool is absent, fall back to standard file tools.

## Core Principle

> **Every meaningful action should be visible in Neovim.**

After any edit, open, or navigation: leave the buffer focused so the user sees the result immediately.

---

## Tools Quick Reference

| Tool                 | MCP Name                    | Purpose                                                  |
| -------------------- | --------------------------- | -------------------------------------------------------- |
| `vim_status`         | `neovim_vim_status`         | Current buffer, cursor, mode, LSP clients, window layout |
| `vim_buffer`         | `neovim_vim_buffer`         | Read buffer contents (optionally by filename)            |
| `vim_buffer_switch`  | `neovim_vim_buffer_switch`  | Switch to buffer by name or number                       |
| `vim_file_open`      | `neovim_vim_file_open`      | Open a file into a new buffer                            |
| `vim_command`        | `neovim_vim_command`        | Run any Vim command (`:norm`, `:e`, `:bd`, `!shell`)     |
| `vim_search`         | `neovim_vim_search`         | Regex search within current buffer                       |
| `vim_search_replace` | `neovim_vim_search_replace` | Find-and-replace in current buffer                       |
| `vim_grep`           | `neovim_vim_grep`           | Project-wide vimgrep → populates quickfix list           |
| `vim_window`         | `neovim_vim_window`         | Split, vsplit, close, navigate windows                   |
| `vim_register`       | `neovim_vim_register`       | Set register content                                     |
| `vim_macro`          | `neovim_vim_macro`          | Record / stop / play macros                              |
| `vim_tab`            | `neovim_vim_tab`            | Tab management (new, close, next, prev…)                 |
| `vim_fold`           | `neovim_vim_fold`           | Code folding (create/open/close/delete/toggle)           |
| `vim_jump`           | `neovim_vim_jump`           | Jump list navigation (back/forward/list)                 |
| `vim_health`         | `neovim_vim_health`         | Connection health check                                  |

**Deprecated tools** (avoid using):

- `vim_edit` — unreliable with line-number based editing; use native `edit`/`write` tools instead
- `vim_buffer_save` — use native `write` tool instead
- `vim_mark` and `vim_visual` — BROKEN (MCP server bug with type coercion). Use `vim_command` equivalents instead (see below).

---

## ⚠️ Known Issues

### `vim_edit` — Unreliable, Use Native Tools Instead

`neovim_vim_edit` uses line-number based editing which fails when:

- Buffer content changed between read and edit
- Buffer is `nomodifiable` (e.g., OpenCode's UI buffer)
- Buffer is not the active buffer (replaceAll silently fails)

**Fix:** Use native `edit`/`write` tools to modify files, then reload the buffer in Neovim. See "Edit & Reload" below.

### `vim_mark` and `vim_visual` — BROKEN

The MCP server has type coercion bugs: it sends `column` as string where Vim expects number. Use `vim_command` equivalents instead.

### `vim_grep` — E480 When No Matches

If the search pattern has no matches, Vim returns error E480. This is expected behavior. Handle gracefully in code.

### `vim_fold` openall/closeall — Fails in Terminal Mode

`neovim_vim_fold` with action `openall` or `closeall` fails with "Can't re-enter normal mode from terminal mode". Use `vim_command` equivalents instead.

---

## `vim_command` Equivalents for Broken Tools

| Tool                                       | `vim_command` Equivalent                                               |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| `vim_mark` (set mark 'a' at line 5, col 3) | `:call cursor(5, 3)` then `:normal ma`                                 |
| `vim_visual` (select lines)                | `:call cursor(startLine, startCol)` then `:normal v` + cursor movement |
| `vim_fold` openall                         | `:normal! zR`                                                          |
| `vim_fold` closeall                        | `:normal! zM`                                                          |

---

## Edit & Reload (Canonical Workflow)

**Use native tools to edit, then reload the buffer in Neovim:**

1. Use native `edit` or `write` tool to modify the file on disk
2. Run the formatter as configured for the project
3. Reload the buffer in Neovim:
   - For the current buffer: `neovim_vim_command(":e")`
   - For all changed buffers: `neovim_vim_command(":checktime")`
4. Open the file in Neovim so the user sees it: `neovim_vim_file_open` or `neovim_vim_command(":e <path>")`

This approach is more reliable than `vim_edit` because:

- Native tools use string matching, not line numbers
- No risk of editing the wrong buffer
- No `nomodifiable` issues
- The file is always in sync with disk

---

## Window Focus Step — Required Before Buffer-Dependent Operations

The OpenCode CLIIntegration terminal window holds focus when the agent runs.
Calling any MCP tool without switching away first will act on the terminal buffer,
not the user's file. Always run this snippet before any tool call that depends on
buffer context (status, LSP, diagnostics, buffer read, search, replace):

```vim
:lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == "" and bn ~= "" then vim.api.nvim_set_current_win(w) break end end
```

**What it does:** Iterates all open windows, finds the first with `buftype=""` (normal
file — excludes terminal, NeoTree, quickfix, nofile buffers) and a non-empty name,
and focuses it. Safe to call even when a file window is already focused.

**When to skip:** Only skip if the operation is explicitly window-agnostic (e.g.,
`:wa`, `:checktime`, opening a brand-new file with `vim_file_open` when you don't
need the current buffer context).

---

## Interaction Patterns

### "What's happening on line X?"

1. Run Window Focus Step (see above) — ensure a file window is active.
2. `neovim_vim_status` → get active filename and cursor.
3. `neovim_vim_buffer` (with filename) → read the target buffer.
4. Use LSP info from `neovim_vim_status` (attached clients) to reason about diagnostics if needed.
5. Respond with context from that file.

### "Modify / fix X"

1. Run Window Focus Step — ensure a file window is active.
2. Use native `edit` tool to modify the file.
3. Run the formatter as configured.
4. Reload buffer: `neovim_vim_command(":e")` or `:checktime`.
5. Open file in Neovim: `neovim_vim_file_open`.

### "Search and replace all references to Y"

1. Run Window Focus Step — ensure a file window is active.
2. `neovim_vim_grep` pattern → populates quickfix list (user sees all matches).
3. For buffer-local replace: `neovim_vim_search_replace` with pattern and replacement.
4. For project-wide replace: iterate quickfix results, open each buffer, apply native `edit`, reload with `:e`.
5. Prefer `vim_grep` first — it improves UX by showing the quickfix list before changes.

### "Open files related to Z"

1. Run Window Focus Step — ensure a file window is active.
2. Use `neovim_vim_grep` or existing knowledge to find relevant files.
3. `neovim_vim_file_open` for each file.
4. Use `neovim_vim_window split` / `vsplit` to show multiple files simultaneously when relevant.
5. Call `neovim_vim_status` after to confirm layout.

### "Go to / navigate to X"

1. Run Window Focus Step (see above) — ensure a file window is active.
2. Use `neovim_vim_command` with `:e filename`, `:b bufname`, or `:tag symbol`.
3. Use `neovim_vim_jump` for back/forward in jump list.
4. Use `neovim_vim_buffer_switch` for known buffer names.

### "Run a shell command"

- `neovim_vim_command` with `!command` prefix (only when `ALLOW_SHELL_COMMANDS=true`).
- Prefer native Vim commands when possible.

---

## LSP Integration

`neovim_vim_status` returns attached LSP clients via `lspInfo` field. If `lspInfo` is "LSP information unavailable", no LSP is attached. Use this to:

- Know which language server is active for the file type.
- Run LSP commands via `neovim_vim_command`: `:lua vim.lsp.buf.definition()`, `:lua vim.lsp.buf.references()`, etc.
- Populate quickfix with LSP diagnostics: `:lua vim.diagnostic.setqflist()`.

---

## Quickfix List — Prefer It for Multi-File Operations

The quickfix list improves discoverability. Always populate it when:

- Doing project-wide search (`neovim_vim_grep`).
- Collecting LSP references or diagnostics.
- Planning multi-file edits (user can navigate with `:cn` / `:cp`).

Open quickfix after populating: `neovim_vim_command(":copen")`.

---

## Common Mistakes

| Mistake                                  | Fix                                                                               |
| ---------------------------------------- | --------------------------------------------------------------------------------- |
| Using `vim_edit` instead of native tools | Use native `edit`/`write` + `:e` to reload                                        |
| Not reloading buffer after native edit   | Call `neovim_vim_command(":e")` or `:checktime` after editing                     |
| Not opening the file after editing       | Call `neovim_vim_file_open` or `neovim_vim_command(":e")` so user sees the result |
| Skipping quickfix for project-wide ops   | Use `neovim_vim_grep` first, then open quickfix                                   |
| Ignoring LSP clients                     | Check `neovim_vim_status` for `lspInfo` before reasoning about code symbols       |
| Using `vim_mark` or `vim_visual`         | These are broken — use `neovim_vim_command` equivalents instead                   |
| Not focusing a file window before buffer ops | Run Window Focus Step before `neovim_vim_status`, `neovim_vim_buffer`, LSP commands, or search |
