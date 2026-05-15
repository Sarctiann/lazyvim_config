---
name: using-neovim-lsp
description: Use when navigating code symbols, finding definitions or references, renaming symbols, reading diagnostics, or any operation that benefits from the active LSP client in Neovim.
---

# Using Neovim LSP via MCP

## Overview

When the Neovim MCP is active, use `neovim_vim_command` to invoke LSP operations through Neovim's built-in `vim.lsp` and `vim.diagnostic` APIs. Always verify an LSP client is attached before relying on LSP features.

**Requires:** Neovim MCP active. See `using-neovim` skill.

---

## Check LSP Status First

```
neovim_vim_status()   // returns "lspInfo" field
```

If `lspInfo` is "LSP information unavailable", no LSP client is attached — LSP features are unavailable. Fall back to `neovim_vim_grep` or file reads.

---

## Quick Reference

| Operation | Command |
| --------- | ------- |
| Go to definition | `neovim_vim_command(":lua vim.lsp.buf.definition()")` |
| Go to declaration | `neovim_vim_command(":lua vim.lsp.buf.declaration()")` |
| Go to type definition | `neovim_vim_command(":lua vim.lsp.buf.type_definition()")` |
| Find all references | `neovim_vim_command(":lua vim.lsp.buf.references()")` |
| Show hover info | `neovim_vim_command(":lua vim.lsp.buf.hover()")` |
| Rename symbol | `neovim_vim_command(":lua vim.lsp.buf.rename('NewName')")` |
| Code actions | `neovim_vim_command(":lua vim.lsp.buf.code_action()")` |
| Format buffer | `neovim_vim_command(":lua vim.lsp.buf.format()")` |
| All diagnostics → quickfix | `neovim_vim_command(":lua vim.diagnostic.setqflist()")` |
| Buffer diagnostics → loclist | `neovim_vim_command(":lua vim.diagnostic.setloclist()")` |
| Show diagnostic at cursor | `neovim_vim_command(":lua vim.diagnostic.open_float()")` |
| List workspace symbols | `neovim_vim_command(":lua vim.lsp.buf.workspace_symbol('query')")` |
| List document symbols | `neovim_vim_command(":lua vim.lsp.buf.document_symbol()")` |

---

## Typical Workflows

### "What does this symbol do?"

1. `neovim_vim_status` → confirm cursor position and LSP client via `lspInfo`.
2. `neovim_vim_command(":lua vim.lsp.buf.hover()")` → inline docs.

### "Find all usages of X"

1. Position cursor on symbol via `neovim_vim_command(":norm /X\n")` or by moving to it.
2. `neovim_vim_command(":lua vim.lsp.buf.references()")` → populates quickfix.
3. `neovim_vim_command(":copen")` → show results.
4. See `using-quickfix` skill for navigation.

### "Rename symbol Y to Z"

1. Position cursor on symbol.
2. `neovim_vim_command(":lua vim.lsp.buf.rename('Z')")`.
3. LSP applies rename across all files automatically.
4. Save affected buffers: `neovim_vim_command(":wa")`.

### "Show all errors in the project"

1. `neovim_vim_command(":lua vim.diagnostic.setqflist()")`.
2. `neovim_vim_command(":copen")`.

### "Jump to definition and open in split"

1. `neovim_vim_window("vsplit")` → open vertical split first.
2. `neovim_vim_command(":lua vim.lsp.buf.definition()")` → jump in new split.

---

## Reading Diagnostics Programmatically

```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get(0)))")
```

Returns diagnostics for the current buffer (bufnr=0) as JSON. Parse to reason about errors.

For all buffers:
```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get()))")
```

---

## No LSP Client — Fallback

If `neovim_vim_status` returns `lspInfo: "LSP information unavailable"`:
- Use `neovim_vim_grep` for project-wide search
- Use `neovim_vim_search` for buffer-local search
- LSP features (references, definition, rename) are unavailable

---

## Common Mistakes

| Mistake | Fix |
| ------- | --- |
| Using LSP without checking client | Always `neovim_vim_status` first; check `lspInfo` before LSP commands |
| Assuming rename worked | Call `:wa` after rename and verify with `neovim_vim_grep` |
| Using `vim_search` to find references | Use `vim.lsp.buf.references()` for semantic accuracy |
| Forgetting `:copen` after `references()` | LSP results go to quickfix — open it so user sees them |
