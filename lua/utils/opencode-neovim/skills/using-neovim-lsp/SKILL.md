---
name: using-neovim-lsp
description: Use when navigating code symbols, finding definitions or references, renaming symbols, reading diagnostics, or any operation that benefits from the active LSP client in Neovim.
---

# Using Neovim LSP via MCP

## Purpose

LSP through Neovim MCP is for **reading context** (hover info, diagnostics, checking which language server is active). Do NOT use MCP to perform file operations like renaming or formatting — use native tools instead.

**Requires:** Neovim MCP active. See `using-neovim` skill.

## Check LSP Status

```
neovim_vim_status()   // returns "lspInfo" field
```

If `lspInfo` is "LSP information unavailable", no LSP client is attached.

## Quick Reference (Read-Only Operations)

These are safe to use for understanding code context:

| Operation | Command |
|-----------|---------|
| Go to definition | `neovim_vim_command(":lua vim.lsp.buf.definition()")` |
| Go to type definition | `neovim_vim_command(":lua vim.lsp.buf.type_definition()")` |
| Show hover info | `neovim_vim_command(":lua vim.lsp.buf.hover()")` |
| Buffer diagnostics → loclist | `neovim_vim_command(":lua vim.diagnostic.setloclist()")` |
| Show diagnostic at cursor | `neovim_vim_command(":lua vim.diagnostic.open_float()")` |
| List workspace symbols | `neovim_vim_command(":lua vim.lsp.buf.workspace_symbol('query')")` |
| List document symbols | `neovim_vim_command(":lua vim.lsp.buf.document_symbol()")` |

## Operations to AVOID via MCP

Do NOT use MCP for these — use native tools instead:

| Operation | Why | Native Alternative |
|-----------|-----|-------------------|
| **Rename symbol** | MCP rename applies changes invisibly, conflicts with native tools | native `grep` + `edit` |
| **Format buffer** | Use the project's formatter directly | run formatter CLI or native tool |
| **Code actions** | Unreliable through MCP | use native tools to make changes |
| **Find references** | native `grep` is more thorough and reliable | native `grep` |
| **All diagnostics → quickfix** | Use native lint/typecheck commands instead | run `npm run typecheck`, `ruff`, etc. |

## Reading Diagnostics Programmatically

```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get(0)))")
```

Returns diagnostics for the current buffer (bufnr=0) as JSON. For all buffers:

```
neovim_vim_command(":lua print(vim.fn.json_encode(vim.diagnostic.get()))")
```

## No LSP Client — Fallback

If `neovim_vim_status` returns `lspInfo: "LSP information unavailable"`:

- Use native `grep` for project-wide search
- Use native `read`/`grep` for code understanding
- LSP features (hover, definition, diagnostics) are unavailable

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using LSP rename through MCP | Use native `grep` + `edit` |
| Using LSP references instead of native grep | native `grep` finds all occurrences including comments/strings |
| Using LSP formatting through MCP | Run the project's formatter directly |
| Assuming rename worked without verification | Native grep+edit gives you full control |
