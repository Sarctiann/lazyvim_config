---
description: Find all LSP references for the symbol under cursor and show in quickfix
---

1. Call vim_status to get the current cursor position and confirm an LSP client is attached.
2. Run vim_command with ":lua vim.lsp.buf.references()" to populate the quickfix list with all references.
3. Run vim_command with ":copen" to show the quickfix list.
4. Run vim_command with ":lua print(vim.fn.json_encode(vim.fn.getqflist()))" and summarize: how many references, which files and lines.

If no LSP client is attached, fall back to vim_grep using the word under the cursor from vim_status.
If the Neovim MCP is not available, say so clearly.
