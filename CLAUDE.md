# CLAUDE.md

## Repository
macOS dev environment bootstrap & management. Not a library — a collection of configs, scripts, and setup automation.

## Structure
- `mac_setup/setup.sh` — 19-step idempotent bootstrap
- `mac_setup/cli-upgrades` — unified tool upgrade manager (symlinked to `~/cli-upgrades`)
- `mac_setup/configs/` — dotfiles symlinked to `$HOME`
- `mac_setup/README.md` — setup documentation
- `.claude/skills/` — Claude Code skills

## Documentation Sync Rule
When adding/modifying aliases, shell functions, CLI tools, or upgrade sections, update ALL surfaces:
1. `mac_setup/configs/zshrc` — source of truth for aliases/functions
2. `mac_setup/configs/tmux/help` — the `h` command reference card
3. `mac_setup/cli-upgrades` — header comment AND `--help` output section lists
4. `mac_setup/README.md` — setup steps and tables

## Conventions
- Headless agent aliases follow `<letter>ch` pattern (cch, gch, xch, pch, kch)
- Shell completions go in `mac_setup/configs/completions.zsh`
- Local overrides use `.<name>.local` pattern, never committed
- Poetry pinned to v1.x (not brew's v2)
- Claude Code uses native installer, not npm
