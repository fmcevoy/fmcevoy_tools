---
name: add-coding-agent
description: Use when the user asks to add a new coding agent to their dev environment. Triggers on "add X as a coding agent", "set up Y agent", "integrate Z CLI into my setup". Handles research, install, completions, aliases, and upgrade integration.
---

# Add Coding Agent

Integrate a new coding agent into the mac_setup environment. The skill researches the agent's CLI, installs it, wires it into all integration points (Brewfile, setup.sh, cli-upgrades, completions, aliases, help, README), and verifies everything works.

**Spec:** `~/fmcevoy_tools/docs/superpowers/specs/2026-03-17-add-coding-agent-skill-design.md`

---

## Phase 1 — Research & Propose

### Step 1: Research the agent

1. Use `WebSearch` to find the agent's npm package, brew cask, brew formula, or GitHub repo. Search for `"<agent-name> CLI install"`, `"<agent-name> coding agent npm"`, and `"<agent-name> brew install"`.
2. Detect the install method from what you find. Agents use one of:
   - **npm-only** — `npm install -g @scope/package` (setup.sh Step 13 + npm upgrade in cli-upgrades)
   - **brew cask** — `cask "name"` in Brewfile (upgraded by `brew upgrade --cask --greedy`)
   - **brew formula** — `brew "tap/name"` in Brewfile (upgraded by `brew upgrade`)
   - **Hybrid (brew install + npm upgrade)** — Brewfile for initial install, npm for upgrades (e.g., Claude Code: cask install, `npm install -g` for updates)
   - **Self-updating app** — track version only (e.g., Cursor)
3. Install the agent using the detected method.
4. Run `<cmd> --help` and capture the **full output**. This is the authoritative source for flags — do NOT rely on web docs for flag names.
5. Check for built-in shell completions. Try these in order:
   - `<cmd> completion zsh`
   - `<cmd> --get-yargs-completions`
   - `<cmd> completions zsh`
   - Look for mention of completions in `--help` output

### Step 2: Build agent profile

Extract the following from the `--help` output:

| Field | How to find it |
|-------|---------------|
| CLI command name | The binary name (e.g., `kiro-cli` vs `kiro`) |
| Install method + package ID | From Step 1 research |
| Subcommands | Listed under "Commands:" or similar heading in `--help` |
| All flags | Listed under "Options:" — capture short forms (`-p`) and choice values |
| Headless/print mode flag | Look for `-p`, `--print`, `--no-interactive`, `exec` subcommand, or similar |
| Yolo/auto-approval flag | Look for `--yolo`, `--trust-all-tools`, `--dangerously-*`, `--force`, `-y` (in agent context) |
| Version command | Run `<cmd> --version`. Note if it hangs or needs a workaround |
| Built-in completions | From Step 1.5 above |

### Step 3: Idempotency check

Scan each of these files for existing references to the agent name or CLI command. Record what is already present and what is missing.

- `~/fmcevoy_tools/mac_setup/Brewfile`
- `~/fmcevoy_tools/mac_setup/setup.sh`
- `~/fmcevoy_tools/mac_setup/cli-upgrades`
- `~/fmcevoy_tools/mac_setup/configs/completions.zsh`
- `~/fmcevoy_tools/mac_setup/configs/zshrc`
- `~/fmcevoy_tools/mac_setup/configs/tmux/help`
- `~/fmcevoy_tools/mac_setup/README.md`

If the agent is already partially integrated, only add the missing pieces.

### Step 4: Headless alias naming

If the agent has a headless mode, propose an alias following the `<first-letter>ch` pattern:

1. Take the first letter of the agent name and form `<letter>ch`.
2. Check for conflicts against existing aliases: `ch`, `cch`, `gch`, `xch`, `pch`, `kch`.
3. If collision: try first two letters (e.g., `aich` for "aider").
4. If still collision: ask the user.

If the agent has no headless mode, skip alias creation entirely.

### Step 5: Present proposal

