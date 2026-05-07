import { tool } from "@opencode-ai/plugin";

/**
 * nvim-diagnostics: Retrieves LSP diagnostics and quickfix list from the active Neovim session.
 *
 * Uses vim_command (from the neovim MCP) to query vim.diagnostic and vim.fn.getqflist()
 * and returns structured data the agent can reason about directly.
 *
 * Requires: neovim MCP enabled and connected.
 */

export const diagnostics = tool({
  description:
    "Get LSP diagnostics from the active Neovim buffer or all buffers. Returns structured list of errors, warnings and hints with file, line, column and message.",
  args: {
    scope: tool.schema
      .enum(["buffer", "all"])
      .describe(
        'Scope of diagnostics to fetch. "buffer" = current buffer only, "all" = entire workspace.',
      )
      .default("buffer"),
  },
  async execute(args, _context) {
    // We cannot call vim_command directly from a custom tool —
    // this tool generates the vim.diagnostic lua command string
    // that the agent should pass to vim_command.
    const bufnr = args.scope === "buffer" ? "0" : "nil";
    const luaCmd = `print(vim.fn.json_encode(vim.diagnostic.get(${bufnr})))`;

    return [
      `To retrieve ${args.scope === "buffer" ? "current buffer" : "all workspace"} diagnostics, call:`,
      ``,
      `vim_command({ command: ":lua ${luaCmd}" })`,
      ``,
      `The output is a JSON array. Each entry has:`,
      `  bufnr    - buffer number (use vim_buffer to read it)`,
      `  lnum     - line number (0-indexed)`,
      `  col      - column (0-indexed)`,
      `  severity - 1=ERROR, 2=WARN, 3=INFO, 4=HINT`,
      `  message  - diagnostic text`,
      `  source   - LSP client name`,
      ``,
      `To also populate the quickfix list and open it:`,
      `  vim_command({ command: ":lua vim.diagnostic.setqflist()" })`,
      `  vim_command({ command: ":copen" })`,
    ].join("\n");
  },
});

export const quickfix = tool({
  description:
    "Get the current Neovim quickfix list entries. Returns structured data with file paths, line numbers and text for each entry.",
  args: {},
  async execute(_args, _context) {
    return [
      `To retrieve the current quickfix list, call:`,
      ``,
      `vim_command({ command: ":lua print(vim.fn.json_encode(vim.fn.getqflist()))" })`,
      ``,
      `The output is a JSON array. Each entry has:`,
      `  bufnr    - buffer number`,
      `  filename - file path (if bufnr = 0)`,
      `  lnum     - line number (1-indexed)`,
      `  col      - column (1-indexed)`,
      `  text     - match text or diagnostic message`,
      `  type     - "E"=error, "W"=warning, ""=info`,
      `  valid    - 1 if entry is valid`,
      ``,
      `To navigate: vim_command({ command: ":cfirst" }) / :cn / :cp / :clast`,
      `To open list: vim_command({ command: ":copen" })`,
    ].join("\n");
  },
});
