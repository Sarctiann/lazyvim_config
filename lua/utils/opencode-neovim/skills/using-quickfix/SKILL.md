---
name: using-quickfix
description: Use when doing project-wide search, collecting LSP references or diagnostics, navigating multi-file results, or any workflow that benefits from the Neovim quickfix or location list.
---

# Using Quickfix List

## Overview

The quickfix list is Neovim's built-in multi-file navigation hub. Populate it for any multi-file operation so the user can navigate results with `:cn` / `:cp` / `:copen` — giving them visibility and control over what the agent found.

**Requires:** Neovim MCP active (`vim_*` tools available). See `using-neovim` skill.

---

## When to Use

- Project-wide search (`vim_grep`)
- LSP references for a symbol
- LSP diagnostics across the codebase
- Planned multi-file edits (show scope before changing)
- Any operation returning 3+ file locations

---

## Core Pattern

### 1. Populate via `vim_grep`

```
vim_grep(pattern, filePattern?)   // e.g. pattern="MyFunction", filePattern="*.ts"
```

This automatically populates the quickfix list.

### 2. Open the list

```
vim_command(":copen")
```

User sees all matches. They can navigate with `:cn` / `:cp` or click entries.

### 3. Navigate programmatically

```
vim_command(":cfirst")   // jump to first match
vim_command(":cn")       // next match
vim_command(":cp")       // previous match
vim_command(":clast")    // last match
```

### 4. Populate via LSP (references / diagnostics)

```
vim_command(":lua vim.lsp.buf.references()")
vim_command(":lua vim.diagnostic.setqflist()")
vim_command(":copen")
```

### 5. Read quickfix entries programmatically

```
vim_command(":lua print(vim.fn.json_encode(vim.fn.getqflist()))")
```

Parse the output to get file paths and line numbers for batch edits.

---

## Multi-File Edit Workflow

1. `vim_grep` → populate quickfix
2. `vim_command :copen` → show user the scope
3. Parse `getqflist()` → collect file+line pairs
4. For each entry: `vim_file_open` → `vim_edit` → `vim_buffer_save`
5. `vim_command :cclose` when done

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

| Mistake                                             | Fix                                          |
| --------------------------------------------------- | -------------------------------------------- |
| Making multi-file edits without showing scope first | Always `vim_grep` + `:copen` before editing  |
| Using `vim_search` for project-wide search          | `vim_search` is buffer-local; use `vim_grep` |
| Forgetting to open quickfix after populating        | Always call `:copen` so user sees results    |
| Parsing quickfix output manually from buffer        | Use `getqflist()` for structured data        |