Present a structured proposal to the user. Format it exactly like this:

```
### Agent Profile

| Field | Value |
|-------|-------|
| CLI command | `<cmd>` |
| Package | `<package-identifier>` |
| Install method | <method> |
| Headless flag | `<flag>` or (none) |
| Yolo flag | `<flag>` or (none) |
| Proposed alias | `<x>ch` → `<full command>` |

### Planned File Changes

| # | File | Change | Status |
|---|------|--------|--------|
| 1 | Brewfile | Add `cask "<name>"` | planned / skip (npm-only) |
| 2 | setup.sh Step 13 | Add npm install block | planned / skip (brew-managed) |
| 3 | cli-upgrades | Add to comments, versions, upgrade section | planned |
| 4 | completions.zsh | Add completion function + meldr --agent | planned |
| 5 | zshrc | Add headless function `<x>ch` | planned / skip (no headless) |
| 6 | tmux/help | Add headless alias line | planned / skip (no headless) |
| 7 | README.md | Update completions table + Step 13 | planned |

### Warnings
- <any issues: no yolo flag, no headless mode, version hangs, etc.>
```

### Step 6: HARD GATE

**STOP. Do NOT proceed to Phase 2.** Wait for the user to explicitly approve the proposal. If they request changes, update the proposal and present it again. Only proceed when you receive clear approval (e.g., "looks good", "approved", "go ahead").

## Current Agent Inventory (reference)

| Agent | CLI cmd | Install | Headless | Yolo flag | Alias |
|-------|---------|---------|----------|-----------|-------|
| Claude | `claude` | hybrid (brew cask + npm) | `-p` | `--dangerously-skip-permissions` | `cch` |
| Cursor | `cursor agent` | app (auto-updates) | `-p` | `--force` | `ch` |
| Gemini | `gemini` | npm `@google/gemini-cli` | `-p` | `-y` / `--yolo` | `gch` |
| Codex | `codex` | npm `@openai/codex` | `exec` | `--dangerously-bypass-approvals-and-sandbox` | `xch` |
| OpenCode | `opencode` | brew `anomalyco/tap/opencode` | — | — | — |
| Pi | `pi` | npm `@mariozechner/pi-coding-agent` | `-p` | (none) | `pch` |
| Kiro | `kiro-cli` | brew cask `kiro-cli` | `chat --no-interactive` | `--trust-all-tools` | `kch` |

---

## Phase 2 — Apply & Verify

Only proceed here after user approval of the Phase 1 proposal. Apply each modification in order, skipping inapplicable ones.

### Modification 1: Brewfile

**File:** `~/fmcevoy_tools/mac_setup/Brewfile`
**Skip if:** npm-only install method.

- For brew cask: search for the `# Casks` section or the last existing `cask` line. Add `cask "<name>"` in alphabetical order among existing casks.
- For brew formula with tap: search for existing `brew "tap/name"` lines. Add `brew "<tap/name>"` in the appropriate section.
- For brew formula without tap: search for existing `brew` lines. Add `brew "<name>"` in alphabetical order.

### Modification 2: setup.sh Step 13

**File:** `~/fmcevoy_tools/mac_setup/setup.sh`
**Skip if:** brew-managed (handled by Brewfile).

- Search for the `Step 13` or `Coding agents` block.
- Find the last `fi` before the `else` / `echo ""` that closes the Step 13 block.
- Insert a new npm install check block following the existing pattern:

```bash
  # <Agent Name>
  if ! npm list -g <package-name> &>/dev/null; then
    info "Installing <Agent Name>..."
    run npm install -g <package-name>
    ok "<Agent Name> installed"
  else
    ok "<Agent Name> already installed"
  fi
```

### Modification 3: cli-upgrades

**File:** `~/fmcevoy_tools/mac_setup/cli-upgrades`
**Skip if:** never — always apply.

Make 4 changes in this file:

