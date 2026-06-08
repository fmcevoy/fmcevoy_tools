# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository

macOS dev environment bootstrap & management. Not a library — a collection of configs, scripts, and setup automation.

## Key Commands

```bash
# Bootstrap a fresh machine (idempotent, safe to re-run)
cd mac_setup && ./setup.sh

# Preview what setup.sh would do without making changes
./setup.sh --dry-run

# Upgrade all CLI tools
cliup                        # alias for ~/cli-upgrades
cliup --only recon           # single section
cliup --skip brew            # skip a section
cliup --dry-run              # preview only

# Re-apply Kiro tmux fix if a Kiro upgrade breaks the ordering
mac_setup/scripts/fix_kiro_tmux.sh
```

## Structure

- `mac_setup/setup.sh` — 20-step idempotent bootstrap (steps numbered in script and README)
- `mac_setup/cli-upgrades` — unified upgrade manager, symlinked to `~/cli-upgrades`
- `mac_setup/Brewfile` — all Homebrew installs (formulas + casks + taps)
- `mac_setup/configs/` — dotfiles symlinked to `$HOME` by setup.sh step 1
- `mac_setup/configs/claude/` — Claude Code config: `settings.json`, `mcp.json`, `claude-notify.sh`, `claude-session-start.sh`, `claude-agents-register-launcher.sh`, `statusline-command.sh`
- `mac_setup/scripts/` — one-off maintenance scripts
- `.claude/skills/` — local Claude Code skills (e.g., `add-coding-agent`)

## Documentation Sync Rule

When adding or modifying aliases, shell functions, CLI tools, or upgrade sections, update **all five surfaces**:

1. `mac_setup/configs/zshrc` — source of truth for aliases/functions
2. `mac_setup/configs/tmux/help` — the `h` command reference card
3. `mac_setup/cli-upgrades` — header comment section list AND `--help` output AND `capture_all_versions`
4. `mac_setup/README.md` — "What It Does" steps and config tables
5. `mac_setup/setup.sh` — install step in the relevant numbered section

## Adding a New Coding Agent

Use the `/add-coding-agent` skill (`.claude/skills/add-coding-agent/SKILL.md`). It researches install method, runs the binary to capture flags, then wires the agent into all integration points:

| Integration point | What to change |
|---|---|
| `mac_setup/Brewfile` | Add formula/cask if brew-installed |
| `mac_setup/setup.sh` step 14 | Add install block |
| `mac_setup/cli-upgrades` | Add upgrade section + section lists + `capture_all_versions` |
| `mac_setup/configs/zshrc` | Add `<x>ch()` headless alias |
| `mac_setup/configs/completions.zsh` | Add shell completion wiring |
| `mac_setup/configs/tmux/help` | Add alias to reference card |
| `mac_setup/README.md` | Update step 14 agent list |

Headless aliases follow `<letter>ch` pattern: `cch` (claude), `gch` (gemini), `agch` (antigravity), `xch` (codex), `pch` (pi), `kch` (kiro), `dch` (deepseek), `grch` (grok), `mch` (kimi), `och` (opencode).

## Conventions

- **Local overrides** use `.<name>.local` pattern and are never committed. `setup.sh` creates empty stubs or symlinks from `~/fmcevoy/local/` if that private repo exists.
- **Secrets** live in `~/ee` (sourced by zshrc, chmod 600, never committed). See `mac_setup/SECRETS_CHECKLIST.md`.
- **pipx-managed tools** (e.g., Poetry) live in `~/.local/bin` — already first on `$PATH` in zshrc.
- **Poetry** is pinned to v1.x via `uv tool install "poetry>=1,<2"` — never install via Homebrew (brew only ships v2).
- **Claude Code** uses `opusplan` model, auto mode, with Stop/Notification hooks wired to `~/.claude/claude-notify.sh` and a SessionStart hook wired to `~/.claude/claude-session-start.sh`. The SessionStart hook enables tab-lighting for `claude agents` background sessions: it reads a launcher registry written by the `claude()` zshrc wrapper, resolves the originating tmux pane, and writes a `<session_id>.parent_pane` sidecar that `claude-notify.sh` consults at Stop/Notification time. Config lives in `mac_setup/configs/claude/settings.json`.
- **MCP config** lives in `~/.claude/.mcp.json` (copied, not symlinked — secrets injected at setup time). Template is `mac_setup/configs/claude/mcp.json`.
- **Kiro CLI** installs shell hooks that corrupt starship in tmux; the zshrc neutralization block (after the Kiro post block) disables them. If a Kiro upgrade breaks ordering, run `mac_setup/scripts/fix_kiro_tmux.sh`.
