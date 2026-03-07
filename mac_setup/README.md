# mac_setup

One command to reproduce the entire macOS development environment.

## Quick Start

```bash
git clone https://github.com/fmcevoy/fmcevoy_tools.git ~/fmcevoy_tools
cd ~/fmcevoy_tools/mac_setup
chmod +x setup.sh macos_defaults.sh
./setup.sh
```

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Print what would happen without making changes |
| `--skip-brew` | Skip Homebrew install and brew bundle |
| `--no-upgrade` | Install missing packages only, don't upgrade existing |

## What It Does (in order)

1. **Symlink configs** — all config files in `configs/` are symlinked to their home locations
2. **Homebrew** — install if missing, run `brew bundle` from Brewfile
3. **vim-plug** — install Neovim plugin manager
4. **TPM** — install tmux plugin manager
5. **Oh My Zsh** — install with custom plugins (autosuggestions, syntax highlighting, fzf-tab)
6. **pyenv** — Python version manager
7. **mise** — polyglot runtime manager
8. **Secrets** — create `~/ee` template (chmod 600)
9. **macOS defaults** — keyboard repeat, Finder, Dock, trackpad preferences
10. **Neovim plugins** — headless `:PlugInstall`
11. **tmux plugins** — TPM install
12. **Claude Code MCP servers** — configures MCP servers (Context7, Playwright, GitHub, Supabase, AWS CDK, Docker, Fly.io, gcloud, sequential-thinking) and injects GitHub token from `gh` CLI
13. **Git identity** — create `~/.gitconfig.local` template

## Config Files

| Source | Target |
|--------|--------|
| `configs/zshrc` | `~/.zshrc` |
| `configs/gitconfig` | `~/.gitconfig` |
| `configs/gitignore_global` | `~/.gitignore` |
| `configs/vim/init.vim` | `~/.config/nvim/init.vim` |
| `configs/tmux/tmux.conf` | `~/.tmux.conf` |
| `configs/tmux/start_tmux_dev` | `~/start_tmux_dev` |
| `configs/tmux/help` | `~/tmux_help` |
| `configs/ghostty/config` | `~/.config/ghostty/config` |
| `configs/starship.toml` | `~/.config/starship.toml` |
| `configs/ssh/config` | `~/.ssh/config` |
| `configs/worktreerc` | `~/.worktreerc` |
| `configs/claude/mcp.json` | `~/.claude/.mcp.json` (copied, not symlinked — secrets injected at setup) |

## After Setup

1. Edit `~/.gitconfig.local` with your name and email
2. Run `gh auth login` to authenticate GitHub CLI
3. Open Ghostty, type `t` to start tmux Dev session
4. Type `h` for the command reference card
5. See `SECRETS_CHECKLIST.md` for remaining credentials
6. Set `SUPABASE_ACCESS_TOKEN` in `~/ee` for Supabase MCP (get from supabase.com/dashboard/account/tokens)
