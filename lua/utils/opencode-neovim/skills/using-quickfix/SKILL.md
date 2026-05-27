---
name: using-quickfix
description: Use when doing project-wide search, collecting LSP references or diagnostics, navigating multi-file results, or any workflow that benefits from the Neovim quickfix or location list.
---

# Using Quickfix List

## Purpose

The quickfix list lets the user navigate multi-file results with `:cn` / `:cp` / `:copen`. Populate it only **after** doing the actual work with native tools — it's a visualization aid, not a work mechanism.

**Requires:** Neovim MCP active (`neovim_vim_*` tools available). See `using-neovim` skill.

## When to Use

- After a project-wide search via native `grep` — show results so user can browse
- After collecting references — populate quickfix for navigation
- Before multi-file edits — show scope so the user can review

## Core Pattern

### 1. Do the actual search with native tools

```
grep <pattern>  // native grep to find matches
```

### 2. Populate quickfix for user navigation

```
neovim_vim_grep(<pattern>)
neovim_vim_command(":copen")
```

This shows the user all matches without you having to do the search through MCP.

### 3. Navigate programmatically

```
neovim_vim_command(":cfirst")   // jump to first match
neovim_vim_command(":cn")       // next match
neovim_vim_command(":cp")       // previous match
neovim_vim_command(":clast")    // last match
```

### 4. Read quickfix entries programmatically

```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.fn.getqflist()))")
```

Parse the output to get file paths and line numbers.

## Populate via LSP (references / diagnostics)

Only use when you specifically need semantic results. For thorough results, prefer native `grep`.

```
neovim_vim_command(":lua vim.lsp.buf.references()")
neovim_vim_command(":lua vim.diagnostic.setqflist()")
neovim_vim_command(":copen")
```

## Multi-File Edit Workflow

1. Use native `grep` / `glob` to identify which files to edit.
2. Optionally: `neovim_vim_grep(<pattern>)` + `:copen` to show the scope.
3. Apply edits with native `edit`/`write` tools.
4. Reload buffers: `neovim_vim_command(":checktime")`.
5. `neovim_vim_command(":cclose")` when done.

## Location List vs Quickfix

| | Quickfix | Location List |
|--|----------|---------------|
| Scope | Global (shared) | Per-window |
| Commands | `:copen`, `:cn`, `:cp` | `:lopen`, `:ln`, `:lp` |
| Use case | Project-wide results | Window-local results |

Prefer **quickfix** for agent-driven operations.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `neovim_vim_grep` as the primary search tool | Use native `grep` — `vim_grep` is only for showing results |
| Making multi-file edits without showing scope first | Populate quickfix before editing so user can review |
| Using `vim_search` for project-wide search | `vim_search` is buffer-local; use native `grep` |
| Forgetting to open quickfix after populating | Always call `neovim_vim_command(":copen")` |
