# mac_setup

One command to reproduce the entire macOS development environment.

## Quick Start

```bash
git clone https://github.com/fmcevoy/fmcevoy_tools.git ~/fmcevoy_tools
cd ~/fmcevoy_tools/mac_setup
./setup.sh
```

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Print what would happen without making changes |
| `--skip-brew` | Skip Homebrew install and brew bundle |
| `--no-upgrade` | Install missing packages only, don't upgrade existing |

## What It Does

1. **Symlink configs** — links config files to `$HOME`, backs up any existing files to `.backup.<timestamp>`
2. **Create `.local` overrides** — empty local override files so includes never fail
3. **Homebrew** — install if missing, run `brew bundle` from Brewfile
4. **vim-plug** — Neovim plugin manager
5. **TPM** — tmux plugin manager
6. **Oh My Zsh** — with plugins: autosuggestions, syntax-highlighting, fzf-tab
7. **pyenv** — Python version manager
8. **mise** — polyglot runtime manager
9. **Poetry** — Python dependency manager (v1.x via uv)
10. **meldr** — multi-repo workspace manager (via `cargo install`)
11. **Fly CLI** — Fly.io deployment CLI
12. **Vercel CLI** — Vercel deployment CLI (npm global)
13. **Bun** — JavaScript runtime and toolkit (official installer)
14. **Coding agents** — Claude Code, Gemini CLI, Codex, Pi (npm global); OpenCode (brew); Kiro (cask); Cursor (auto-updates)
15. **Secrets template** — `~/ee` (chmod 600, sourced by zshrc)
16. **macOS defaults** — keyboard repeat, Finder, Dock, trackpad
17. **Neovim plugins** — headless `:PlugInstall`
18. **tmux plugins** — TPM install
19. **Claude Code MCP** — configures MCP servers, injects GitHub token from `gh` CLI
20. **Git identity** — creates `~/.gitconfig.local` template

## Config Files

All configs are symlinked from `configs/` to `$HOME`. If a file already exists at the target, it is moved to `<target>.backup.<timestamp>` before linking.

| Source | Target | Local override | Override mechanism |
|--------|--------|---------------|-------------------|
| `configs/zshrc` | `~/.zshrc` | `~/.zshrc.local` | `source` at end |
| `configs/completions.zsh` | `~/.completions.zsh` | `~/.completions.local.zsh` | `source` at end |
| `configs/gitconfig` | `~/.gitconfig` | `~/.gitconfig.local` | `[include] path` |
| `configs/tmux/tmux.conf` | `~/.tmux.conf` | `~/.tmux.conf.local` | `source-file` at end |
| `configs/vim/init.vim` | `~/.config/nvim/init.vim` | `~/.config/nvim/init.local.vim` | `source` at end |
| `configs/ghostty/config` | `~/.config/ghostty/config` | `~/.config/ghostty/config.local` | `config-file` directive |
| `configs/ssh/config` | `~/.ssh/config` | `~/.ssh/config.local` | `Include` at top |
| `configs/starship.toml` | `~/.config/starship.toml` | — | No include support |
| `configs/gitignore_global` | `~/.gitignore` | — | |
| `configs/tmux/start_tmux_dev` | `~/start_tmux_dev` | — | |
| `configs/tmux/help` | `~/tmux_help` | — | |
| `configs/claude/mcp.json` | `~/.claude/.mcp.json` | — | Copied, not symlinked (secrets injected) |

Local override files are created empty by `setup.sh` and are never committed. They load after the managed config, so values set in `.local` files win.

## Shell Completions

Tab completions come from three layers:

| Source | Coverage |
|--------|----------|
| **carapace** (brew) | 800+ CLIs: git, docker, kubectl, terraform, aws, helm, etc. |
| **oh-my-zsh plugins** | git, fzf, docker, kubectl, golang, terraform |
| **completions.zsh** (custom) | claude, cursor, gemini, codex, pi, kiro-cli, opencode, meldr, difft, duf, grpcurl, sshuttle, tre, yamllint, virtualenv |

Add machine-specific completions in `~/.completions.local.zsh`.

## Environment Defaults

Set in zshrc, override in `~/.zshrc.local` or `~/ee`:

| Variable | Default | Used by |
|----------|---------|---------|
| `MELDR_AGENT` | `claude` | meldr workspace agent |

## After Setup

1. Edit `~/.gitconfig.local` with your name and email
2. `gh auth login`
3. Open Ghostty, type `t` to start tmux Dev session
4. `h` for the command reference card
5. See `SECRETS_CHECKLIST.md` for remaining credentials
