---
name: using-quickfix
description: Use when doing project-wide search, collecting LSP references or diagnostics, navigating multi-file results, or any workflow that benefits from the Neovim quickfix or location list.
---

# Using Quickfix List

## Overview

The quickfix list is Neovim's built-in multi-file navigation hub. Populate it for any multi-file operation so the user can navigate results with `:cn` / `:cp` / `:copen` — giving them visibility and control over what the agent found.

**Requires:** Neovim MCP active (`neovim_vim_*` tools available). See `using-neovim` skill.

---

## When to Use

- Project-wide search (`neovim_vim_grep`)
- LSP references for a symbol
- LSP diagnostics across the codebase
- Planned multi-file edits (show scope before changing)
- Any operation returning 3+ file locations

---

## Window Focus Step — Required Before Quickfix Operations

Before populating or navigating the quickfix list, always run the Window Focus Step
(`using-neovim` skill) to ensure operations target a file buffer, not the terminal window.

```vim
:lua for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w) local bt = vim.bo[b].buftype local bn = vim.api.nvim_buf_get_name(b) if bt == "" and bn ~= "" then vim.api.nvim_set_current_win(w) break end end
```

---

## Core Pattern

### 1. Populate via `vim_grep`

```
neovim_vim_grep(pattern, filePattern?)
```

This automatically populates the quickfix list. Note: `neovim_vim_grep` returns E480 if no matches — this is expected Vim behavior.

### 2. Open the list

```
neovim_vim_command(":copen")
```

User sees all matches. They can navigate with `:cn` / `:cp` or click entries.

### 3. Navigate programmatically

```
neovim_vim_command(":cfirst")   // jump to first match
neovim_vim_command(":cn")       // next match
neovim_vim_command(":cp")       // previous match
neovim_vim_command(":clast")    // last match
```

### 4. Populate via LSP (references / diagnostics)

```
neovim_vim_command(":lua vim.lsp.buf.references()")
neovim_vim_command(":lua vim.diagnostic.setqflist()")
neovim_vim_command(":copen")
```

### 5. Read quickfix entries programmatically

```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.fn.getqflist()))")
```

Parse the output to get file paths and line numbers for batch edits.

---

## Multi-File Edit Workflow

1. Run Window Focus Step (`using-neovim` skill) — ensure a file window is active.
2. `neovim_vim_grep` → populate quickfix.
3. `neovim_vim_command(":copen")` → show user the scope.
4. Parse `getqflist()` → collect file+line pairs.
5. For each entry: use native `edit`/`write` tool to modify the file, then `neovim_vim_command(":e")` to reload buffer.
6. `neovim_vim_command(":cclose")` when done.

---

## Location List vs Quickfix

|          | Quickfix               | Location List          |
| -------- | ---------------------- | ---------------------- |
| Scope    | Global (shared)        | Per-window             |
| Commands | `:copen`, `:cn`, `:cp` | `:lopen`, `:ln`, `:lp` |
| Use case | Project-wide results   | Window-local results   |

Prefer **quickfix** for agent-driven operations (simpler, global).

---

## Common Mistakes

| Mistake                                             | Fix                                                             |
| --------------------------------------------------- | --------------------------------------------------------------- |
| Making multi-file edits without showing scope first | Always `neovim_vim_grep` + `:copen` before editing              |
| Using `vim_search` for project-wide search          | `vim_search` is buffer-local; use `neovim_vim_grep`             |
| Forgetting to open quickfix after populating        | Always call `neovim_vim_command(":copen")` so user sees results |
| Parsing quickfix output manually from buffer        | Use `getqflist()` for structured data                           |
| Using `vim_edit` for multi-file edits               | Use native `edit`/`write` + `:e` to reload instead              |
| Not focusing a file window before quickfix ops | Run Window Focus Step before `neovim_vim_grep` and quickfix population |
