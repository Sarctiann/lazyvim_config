# OpenCode Tunnel Setup

This document describes how to expose the OpenCode local server to the internet using tunneling services.

## What we implemented

### 1. Password Configuration

- Created `~/.config/opencode/password` with the server password
- Added to `~/.zshrc`:
  ```bash
  export OPENCODE_SERVER_PASSWORD=$(cat ~/.config/opencode/password 2>/dev/null)
  ```

### 2. Shell Aliases

- Updated `alias oc` to include password: `alias oc="opencode -p ${OPENCODE_SERVER_PASSWORD}"`
- Added tunnel alias: `alias ocht="npx localtunnel --port 4096"`

### 3. Lua Functions (opencode_utils.lua)

Added tunnel management functions:
- `start_tunnel()` - Starts localtunnel if server is running and password is configured
- `stop_tunnel()` - Stops the active tunnel
- `toggle_tunnel()` - Toggles tunnel on/off

### 4. Keymap

Added `<leader>ast` in `local_config.lua` to toggle the tunnel.

## Usage

1. Reload shell: `source ~/.zshrc`
2. Start OpenCode server: `<leader>asr`
3. Activate tunnel: `<leader>ast`
4. View URL: Run `ocht` in terminal

## Alternatives to Explore

### localtunnel (current)
- **Pros**: No account required, simple
- **Cons**: Random subdomain, URLs hard to predict

### nport
- Uses Cloudflare infrastructure
- Allows custom subdomains: `npx nport 4096 -s my-subdomain`
- No account required
- Requires Node.js >= 20

### untun
- Cloudflare Quick Tunnels
- No account required
- URLs: `*.trycloudflare.com`
- Command: `npx untun tunnel http://localhost:4096`

### ngrok
- Requires account (free tier available)
- More stable URLs
- Best developer experience
- Command: `ngrok http 4096` (requires authtoken setup)

## Security Notes

- The server is protected with `OPENCODE_SERVER_PASSWORD`
- Only expose tunnels temporarily, not permanently
- Be careful with what you expose to the internet