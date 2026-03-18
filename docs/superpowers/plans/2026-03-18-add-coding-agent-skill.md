# Add Coding Agent Skill — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Claude Code skill at `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md` that automates integrating new coding agents into the mac_setup environment.

**Architecture:** Single SKILL.md file with YAML frontmatter and structured instructions. The skill guides Claude through a two-phase process: (1) research the agent's CLI and propose an integration plan, (2) apply changes to all mac_setup files and verify. No bundled resources needed — the skill uses web search and `--help` output at runtime.

**Tech Stack:** Claude Code skill (Markdown), zsh, bash

**Spec:** `docs/superpowers/specs/2026-03-17-add-coding-agent-skill-design.md`

---

## File Structure

| Action | File | Purpose |
|--------|------|---------|
| Create | `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md` | The skill itself |
| Verify | `mac_setup/Brewfile` | Confirm skill can find the Casks section |
| Verify | `mac_setup/setup.sh` | Confirm skill can find Step 13 block |
| Verify | `mac_setup/cli-upgrades` | Confirm skill can find `# Sections:`, `capture_all_versions`, `should_run` patterns |
| Verify | `mac_setup/configs/completions.zsh` | Confirm skill can find meldr `--agent` list and completion function insertion point |
| Verify | `mac_setup/configs/zshrc` | Confirm skill can find "Headless agents" section |
| Verify | `mac_setup/configs/tmux/help` | Confirm skill can find headless alias section |
| Verify | `mac_setup/README.md` | Confirm skill can find completions table and Step 13 line |

---

## Chunk 1: Write the SKILL.md

### Task 1: Create SKILL.md with frontmatter and overview

**Files:**
- Create: `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p ~/fmcevoy_tools/.claude/skills/add-coding-agent
```

- [ ] **Step 2: Write the SKILL.md frontmatter and overview section**

Write the file with:
- YAML frontmatter: `name: add-coding-agent`, `description` that triggers on "add X as a coding agent", "set up Y agent", "integrate Z CLI"
- Overview paragraph explaining what the skill does
- Pointer to the spec doc for full context

The description must be specific enough to trigger reliably. Model it after existing skills like `finish-up`.

```markdown
---
name: add-coding-agent
description: Use when the user asks to add a new coding agent to their dev environment. Triggers on "add X as a coding agent", "set up Y agent", "integrate Z CLI into my setup". Handles research, install, completions, aliases, and upgrade integration.
---

# Add Coding Agent

Integrate a new coding agent into the mac_setup environment. The skill researches the agent's CLI, installs it, wires it into all integration points (Brewfile, setup.sh, cli-upgrades, completions, aliases, help, README), and verifies everything works.

**Spec:** `~/fmcevoy_tools/docs/superpowers/specs/2026-03-17-add-coding-agent-skill-design.md`
```

- [ ] **Step 3: Verify the file exists and frontmatter parses**

```bash
head -5 ~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md
```

Expected: the YAML frontmatter block.

---

### Task 2: Write Phase 1 — Research & Propose

**Files:**
- Modify: `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md`

- [ ] **Step 1: Write the Phase 1 instructions**

Append the Phase 1 section to SKILL.md. This section tells Claude exactly what to do when the skill triggers. It must include:

1. **Research steps** with explicit tool usage:
   - Use `WebSearch` to find the agent's npm package / brew cask / GitHub repo
   - Detect install method (npm, brew cask, brew formula, hybrid, self-updating)
   - Install the agent using the detected method
   - Run `<cmd> --help` and capture the full output — this is the authoritative source for flags
   - Check for built-in shell completions (`<cmd> completion zsh`, `--get-yargs-completions`)

2. **Profile building** from `--help` output:
   - CLI command name
   - Install method + package identifier
   - Subcommands list
   - All flags with short forms and choice values
   - Headless/print mode flag (may be absent)
   - Yolo/auto-approval flag (may be absent)
   - Version command behavior (hangs? needs workaround?)
   - Built-in completion support

3. **Idempotency check** — scan each of these files for existing references to the agent:
   - `~/fmcevoy_tools/mac_setup/Brewfile`
   - `~/fmcevoy_tools/mac_setup/setup.sh`
   - `~/fmcevoy_tools/mac_setup/cli-upgrades`
   - `~/fmcevoy_tools/mac_setup/configs/completions.zsh`
   - `~/fmcevoy_tools/mac_setup/configs/zshrc`
   - `~/fmcevoy_tools/mac_setup/configs/tmux/help`
   - `~/fmcevoy_tools/mac_setup/README.md`

4. **Headless alias naming** — propose `<first-letter>ch`, check for conflicts with existing aliases (ch, cch, gch, xch, pch, kch). If collision: try first two letters. If still collision: ask user.

