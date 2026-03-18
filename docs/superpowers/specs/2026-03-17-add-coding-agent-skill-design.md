# Add Coding Agent Skill — Design Spec

## Purpose

A Claude Code skill that automates integrating a new coding agent into the mac_setup environment. Given an agent name (e.g., "add Aider as a coding agent"), the skill researches the agent's CLI, installs it, wires it into all applicable integration points, and verifies everything works.

## Motivation

The mac_setup repo manages 7 coding agents (claude, cursor, gemini, codex, opencode, pi, kiro) across up to 10 integration points per agent. Adding a new agent is mechanical but tedious and error-prone — web docs frequently have incorrect flag names (as discovered with gemini's `--yolo` and codex's `--dangerously-bypass-approvals-and-sandbox`). This skill codifies the process.

## Invocation

- **Who:** User-triggered only
- **Trigger phrases:** "add X as a coding agent", "set up Y agent", "integrate Z CLI into my setup"
- **Skill location:** `~/.claude/skills/add-coding-agent/SKILL.md`

## Two-Phase Design

### Phase 1 — Research & Propose

The skill performs research, then presents a profile for user approval before modifying any files.

**Steps:**

1. **Web search** for the agent — find npm package / brew cask / brew formula, GitHub repo, official docs
2. **Detect install method** from what's found. Agents may use one or more:
   - **npm-only** — `npm install -g @scope/package` (setup.sh Step 13 + npm upgrade in cli-upgrades)
   - **brew cask** — `cask "name"` in Brewfile (upgraded by `brew upgrade --cask --greedy`)
   - **brew formula** — `brew "tap/name"` in Brewfile (upgraded by `brew upgrade`)
   - **Hybrid (brew install + npm upgrade)** — Brewfile for initial install, npm for upgrades (e.g., Claude Code: cask install, `npm install -g` for updates)
   - **Self-updating app** — track version only (e.g., Cursor)
3. **Install the agent** using the detected method
4. **Run `<cmd> --help`** — this is the authoritative source for flags, not web docs
5. **Check for built-in shell completions** — look for `<cmd> completion zsh`, `--get-yargs-completions`, or similar. If found, prefer delegating to the CLI's own completions over hand-parsed `--help` output.
6. **Build agent profile** from `--help` output:
   - CLI command name (e.g., `kiro-cli` vs `kiro`)
   - Install method + package identifier
   - Subcommands (for completions)
   - All flags with short forms and choice values
   - Headless/print mode flag (e.g., `-p`, `--no-interactive`, `exec`) — may be absent
   - Yolo/auto-approval flag (e.g., `--yolo`, `--trust-all-tools`, `--dangerously-bypass-approvals-and-sandbox`) — may be absent
   - Version command (and whether it hangs/needs workaround)
   - Built-in completion support (if found)
7. **Check idempotency** — scan each integration point to see what's already present
8. **Present structured proposal** to user:
   - Agent profile table (command, package, install method, headless syntax, yolo flag)
   - Proposed headless alias (following `<letter>ch` naming pattern) — or note that no headless mode is available
   - Proposed headless command (full syntax)
   - List of files to modify with description of each change, noting any skipped points
   - Warnings (e.g., "no yolo equivalent found — headless alias will omit auto-approval", "no headless mode — skipping alias", "version command hangs")

**The skill stops and waits for user approval before proceeding.**

### Phase 2 — Apply & Verify

After user approves, modify applicable files and verify.

**File modifications (in order):**

Not all agents touch all points. The skill skips integration points that don't apply (e.g., no headless mode = skip zshrc alias and tmux/help entry, npm-only = skip Brewfile, brew-only = skip setup.sh Step 13).

1. **`mac_setup/Brewfile`**
   - Add `cask "name"` or `brew "tap/name"` line in the Casks or appropriate section
   - Skip if npm-only

2. **`mac_setup/setup.sh` (Step 13: Coding agents)**
   - Add npm install check block for npm-based agents
   - Pattern: `if ! npm list -g @scope/pkg &>/dev/null; then ... fi`
   - Skip if brew-managed (handled by Brewfile)

3. **`mac_setup/cli-upgrades`**
   - Add agent name to the `# Sections:` comment line and the `echo "Sections:` help text line (match by pattern, not line number)
   - Add version capture in `capture_all_versions()` function. If `--version` hangs, use `npm list -g` or `brew list --versions` with an explanatory comment
   - Add upgrade section wrapped in `should_run "<name>"` guard:
     - npm agents: `npm install -g @scope/pkg@latest` block (like gemini/codex/pi)
     - brew cask agents: "managed by Homebrew cask (upgraded above)" reporting block (like kiro)
     - brew formula agents: "managed by Homebrew (upgraded above)" reporting block
     - Hybrid agents: npm upgrade block (like claude)
     - Self-updating: version tracking only block (like cursor)

