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
| `--help` | Print usage and exit |

## What It Does

1. **Symlink configs** — links files to `$HOME` (backs up existing to `.backup.<timestamp>`); also creates `.local` override stubs
2. **Homebrew** — install if missing, run `brew bundle` from Brewfile
3. **vim-plug** — Neovim plugin manager
4. **TPM** — tmux plugin manager
5. **Oh My Zsh** — base install
6. **Zsh plugins** — zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab (cloned into custom plugins dir)
7. **pyenv** — Python version manager
8. **mise** — polyglot runtime manager
9. **Poetry** — Python dependency manager (v1.x via uv; uninstalls Homebrew Poetry v2 if present)
10. **meldr + recon** — multi-repo workspace manager and Claude agent dashboard (via `cargo install`)
11. **Fly CLI** — Fly.io deployment CLI
12. **Vercel CLI** — Vercel deployment CLI (npm global)
13. **Bun** — JavaScript runtime and toolkit (official installer)
14. **Coding agents** — Antigravity, Devin (curl); Claude Code, Gemini CLI, Codex, Pi, DeepSeek TUI (npm global); OpenCode, Kiro (Brewfile); Cursor (Brewfile cask, ships `cursor` CLI)
15. **Secrets template** — `~/ee` (chmod 600, sourced by zshrc)
16. **macOS defaults** — keyboard repeat, Finder, Dock, trackpad
17. **Neovim plugins** — headless `:PlugInstall`
18. **tmux plugins** — TPM install
19. **Claude Code MCP** — copies `mcp.json` if missing, merges new servers into existing config, injects GitHub token from `gh` CLI if authenticated
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
| `cli-upgrades` | `~/cli-upgrades` | — | Symlinked, executable; invoked by `cliup` alias |
| `configs/claude/settings.json` | `~/.claude/settings.json` | — | Claude Code settings and hooks |
| `configs/claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | — | Claude Code statusline script |
| `configs/claude/mcp.json` | `~/.claude/.mcp.json` | — | Copied, not symlinked (secrets injected) |
| `configs/claude/claude-notify.sh` | `~/.claude/claude-notify.sh` | — | Hook script for Stop/Notification events |
| `configs/meldr_prompt.sh` | `~/.config/meldr_prompt.sh` | — | meldr starship prompt integration |

Local override files are created empty by `setup.sh` and are never committed. They load after the managed config, so values set in `.local` files win.

**Per-laptop overrides via `~/fmcevoy`.** If a private repo exists at `~/fmcevoy`, `setup.sh` will symlink matching files from `~/fmcevoy/local/` in place of creating empty stubs. Flat naming convention:

| `$HOME` target | `~/fmcevoy/local/` source |
|---|---|
| `~/.zshrc.local` | `zshrc.local` |
| `~/.completions.local.zsh` | `completions.local.zsh` |
| `~/.tmux.conf.local` | `tmux.conf.local` |
| `~/.config/nvim/init.local.vim` | `init.local.vim` |
| `~/.config/ghostty/config.local` | `ghostty.config.local` |
| `~/.ssh/config.local` | `ssh.config.local` |

## Shell Completions

Tab completions come from three layers:

| Source | Coverage |
|--------|----------|
| **carapace** (brew) | 800+ CLIs: git, docker, kubectl, terraform, aws, helm, etc. |
| **oh-my-zsh plugins** | git, fzf, docker, kubectl, golang, terraform |
| **completions.zsh** (custom) | claude, cursor, gemini, codex, pi, kiro-cli, deepseek-tui, opencode, difft, duf, grpcurl, sshuttle, tre, yamllint, virtualenv, meldr |

Add machine-specific completions in `~/.completions.local.zsh`.

## Environment Defaults

Set in zshrc, override in `~/.zshrc.local` or `~/ee`:

| Variable | Default | Used by |
|----------|---------|---------|
| `MELDR_AGENT` | `claude` | meldr workspace agent |

## Claude Session Notifications

| Signal | Event | Mechanism |
|--------|-------|-----------|
| `Glass.aiff` chime | Claude finishes a task (`Stop`) | Claude Code hook → `afplay` |
| `Funk.aiff` ping | Claude is waiting on you (`Notification`) | Claude Code hook → `afplay` |
| Tab flashes red/yellow | `Stop` (red) or `Notification` (yellow), focused or inactive tab | Hook sets `@cc_status` on the tmux window; `window-status-format` conditionals in `tmux.conf` paint it. Clears on tab focus; auto-clears after 3 s if the Claude tab is active, 60 s otherwise. |

Hook script: `mac_setup/configs/claude/claude-notify.sh` → symlinked to `~/.claude/claude-notify.sh`.
Wired in `configs/claude/settings.json` under `hooks.Stop` and `hooks.Notification`.

State files written per-session to `~/.cache/claude-agents/<session_id>.json` — readable by dashboard tools.

### Agent dashboard

`agents` (alias for `recon`) opens a persistent TUI dashboard showing all Claude sessions, their worktree/branch, model, context %, and last-active time. Run it in a dedicated tmux pane.

Installed automatically by `setup.sh` (step 10). To upgrade: `cliup --only recon`.

## Dev Session Layout

`t` (alias for `~/start_tmux_dev`) creates or attaches a tmux session named **Dev**.
If **Dev** already exists, `t` just re-attaches — safe to run repeatedly.

**Window 0 — `apps`** (8 tiled panes):

| Pane | Runs |
|------|------|
| 0 | `recon view` (agents dashboard, auto-restart loop) |
| 1 | `sch` if defined (user-supplied in `~/.zshrc.local`) |
| 2 | `claude agents` in `~/fmcevoy` (or `~/fmcevoy_tools`) |
| 3 | shell in `$HOME` |
| 4 | `yazi ~/workspaces` |
| 5–7 | empty shells |

**Additional windows:** one per active meldr worktree, auto-created by scanning `~/workspaces/ws-*/` and invoking `meldr worktree open <branch>`. Layout inside each worktree window is owned by meldr.

Prefix is `C-a`. Press `h` for the full key/alias reference card.

## After Setup

1. Edit `~/.gitconfig.local` with your name and email
2. `gh auth login`
3. If using the Supabase MCP server, set `SUPABASE_ACCESS_TOKEN` in `~/ee`
4. Open Ghostty, type `t` to start tmux Dev session
5. `h` for the command reference card
6. See `SECRETS_CHECKLIST.md` for remaining credentials