**3a. Comment header** — Find the line starting with `#           tpm, nvim,` (or the last line of the `# Sections:` comment block listing agent names). Append the new agent name to this list, maintaining the comma-separated format.

**3b. Help text** — Find the `echo "Sections:` line. Append the agent name to the list inside the echo string.

**3c. Version capture** — Find the `capture_all_versions()` function. Before its closing `}`, add a version capture line using the `versions_ref` associative array and `safe_version` helper:
- If `<cmd> --version` works normally: `command -v <cmd> &>/dev/null && versions_ref[<name>]="$(safe_version '<cmd> --version')"`
- If `<cmd> --version` hangs: use `command -v npm &>/dev/null && versions_ref[<name>]="$(safe_version \"npm list -g <package> 2>/dev/null | grep <package> | sed 's/.*@//'\")"`  with an explanatory comment (see the `claude` entry as an example).

**3d. Upgrade section** — Find the `# Kiro CLI` comment block for brew agents, or the `# Pi coding agent` section for npm agents. Insert the new section immediately after the closing `fi` of that block. Use the `section`, `dim`, and `ok` helper functions (not raw `echo`):

For **npm agents** (pattern matches Gemini/Codex/Pi sections):
```bash
# ---------------------------------------------------------------------------
# <Name> (npm global)
# ---------------------------------------------------------------------------
if should_run "<name>" && command -v npm &>/dev/null; then
  section "<Name>"
  if npm list -g <package> &>/dev/null; then
    npm install -g <package>@latest
    ok "<Name> done"
  else
    skip "<name> not installed globally"
  fi
elif should_run "<name>"; then
  skip "npm not found (needed for <name>)"
fi
```

For **brew cask agents** (pattern matches Kiro section):
```bash
# ---------------------------------------------------------------------------
# <Name> (brew cask — upgraded in Homebrew section above)
# ---------------------------------------------------------------------------
if should_run "<name>" && command -v <cmd> &>/dev/null; then
  section "<Name>"
  dim "<Name> is managed by Homebrew cask (upgraded above)"
  dim "$(<cmd> --version | head -1)"
  ok "<Name> done"
fi
```

For **brew formula agents** (pattern matches Go/OpenCode sections):
```bash
# ---------------------------------------------------------------------------
# <Name> (brew — upgraded in Homebrew section above)
# ---------------------------------------------------------------------------
if should_run "<name>" && command -v <cmd> &>/dev/null; then
  section "<Name>"
  dim "<Name> is managed by Homebrew (upgraded above)"
  dim "$(<cmd> --version | head -1)"
  ok "<Name> done"
fi
```

For **hybrid agents** (pattern matches Claude Code section):
```bash
# ---------------------------------------------------------------------------
# <Name> (brew cask + npm upgrade)
# ---------------------------------------------------------------------------
if should_run "<name>" && command -v npm &>/dev/null; then
  section "<Name>"
  npm install -g <package>@latest
  ok "<Name> done"
elif should_run "<name>"; then
  skip "npm not found (needed for <name>)"
fi
```

For **self-updating agents** (pattern matches Cursor section):
```bash
# ---------------------------------------------------------------------------
# <Name> (auto-updates itself, just report version)
# ---------------------------------------------------------------------------
if should_run "<name>" && command -v <cmd> &>/dev/null; then
  section "<Name>"
  dim "<Name> auto-updates via the app — version tracked for reference"
  dim "$(<cmd> --version | head -1)"
  ok "<Name> done"
fi
```

### Modification 4: completions.zsh

**File:** `~/fmcevoy_tools/mac_setup/configs/completions.zsh`
**Skip if:** never — always apply.

Make 2 changes:

**4a. Completion function** — Find the `# opencode` comment block (or the last completion function). Insert the new completion function before it (to maintain rough alphabetical order) or after the last function.

