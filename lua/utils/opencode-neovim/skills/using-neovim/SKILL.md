---
name: using-neovim
description: Use when the neovim MCP is available, or when the user mentions neovim, opening/closing/reading files in an editor, buffer navigation, text editing via editor, or any interaction with a text editor integrated session.
---

# Using Neovim MCP

## Overview

When the `neovim` MCP server is available, Neovim IS the primary user interface. Treat it as the canonical view of the user's workspace: always reflect changes there, open relevant files for context, and leverage Vim-native features (quickfix, LSP, marks, etc.) for a seamless editing experience.

## Detecting Neovim MCP Availability

At session start, call `vim_health` or `vim_status`. If it succeeds, the Neovim MCP is active — follow this skill for all file and editor interactions.

If it fails or the tool is absent, fall back to standard file tools.

## Core Principle

> **Every meaningful action should be visible in Neovim.**

After any edit, open, or navigation: leave the buffer focused so the user sees the result immediately.

---

## Tools Quick Reference

| Tool                 | Purpose                                                  |
| -------------------- | -------------------------------------------------------- |
| `vim_status`         | Current buffer, cursor, mode, LSP clients, window layout |
| `vim_buffer`         | Read buffer contents (optionally by filename)            |
| `vim_buffer_switch`  | Switch to buffer by name or number                       |
| `vim_buffer_save`    | Save current or named buffer                             |
| `vim_file_open`      | Open a file into a new buffer                            |
| `vim_edit`           | Insert / replace / replaceAll lines                      |
| `vim_command`        | Run any Vim command (`:norm`, `:e`, `:bd`, `!shell`)     |
| `vim_search`         | Regex search within current buffer                       |
| `vim_search_replace` | Find-and-replace in current buffer                       |
| `vim_grep`           | Project-wide vimgrep → populates quickfix list           |
| `vim_window`         | Split, vsplit, close, navigate windows                   |
| `vim_mark`           | Set named marks (a–z)                                    |
| `vim_register`       | Set register content                                     |
| `vim_visual`         | Create visual selections                                 |
| `vim_macro`          | Record / stop / play macros                              |
| `vim_tab`            | Tab management (new, close, next, prev…)                 |
| `vim_fold`           | Code folding                                             |
| `vim_jump`           | Jump list navigation (back/forward)                      |
| `vim_health`         | Connection health check                                  |

---

## Interaction Patterns

### "What's happening on line X?"

1. `vim_status` → get active filename and cursor.
2. `vim_buffer` (no arg) → read current buffer.
3. Use LSP info from `vim_status` (attached clients) to reason about diagnostics if needed.
4. Respond with context from that file.

### "Modify / fix X"

1. `vim_status` → confirm active file.
2. `vim_buffer` → read content, find target lines.
3. `vim_edit` with `replace` mode at the correct `startLine`.
4. `vim_buffer_save` → persist.
5. Leave focus on the edited buffer (use `vim_command :e <file>` if needed to refresh display).

### "Search and replace all references to Y"

1. `vim_grep pattern *.ext` → populates quickfix list (user sees all matches).
2. For buffer-local replace: `vim_search_replace` with `global: true`.
3. For project-wide replace: iterate quickfix results, open each buffer, apply `vim_search_replace`, save.
4. Prefer `vim_grep` first — it improves UX by showing the quickfix list before changes.

### "Open files related to Z"

1. Use `vim_grep` or existing knowledge to find relevant files.
2. `vim_file_open` for each file.
3. Use `vim_window split` / `vsplit` to show multiple files simultaneously when relevant.
4. Call `vim_status` after to confirm layout.

### "Go to / navigate to X"

- Use `vim_command` with `:e filename`, `:b bufname`, or `:tag symbol`.
- Use `vim_jump` for back/forward in jump list.
- Use `vim_buffer_switch` for known buffer names.

### "Run a shell command"

- `vim_command` with `!command` prefix (only when `ALLOW_SHELL_COMMANDS=true`).
- Prefer native Vim commands when possible.

---

## LSP Integration

`vim_status` returns attached LSP clients. Use this to:

- Know which language server is active for the file type.
- Run LSP commands via `vim_command`: `:lua vim.lsp.buf.definition()`, `:lua vim.lsp.buf.references()`, etc.
- Populate quickfix with LSP diagnostics: `:lua vim.diagnostic.setqflist()`.

---

## Quickfix List — Prefer It for Multi-File Operations

The quickfix list improves discoverability. Always populate it when:

- Doing project-wide search (`vim_grep`).
- Collecting LSP references or diagnostics.
- Planning multi-file edits (user can navigate with `:cn` / `:cp`).

Open quickfix after populating: `vim_command :copen`.

---

## Common Mistakes

| Mistake                                              | Fix                                                                     |
| ---------------------------------------------------- | ----------------------------------------------------------------------- |
| Editing a file with Write tool instead of `vim_edit` | Always use `vim_edit` + `vim_buffer_save` when Neovim MCP is active     |
| Not opening the file after editing                   | Call `vim_file_open` or `vim_command :e` so user sees the result        |
| Skipping quickfix for project-wide ops               | Use `vim_grep` first, then open quickfix                                |
| Assuming buffer = disk file                          | Call `vim_buffer_save` explicitly after edits                           |
| Ignoring LSP clients                                 | Check `vim_status` for attached LSP before reasoning about code symbols |
