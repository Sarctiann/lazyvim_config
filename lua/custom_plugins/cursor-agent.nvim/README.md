# 🤖 cursor-agent.nvim

A Neovim plugin that seamlessly integrates [Cursor CLI](https://cursor.com) into
your Neovim workflow, providing an interactive terminal interface for AI-assisted
coding directly within your editor.

> **Note**: This plugin is a wrapper/integration tool for the Cursor CLI.
> You need to have Cursor CLI installed locally on your system for this plugin to work.

## ✨ Features

- 🚀 **Quick Access**: Open Cursor Agent terminal with simple keymaps
- 📁 **Smart Context**: Automatically attach current file or project root
- 🔄 **Multiple Modes**: Work in current directory, project root, or custom paths
- 📋 **Buffer Management**: Easily attach single or multiple open buffers
- ⚡ **Interactive Terminal**: Full terminal integration with custom keymaps
- 🎯 **Session Management**: List and manage your Cursor sessions

## 📋 Requirements

- Neovim >= 0.9.0
- [Cursor CLI](https://cursor.com) installed and available in your `$PATH`
- [snacks.nvim](https://github.com/folke/snacks.nvim) (for terminal and notifications)

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Sarctiann/cursor-agent.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  --- @type Cursor-Agent.Config
  opts = {
    use_default_mappings = true,
  },
}
```

### For local development

```lua
{
  dir = "~/.config/nvim/lua/custom_plugins/cursor-agent.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  --- @type Cursor-Agent.Config
  opts = {
    use_default_mappings = true,
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Sarctiann/cursor-agent.nvim",
  requires = { "folke/snacks.nvim" },
  config = function()
    require("cursor-agent").setup({
      use_default_mappings = true,
    })
  end
}
```

## ⚙️ Configuration

### Default Configuration

```lua
require("cursor-agent").setup({
  -- Enable default keymaps
  use_default_mappings = true,
})
```

### Configuration Options

| Option                 | Type      | Default | Description                         |
| ---------------------- | --------- | ------- | ----------------------------------- |
| `use_default_mappings` | `boolean` | `true`  | Whether to use default key mappings |

## 🎮 Usage

### Commands

The plugin provides a single command with multiple subcommands:

```vim
:CursorAgent [subcommand]
```

**Available subcommands:**

- `:CursorAgent` or `:CursorAgent open_cwd` - Open in current file's directory
- `:CursorAgent open_root` - Open in project root (git root)
- `:CursorAgent session_list` - List all Cursor sessions
- `:CursorAgent [custom args]` - Open with custom cursor-agent arguments

### Default Keymaps

When `use_default_mappings = true`:

| Keymap       | Mode   | Description                                   |
| ------------ | ------ | --------------------------------------------- |
| `<leader>aJ` | Normal | Open Cursor Agent in current file's directory |
| `<leader>aj` | Normal | Open Cursor Agent in project root             |
| `<leader>al` | Normal | Show Cursor Agent sessions                    |

### Terminal Keymaps

Once the Cursor Agent terminal is open, you have access to special keymaps:

#### Terminal Mode

| Keymap                  | Description                  |
| ----------------------- | ---------------------------- |
| `<C-s>` or `<CR><CR>`   | Submit command/message       |
| `<M-q>` or `<Esc><Esc>` | Enter normal mode            |
| `<C-p>`                 | Attach current file path     |
| `<C-p><C-p>`            | Attach all open buffer paths |
| `<M-?>` or `??` or `\\` | Show help                    |
| `<C-c>`                 | Clear/Stop/Close             |
| `<C-d>`                 | Close terminal               |
| `<C-r>`                 | Review changes               |
| `<CR>`                  | New line                     |

#### Normal Mode (in terminal)

| Keymap                                   | Description   |
| ---------------------------------------- | ------------- |
| `q` or `<Esc>`                           | Hide terminal |
| All other normal mode keys work as usual |               |

### Cursor Agent Commands

Within the Cursor Agent terminal, you can use these commands:

- `quit` or `exit` - Close Cursor Agent (press `<CR>` after)
- `/` - Show command list
- `@` - Show file list to attach
- `!` - Run command in shell

## 🚀 Quick Start

1. Install the plugin using your preferred package manager
2. Make sure Cursor CLI is installed: `cursor-agent --version`
3. Open Neovim and press `<leader>aj` to open Cursor Agent
4. Type your coding question or request
5. Press `<C-s>` or `<CR><CR>` to submit
6. Use `<C-p>` to quickly attach files to the conversation

## 💡 Tips

- **Attach Multiple Files**: Use `<C-p><C-p>` to quickly attach all your open buffers
- **Quick Submit**: Double-tap `<CR>` or use `<C-s>` to submit without leaving insert mode
- **Context Switching**: Use `:CursorAgent open_cwd` vs `:CursorAgent open_root`
  depending on whether you want file-level or project-level context
- **Help Anytime**: Press `??` in terminal mode to see all available keymaps

## 🏗️ Project Structure

```bash
cursor-agent.nvim/
└── lua/
    └── cursor-agent/
        ├── init.lua          # Main entry point and setup
        ├── config.lua        # Configuration management
        ├── terminal.lua      # Terminal singleton management
        ├── commands.lua      # Command implementations
        ├── buffers.lua       # Buffer path management
        ├── keymaps.lua       # Terminal keymaps
        ├── autocmds.lua      # Autocommands
        └── help.lua          # Help system
```

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## 📝 TODO

- [ ] Replace Snacks dependency with native Neovim APIs
- [ ] Improve terminal management (windows and buffers)
- [ ] Make keymaps fully configurable
- [ ] Add more commands and options
- [ ] Add tests
- [ ] Add documentation generation

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details

## 🙏 Acknowledgments

- [Cursor](https://cursor.com) - For the amazing AI coding assistant
- [snacks.nvim](https://github.com/folke/snacks.nvim) - For terminal and notification utilities
- The Neovim community for inspiration and support

---

Made with ❤️ for the Neovim community