5. **Present proposal** to user as a structured table:
   - Agent profile (command, package, install method, headless syntax, yolo flag)
   - Proposed headless alias + full command
   - List of files to modify with what changes, noting any skipped points
   - Warnings (no yolo, no headless, version hangs, etc.)

6. **Hard gate** — STOP and WAIT for user approval. Do not proceed to Phase 2 without explicit approval.

The instructions should reference the current agent inventory table from the spec so Claude can see existing patterns.

- [ ] **Step 2: Include the current agent inventory as a reference table in the skill**

Embed this directly in SKILL.md so Claude has it in context:

```markdown
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
```

---

### Task 3: Write Phase 2 — Apply & Verify

**Files:**
- Modify: `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md`

- [ ] **Step 1: Write the file modification instructions**

Append Phase 2 to SKILL.md. For each integration point, provide:
- The exact file path (`~/fmcevoy_tools/mac_setup/...`)
- The pattern to search for (anchor point in the file)
- What to add and where
- When to skip (conditional logic)

The 7 file modifications in order:

**1. Brewfile** (skip if npm-only)
- Anchor: the `# Casks` section or existing `cask` lines
- Add: `cask "<name>"` or `brew "<tap/name>"` in the appropriate section

**2. setup.sh Step 13** (skip if brew-managed)
- Anchor: the "Step 13: Coding agents" block, find the last `fi` before `else` / `echo ""`
- Add: npm install check block following the existing pattern

**3. cli-upgrades** (always)
- Anchor 1: line starting with `#           tpm, nvim,` — append agent name
- Anchor 2: `echo "Sections:` line — append agent name
- Anchor 3: inside `capture_all_versions()` function, before the closing `}`
- Anchor 4: after an existing agent upgrade section (e.g., after the Pi section for npm agents, after the Kiro section for brew agents)
- Wrap in `should_run "<name>"` guard

**4. completions.zsh** (always)
- Anchor 1: before the `# opencode` comment block — insert new completion function
- Anchor 2: the `--agent` line in meldr `create_options` — add agent name before `none)`
- If CLI has built-in completions, use yargs-style delegation. Otherwise build from `--help`.

**5. zshrc** (skip if no headless mode)
- Anchor: the last headless function (currently `kch`)
- Add: new function following the pattern

**6. tmux/help** (skip if no headless mode)
- Anchor: the last `Headless` echo line (currently `kch`)
- Add: new echo line following the pattern

**7. README.md** (always)
- Anchor 1: the `completions.zsh` row in the Shell Completions table — append agent name
- Anchor 2: the Step 13 description line — append agent name

- [ ] **Step 2: Write the verification instructions**

Append verification section:

```markdown
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
| ... | ... | done / skipped / failed |
```

---

### Task 4: Review and finalize the skill

**Files:**
- Modify: `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md`

- [ ] **Step 1: Read the complete SKILL.md end-to-end**

Read the entire file and check:
- Frontmatter is valid YAML
- All file paths are absolute (using `~/fmcevoy_tools/mac_setup/...`)
- All anchor patterns actually exist in the target files (grep for them)
- No hardcoded line numbers
- Phase 1 has an explicit STOP gate before Phase 2
- Phase 2 covers all 7 files with conditional skip logic
- Verification section is complete

- [ ] **Step 2: Verify anchor patterns exist in target files**

```bash
grep '# Sections:' ~/fmcevoy_tools/mac_setup/cli-upgrades
grep 'capture_all_versions' ~/fmcevoy_tools/mac_setup/cli-upgrades
grep 'should_run' ~/fmcevoy_tools/mac_setup/cli-upgrades | head -3
grep 'Step 13' ~/fmcevoy_tools/mac_setup/setup.sh
grep '\-\-agent.*agent:' ~/fmcevoy_tools/mac_setup/configs/completions.zsh
grep 'Headless agents' ~/fmcevoy_tools/mac_setup/configs/zshrc
grep 'Headless' ~/fmcevoy_tools/mac_setup/configs/tmux/help | tail -3
grep 'completions.zsh' ~/fmcevoy_tools/mac_setup/README.md
```

All must return matches.

- [ ] **Step 3: Test the skill triggers**

Verify the skill appears in the skill list by checking `~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md` exists with valid frontmatter.

- [ ] **Step 4: Commit**

```bash
git add ~/fmcevoy_tools/.claude/skills/add-coding-agent/SKILL.md
git add ~/fmcevoy_tools/docs/superpowers/specs/2026-03-17-add-coding-agent-skill-design.md
git add ~/fmcevoy_tools/docs/superpowers/plans/2026-03-18-add-coding-agent-skill.md
git commit -m "feat: add-coding-agent skill for automating agent integration

Two-phase skill: research agent CLI via web + --help, then apply
changes to Brewfile, setup.sh, cli-upgrades, completions, zshrc,
help card, and README with verification.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```
