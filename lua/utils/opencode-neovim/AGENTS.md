# Neovim Integration Rules

This file only adds rules for OpenCode sessions launched from Neovim. Global user rules live in the parent `AGENTS.md`.

## Source-First Workflow

- `~/.config/opencode/opencode-neovim/` is the source of truth for this integration.
- Make all changes in this directory first.
- Do not modify files under `~/.config/nvim/` unless the user explicitly asks.
- After changes are committed (if user requests a commit), sync the source to the Neovim mirror:

```bash
rsync -av --exclude='node_modules' --exclude='.git' \
  ~/.config/opencode/opencode-neovim/ \
  ~/.config/nvim/lua/utils/opencode-neovim/
```

## Role of Neovim MCP

Neovim MCP exists for **visualization and context sharing**, NOT for executing file operations.

### Use MCP only for:
- **Showing results** — after native edits, open the file so the user sees it
- **Reading user context** — call `neovim_vim_status` when the user says "this line" / "this file" without specifying paths
- **Populating quickfix** — `neovim_vim_grep` + `:copen` after project-wide work so the user can navigate results

### Do NOT use MCP for:
- File editing (use native `edit`/`write`)
- Searching or replacing text (use native `grep`/`edit`)
- Renaming symbols (use native `grep` + `edit`)
- Navigating code (use native `read`/`grep`/glob)
- Window focus switching (removed — impractical and error-prone)

## When MCP is Active

Invoke the `using-neovim` skill for detailed guidance on visualization patterns.

## Deprecated MCP Tools

- `neovim_vim_edit` — use native `edit`/`write`
- `neovim_vim_buffer_save` — use native `write`
- `neovim_vim_search` / `neovim_vim_search_replace` — use native `grep`/`edit`
- `neovim_vim_mark` / `neovim_vim_visual` — broken (MCP server bug)