- If the CLI has built-in yargs completions, create a delegating function:
```zsh
# <name>
_<cmd>_yargs_completions() {
    local curcontext="$curcontext" state line
    local completions
    completions=$(<cmd> --get-yargs-completions "${words[@]:1}" 2>/dev/null)
    local -a comp_array
    comp_array=("${(@f)completions}")
    compadd -a comp_array
}
compdef _<cmd>_yargs_completions <cmd>
```

- If the CLI has `completion zsh` output, capture it and use it directly.

- Otherwise, build a full completion function from `--help` output using the `_arguments -s -S` pattern with `->state` dispatch:
```zsh
# <name>
_<cmd>() {
    local curcontext="$curcontext" state line
    _arguments -s -S \
        '(-h --help)'{-h,--help}'[Show help]' \
        '(-v --version)'{-v,--version}'[Show version]' \
        # ... all flags from --help ...
        '*::command:->command'

    case $state in
        command)
            local -a commands
            commands=(
                'sub1:Description 1'
                'sub2:Description 2'
            )
            _describe 'command' commands
            ;;
    esac
}
compdef _<cmd> <cmd>
```

**4b. Meldr agent list** — Search for the `--agent` line inside the `create_options` array. Find the pattern `agent:(claude cursor gemini codex opencode pi kiro none)`. Add the new agent name before `none` in this space-separated list.

### Modification 5: zshrc

**File:** `~/fmcevoy_tools/mac_setup/configs/zshrc`
**Skip if:** the agent has no headless mode.

- Search for the last headless function (currently `kch`).
- Add the new function after it, following the pattern:

```zsh
<x>ch() { <cmd> <headless-flag> <yolo-flag> "$*"; }
```

- If the agent has no yolo flag, omit it: `<x>ch() { <cmd> <headless-flag> "$*"; }`
- Always use a function, not an alias (`ch` for cursor is the only alias — all new agents use functions).

### Modification 6: tmux/help

**File:** `~/fmcevoy_tools/mac_setup/configs/tmux/help`
**Skip if:** the agent has no headless mode.

- Search for the last `Headless` echo line (currently the `kch` line).
- Add a new echo line after it following the pattern:

```bash
echo -e "  ${GRN}<x>ch${RST}            ${DIM}Headless <Agent Name>${RST}"
```

- Match the spacing/alignment of existing entries.

### Modification 7: README.md

**File:** `~/fmcevoy_tools/mac_setup/README.md`
**Skip if:** never — always apply.

Make 2 changes:

**7a. Completions table** — Search for the `completions.zsh` row in the Shell Completions table (or similar table listing which agents have completions). Append the new agent name to the list.

**7b. Step 13 description** — Search for the Step 13 description line that lists coding agents. Append the new agent name to the list.

---

## Verification

After all modifications, run these checks:

1. `zsh -n ~/fmcevoy_tools/mac_setup/configs/zshrc`
2. `zsh -n ~/fmcevoy_tools/mac_setup/configs/completions.zsh`
3. `bash -n ~/fmcevoy_tools/mac_setup/cli-upgrades`
4. `bash -n ~/fmcevoy_tools/mac_setup/setup.sh`
5. `bash -n ~/fmcevoy_tools/mac_setup/configs/tmux/help`
6. `<cmd> --version` — confirm the agent runs

All must pass. If any syntax check fails, fix the issue and re-check. If unfixable, revert with `git checkout` on the affected file and report the failure.

Print a summary table:

| File | Change | Status |
|------|--------|--------|
| Brewfile | Added `cask "<name>"` | done / skipped / failed |
| setup.sh | Added npm install block | done / skipped / failed |
| cli-upgrades | Added comments, version capture, upgrade section | done / skipped / failed |
| completions.zsh | Added completion function + meldr agent | done / skipped / failed |
| zshrc | Added `<x>ch` headless function | done / skipped / failed |
| tmux/help | Added headless alias line | done / skipped / failed |
| README.md | Updated completions table + Step 13 | done / skipped / failed |
| Syntax checks | zsh -n, bash -n | pass / fail |
| Agent runs | `<cmd> --version` | pass / fail |
