---
name: using-neovim-lsp
description: Use when navigating code symbols, finding definitions or references, renaming symbols, reading diagnostics, or any operation that benefits from the active LSP client in Neovim.
---

# Using Neovim LSP via MCP

## Overview

When the Neovim MCP is active, use `vim_command` to invoke LSP operations through Neovim's built-in `vim.lsp` and `vim.diagnostic` APIs. Always verify an LSP client is attached before relying on LSP features.

**Requires:** Neovim MCP active. See `using-neovim` skill.

---

## Check LSP Status First

```
vim_status()   // returns "lsp_clients" field with attached client names
```

If `lsp_clients` is empty, LSP features are unavailable — fall back to `vim_grep` or file reads.

---

## Quick Reference

| Operation                    | Command                                                     |
| ---------------------------- | ----------------------------------------------------------- |
| Go to definition             | `vim_command(":lua vim.lsp.buf.definition()")`              |
| Go to declaration            | `vim_command(":lua vim.lsp.buf.declaration()")`             |
| Go to type definition        | `vim_command(":lua vim.lsp.buf.type_definition()")`         |
| Find all references          | `vim_command(":lua vim.lsp.buf.references()")`              |
| Show hover info              | `vim_command(":lua vim.lsp.buf.hover()")`                   |
| Rename symbol                | `vim_command(":lua vim.lsp.buf.rename('NewName')")`         |
| Code actions                 | `vim_command(":lua vim.lsp.buf.code_action()")`             |
| Format buffer                | `vim_command(":lua vim.lsp.buf.format()")`                  |
| All diagnostics → quickfix   | `vim_command(":lua vim.diagnostic.setqflist()")`            |
| Buffer diagnostics → loclist | `vim_command(":lua vim.diagnostic.setloclist()")`           |
| Show diagnostic at cursor    | `vim_command(":lua vim.diagnostic.open_float()")`           |
| List workspace symbols       | `vim_command(":lua vim.lsp.buf.workspace_symbol('query')")` |
| List document symbols        | `vim_command(":lua vim.lsp.buf.document_symbol()")`         |

---

## Typical Workflows

### "What does this symbol do?"

1. `vim_status` → confirm cursor position and LSP client.
2. `vim_command(":lua vim.lsp.buf.hover()")` → inline docs.

### "Find all usages of X"

1. Position cursor on symbol via `vim_command(":norm /X\n")` or `vim_mark`.
2. `vim_command(":lua vim.lsp.buf.references()")` → populates quickfix.
3. `vim_command(":copen")` → show results.
4. See `using-quickfix` skill for navigation.

### "Rename symbol Y to Z"

1. Position cursor on symbol.
2. `vim_command(":lua vim.lsp.buf.rename('Z')")`.
3. LSP applies rename across all files automatically.
4. Save affected buffers: `vim_command(":wa")`.

### "Show all errors in the project"

1. `vim_command(":lua vim.diagnostic.setqflist()")`.
2. `vim_command(":copen")`.

### "Jump to definition and open in split"

1. `vim_window("vsplit")` → open vertical split first.
2. `vim_command(":lua vim.lsp.buf.definition()")` → jump in new split.

---

## Reading Diagnostics Programmatically

```
vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get(0)))")
```

Returns diagnostics for the current buffer (bufnr=0) as JSON. Parse to reason about errors.

For all buffers:

```
vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get()))")
```

---

## Common Mistakes

| Mistake                                  | Fix                                                             |
| ---------------------------------------- | --------------------------------------------------------------- |
| Using LSP without checking client        | Always `vim_status` first; fall back to `vim_grep` if no client |
| Assuming rename worked                   | Call `:wa` after rename and verify with `vim_grep`              |
| Using `vim_search` to find references    | Use `vim.lsp.buf.references()` for semantic accuracy            |
| Forgetting `:copen` after `references()` | LSP results go to quickfix — open it so user sees them          |