4. **`mac_setup/configs/completions.zsh`**
   - If the CLI provides built-in zsh completions (yargs, `completion zsh`, etc.), use a delegating function like the existing `_opencode_yargs_completions()` pattern
   - Otherwise, add a full `_<cmd>()` zsh completion function built from `--help` output, following the existing `_arguments -s -S` with `->state` dispatch style
   - Add `compdef _<cmd> <cmd>` registration
   - Add agent name to meldr `--agent` completion list in the `create_options` array (match by the `--agent` pattern)

5. **`mac_setup/configs/zshrc`** (skip if no headless mode)
   - Add headless function in the "Headless agents" section
   - Pattern: `<x>ch() { <cmd> <headless-flag> <yolo-flag> "$*"; }`
   - Note: `ch` (cursor) is the only `alias` — all others use functions. New agents should use functions.
   - If no yolo flag exists, omit it from the function (and note this in the Phase 1 proposal)

6. **`mac_setup/configs/tmux/help`** (skip if no headless mode)
   - Add headless alias entry in the Shortcuts section
   - Pattern: `echo -e "  ${GRN}<x>ch${RST}            ${DIM}Headless <name>${RST}"`

7. **`mac_setup/README.md`**
   - Add agent to completions.zsh table row
   - Add agent to Step 13 description

**Verification steps:**

1. `zsh -n` syntax check on `configs/zshrc` and `configs/completions.zsh`
2. `bash -n` syntax check on `cli-upgrades`, `setup.sh`, `configs/tmux/help`
3. Run `<cmd> --version` to confirm the agent is working
4. Print summary table showing all changes made
5. If any verification step fails, fix the issue and re-verify. If unfixable, revert changes to affected files with `git checkout` and report the failure.

## Key Design Decisions

### Headless alias naming

Follows `<letter>ch` pattern (ch, cch, gch, xch, pch, kch). The skill picks the first letter of the agent name, checks for conflicts with existing aliases. If collision: try first two letters. If still collision: ask the user for a custom name. The proposed name is always shown in the Phase 1 profile for user approval.

### Completion function strategy

Prefer CLI-provided completions when available (yargs, `completion zsh`). Fall back to hand-parsed `--help` output using the `_arguments -s -S` pattern. Always use `--help` as the authoritative source for flag names, not web docs.

### Version tracking heuristic

If `<cmd> --version` hangs or outputs to TUI (like claude does), falls back to `npm list -g` or `brew list --versions`. Documents this in the version capture function with a comment.

### Idempotency

If the agent is already partially integrated (e.g., in Brewfile but not completions), the skill detects what's missing and only adds the gaps. Checks each file before modifying.

### `--help` as source of truth

Web docs are used only for discovery (package name, install method). The `--help` output is the authoritative source for all flag names, subcommands, and options. This avoids the incorrect flag names frequently found in web documentation.

### Conditional integration points

Not all agents have headless mode or yolo flags. The skill skips inapplicable points:
- No headless flag → skip zshrc alias, tmux/help entry
- No yolo flag → headless alias omits auto-approval (with a note)
- npm-only → skip Brewfile
- brew-only → skip setup.sh Step 13

### Meldr integration

The skill updates the meldr `--agent` completion list in completions.zsh. If meldr's Rust code needs updating to actually launch the new agent, the skill flags this to the user with guidance on what to add.

## Integration Points Checklist

Up to 10 points per agent. Points marked conditional are skipped when not applicable.

| # | File | What changes | Condition |
|---|------|-------------|-----------|
| 1 | `Brewfile` | `cask` or `brew` line | brew-managed only |
| 2 | `setup.sh` Step 13 | npm install check | npm-managed only |
| 3 | `cli-upgrades` comments | Section name in `# Sections:` comment + help text | always |
| 4 | `cli-upgrades` versions | `capture_all_versions()` entry | always |
| 5 | `cli-upgrades` upgrade | Upgrade/tracking section with `should_run` guard | always |
| 6 | `completions.zsh` function | Completion function (hand-parsed or delegated) | always |
| 7 | `completions.zsh` meldr | Agent name in `--agent` choices | always |
| 8 | `zshrc` | Headless alias function | has headless mode |
| 9 | `tmux/help` | Headless alias documentation | has headless mode |
| 10 | `README.md` | Completions table + Step 13 description | always |

## Current Agent Inventory

| Agent | CLI cmd | Install | Headless | Yolo flag | Alias |
|-------|---------|---------|----------|-----------|-------|
| Claude | `claude` | hybrid (brew cask + npm upgrade) | `-p` | `--dangerously-skip-permissions` | `cch` |
| Cursor | `cursor agent` | app (auto-updates) | `-p` | `--force` | `ch` |
| Gemini | `gemini` | npm `@google/gemini-cli` | `-p` | `-y` / `--yolo` | `gch` |
| Codex | `codex` | npm `@openai/codex` | `exec` | `--dangerously-bypass-approvals-and-sandbox` | `xch` |
| OpenCode | `opencode` | brew `anomalyco/tap/opencode` | — | — | — |
| Pi | `pi` | npm `@mariozechner/pi-coding-agent` | `-p` | (none by design) | `pch` |
| Kiro | `kiro-cli` | brew cask `kiro-cli` | `chat --no-interactive` | `--trust-all-tools` | `kch` |
