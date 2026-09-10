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

1. **Symlink configs** — links files to `$HOME` (backs up existing to `.backup.<timestamp>`); also creates `.local` override stubs. Two targets are deliberately not symlinks — see below
2. **Homebrew** — install if missing, run `brew bundle` from Brewfile
3. **vim-plug** — Neovim plugin manager
4. **TPM** — tmux plugin manager
5. **Oh My Zsh** — base install
6. **Zsh plugins** — zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab (cloned into custom plugins dir)
7. **pyenv** — Python version manager
8. **mise** — polyglot runtime manager
9. **Poetry** — Python dependency manager (v1.x via uv; uninstalls Homebrew Poetry v2 if present)
10. **meldr + recon** — multi-repo workspace manager and Claude agent dashboard (via `cargo install`); also runs `meldr install-hooks` so the Claude Code hooks match the binary just built
11. **Fly CLI** — Fly.io deployment CLI
12. **Vercel CLI** — Vercel deployment CLI (npm global)
13. **Bun** — JavaScript runtime and toolkit (official installer)
14. **Coding agents** — Antigravity, Devin, Grok Build (curl); Claude Code, Gemini CLI, Codex, Pi, DeepSeek TUI (npm global); Kimi Code CLI (uv tool); OpenCode, Kiro (Brewfile); Cursor (Brewfile cask, ships `cursor` CLI)
15. **Secrets template** — `~/ee` (chmod 600, sourced by zshrc)
16. **macOS defaults** — keyboard repeat, Finder, Dock, trackpad
17. **Neovim plugins** — headless `:PlugInstall`
18. **tmux plugins** — TPM install
19. **Claude Code MCP** — copies `mcp.json` if missing, merges new servers into existing config, injects GitHub token from `gh` CLI if authenticated
20. **Git identity** — creates `~/.gitconfig.local` template
21. **Private laptop overlay** — runs `~/fmcevoy/laptop/bootstrap.sh` last if it exists and is executable; skips quietly otherwise

## Config Files

Most configs are symlinked from `configs/` to `$HOME`. If a file already exists at the target, it is moved to `<target>.backup.<timestamp>` before linking.

Two targets are handled differently, because something other than this repo writes to them. A symlink would send those writes straight into tracked source and dirty a pristine checkout:

- **`~/.zshrc` is a real file**, three lines long, that `source`s `configs/zshrc`. Third-party installers append to `~/.zshrc` — one did on 2026-09-10 — and those appends now land in the untracked shim, after the managed config, so they still take effect. Re-running `setup.sh` leaves an existing shim untouched.
- **`~/.claude/settings.json` is merged, not linked.** Claude Code rewrites it whenever a setting changes, and older meldr builds resolved the symlink before writing — which is how meldr's hook block came to be committed here. Seeding it once would be no better across several laptops: a change to the managed template would never reach a machine that already had the file. So `setup.sh` merges instead, one level deep and the same way Step 19 merges `mcp.json` — keys the live file lacks are added, keys it already has are left alone, so a newly enabled plugin reaches every laptop without overriding one machine's own choices. An existing symlink is materialised into a real file first, keeping its content. The hook entries are meldr's to install and no longer ship in the template.

| Source | Target | Local override | Override mechanism |
|--------|--------|---------------|-------------------|
| `configs/zshrc` | `~/.zshrc` | `~/.zshrc.local` | `source` at end; `~/.zshrc` is a real shim, not a symlink |
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
| `configs/claude/settings.json` | `~/.claude/settings.json` | — | Merged, not symlinked; hooks come from `meldr install-hooks` |
| `configs/claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | — | Claude Code statusline script |
| `configs/claude/mcp.json` | `~/.claude/.mcp.json` | — | Copied, not symlinked (secrets injected) |
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

`setup.sh` also **finishes** by running `~/fmcevoy/laptop/bootstrap.sh` (Step 21) when that file exists and is executable, passing `--dry-run` through. This has to be the last step: Step 1 links this repo's base configs over paths the overlay also owns — `~/.claude/settings.json`, `~/start_tmux_dev` and others — so a `setup.sh` run that is not followed by the private bootstrap silently reverts the laptop to the public defaults. A failure in the overlay warns rather than aborting, and on a machine with no `~/fmcevoy` the step is a no-op.

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

| Signal | Meaning |
|--------|---------|
| `Glass.aiff` + red tab, red pane border | A Claude session in that pane finished |
| `Funk.aiff` + orange tab, orange pane border | It is waiting on you (a question, `AskUserQuestion`, or `needs input:`) |
| `Pop.aiff` + purple `⇣` tab | A Claude **background job** finished in that worktree |
| `Submarine.aiff` + blue `⇣` tab | A background job is waiting on you |

The background states are separate because Claude runs background jobs in one
detached host process that belongs to no pane, so meldr can identify the worktree
window but not which pane — the indicator says so rather than picking one.

The pane is the source of truth (`@cc_pane_status`); a window's `@cc_status` is
derived from its panes and shows the most urgent, so one agent finishing never
hides a sibling that is still waiting. Indicators clear when you select the pane
or window, and otherwise expire after `MELDR_CC_TIMEOUT` seconds (default 5).

Hooks are managed by meldr — run `meldr install-hooks` to write one
`meldr claude-hook stop|notify|session-start` entry per event into
`~/.claude/settings.json`. `Notification` is registered only for the types that
mean the agent is genuinely blocked on you, so routine events like `auth_success`
no longer light the tab.

**No `claude()` shell wrapper.** There used to be one in `configs/zshrc` that
exported `MELDR_TMUX_PANE` / `MELDR_TMUX_WINDOW_ID`. It computed the window with
an untargeted `tmux display-message`, which returns the *focused* window rather
than the pane's own, so it was a cause of notifications landing on the wrong tab.
meldr now derives the pane from the process tree and a live `tmux list-panes`
snapshot and reads neither variable.

Run `meldr doctor hooks` from inside tmux to verify the whole pipeline: it runs
the resolver through a nested shell, as Claude invokes a hook, and checks both the
pane and the window against tmux.

State files are written per session to `~/.cache/claude-agents/<session_id>.json`
— readable by dashboard tools.

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
