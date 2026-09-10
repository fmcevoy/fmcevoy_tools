# setup.sh — private overlay, dry-run gaps, and config write-back drift

**Date:** 2026-09-10
**Branch:** `claude/reading-comprehension-c7hlcv`
**Commits:** `9b7f512`, `825f17a`, `31c21d6`, `46b0064`
**Companion change:** `fmcevoy/meldr` — see that repo's `docs/handover/2026-09-10-symlinked-settings-json.md`. **Merge the meldr change first** (see [Rollout order](#rollout-order)).

---

## Why

A full `setup.sh` re-run on 2026-09-10 surfaced three separate problems:

1. **The private overlay never ran.** Step 1 links this repo's base configs over paths that `~/fmcevoy/laptop/bootstrap.sh` also owns — `~/.claude/settings.json`, `~/start_tmux_dev` and others. A `setup.sh` run not followed by hand-running the private bootstrap silently reverted the laptop to public defaults.
2. **`--dry-run` was not honoured everywhere.** Several mutating calls ran for real during a dry run.
3. **Writes to `$HOME` were landing in tracked source.** `~/.zshrc` and `~/.claude/settings.json` were symlinks into this repo, so anything that wrote to those paths dirtied a pristine checkout. Both had already happened — a third-party installer appended a block to `~/.zshrc`, and meldr's hook block is visible in this repo's git history inside `configs/claude/settings.json`.

Problem 3 is the one that matters most across several laptops, because every machine was writing back into the same shared base.

---

## What changed

### `9b7f512` — hygiene

| Fix | Where |
|---|---|
| `error()` was called but never defined | `setup.sh` output helpers |
| SC2155 — declare and assign separately | `link_file` |
| SC2088 — tilde does not expand in quotes | Step 20 message |

`error()` is the notable one: it is called twice in the Poetry version check, so under `set -euo pipefail` that failure path aborted with `error: command not found` instead of printing the diagnostic it was written to print.

`shellcheck -S warning mac_setup/setup.sh` is now clean (was 2 warnings).

### `825f17a` — private overlay and `--dry-run`

**Step 21 (new).** Runs `$HOME/fmcevoy/laptop/bootstrap.sh` as the last step when it exists and is executable, passing `--dry-run` through. It warns rather than aborting on failure, warns if the file exists but is not executable, and skips quietly when there is no `~/fmcevoy` — so the script stays fully usable on a machine with no private overlay. It has to be last, because Step 1 links the public base configs over paths the overlay owns.

**Four `--dry-run` gaps closed:**

| Call | Problem |
|---|---|
| `brew bundle` (`--no-upgrade` branch) | ran for real |
| `brew bundle` (plain branch) | ran for real |
| `brew link --force libpq` | ran for real |
| Homebrew installer | `$(curl …)` was evaluated *before* `run()` was ever called, so a dry run still hit the network |

**Pinned Poetry.** `brew uninstall` fails outright on a pinned formula, which under `set -e` aborted the rest of the run. Step 9 now checks `brew list --pinned` first and leaves a pinned Poetry alone with a warning telling you to `brew unpin poetry`.

**All five `curl | bash` installers** (fly, bun, antigravity, devin, grok) ran unguarded, so any one failing took Steps 15-20 with it — antigravity's TLS failure on 2026-09-10 did exactly that. Each now warns and continues.

**`meldr install-hooks`** added to the end of Step 10, so the Claude Code hook matchers stay in step with the binary that was just rebuilt. See [Open items](#open-items) — its position is not yet right.

### `31c21d6` — stop `$HOME` writes reaching tracked source

Two helpers replace `link_file` for the two paths that get written from outside this repo.

**`source_shim`** — for `~/.zshrc`. Writes a three-line real file that `source`s `configs/zshrc`:

```
# Managed by fmcevoy_tools/mac_setup/setup.sh — this file is yours to append to.
# Machine-local settings belong in ~/.zshrc.local, sourced by the file below.
source "/Users/<you>/fmcevoy_tools/mac_setup/configs/zshrc"
```

Installer appends land in the untracked shim, *after* the managed config, so they still take effect. Re-running leaves an existing shim untouched, so nothing appended to it is ever lost. The path derives from `$SCRIPT_DIR`, not a hardcoded home directory. Base changes still propagate, because the shim sources the repo file.

**`seed_file`** — for `~/.claude/settings.json`. Superseded by `merge_json_file` in `46b0064`; see below.

Both migrate an existing symlink by backing it up to `<target>.backup.<timestamp>` first, exactly as `link_file` does, and both honour `--dry-run`.

**The meldr hook block was stripped from `configs/claude/settings.json`.** Hooks are meldr's to install and are machine state, not shared base.

### `46b0064` — merge the settings template rather than seed it

`seed_file` never overwrote an existing file. That kept writes out of tracked source, but across several laptops it meant a change to the managed template would never again reach a machine that already had the file — each laptop would silently freeze at whatever it happened to have.

`merge_json_file` replaces it, using the same approach Step 19 already uses for `mcp.json`:

- **Absent** → copy the template.
- **A symlink** (left by an older `setup.sh`) → materialise into a real file, keeping its content, backing up the link.
- **Then merge**, one level deep: keys the live file lacks are added; keys it already has are left alone. For dict-valued keys, missing sub-keys are added.

One level deep is what makes it useful on a fleet: a newly enabled plugin or marketplace in the template reaches every laptop, without overriding a machine's own choices.

---

## What each laptop sees on its first run after this

1. `~/.zshrc` — the old symlink is backed up to `~/.zshrc.backup.<timestamp>` and replaced by the shim. Nothing is lost: appends made through the symlink went into `configs/zshrc` in the repo (see [Evidence](#evidence)), and the shim still sources that file, so they keep working. From now on new appends land in the shim instead.
2. `~/.claude/settings.json` — the symlink is backed up and materialised with its current content, then the template's missing keys are merged in.
3. That is **two more `.backup.<timestamp>` files per laptop**, on top of the ones already accumulating. Worth a sweep.
4. Step 21 now runs the private bootstrap automatically. It was previously a manual step.

---

## Evidence

The tail of `mac_setup/configs/zshrc` carries the fingerprint of exactly the bug this branch fixes:

```sh
# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<
```

The grok installer appended that to `~/.zshrc`, which was a symlink, so it landed in tracked source and was committed (it rode along in `287f451`). It is benign in itself — `$HOME`-relative, and grok is installed by Step 14 anyway — but note it sits *after* the `~/.zshrc.local` sourcing at lines 263-264, so it takes precedence over a laptop's own `PATH` tweaks. Decide whether to keep it (moved above the local-override sourcing, where managed content belongs) or drop it; either way it should no longer be arriving by accident.

The same fingerprint in `configs/claude/settings.json` was meldr's hook block, removed in `31c21d6`.

---

## Verification

Performed in a Linux container, against a throwaway `$HOME`:

- `bash -n` clean; `shellcheck -S warning` clean.
- `source_shim` and `merge_json_file` unit-tested across: fresh machine, installer-appends-then-rerun, migration from the legacy symlink, a laptop's divergent value plus the base gaining a new key and a new plugin, and `--dry-run`. Appends and local divergence survive; base additions propagate; writes to `$HOME` no longer reach the repo; a dry run leaves the symlink and both trees untouched.
- Full `mac_setup/setup.sh --dry-run` exits 0, prints 70 `[dry-run]` lines, creates **zero** config files in the throwaway `$HOME`, and leaves `git status --short` empty.

### Not verified — do this on a laptop

- **Everything macOS.** The brew paths and `macos_defaults.sh` cannot run in a Linux container. A real `--dry-run` on a laptop, one with `~/fmcevoy` and one without, is still required.
- **The antigravity URL.** The container's proxy returns 403 for that host, so its failure there says nothing about the real endpoint. This is why all five installers were hardened uniformly rather than antigravity being special-cased — the fix does not depend on a fact that could not be checked.
- **`meldr install-hooks` end to end**, since it needs a built meldr and a real `~/.claude`.

### A dry run does still write to `$HOME`, and that is correct

`npm list -g` and `uv tool list` create `~/.npm/_logs` and `~/.cache/uv` as a side effect of running at all. They are read-only detection probes — suppressing them would make the dry-run output useless. So "no new files in `$HOME`" is not a satisfiable criterion; "no new *config* files" is, and it holds.

---

## Open items

**`meldr install-hooks` is in the wrong place.** It runs in Step 10, before Step 21. On any laptop whose private bootstrap re-links `~/.claude/settings.json`, Step 21 replaces the file Step 10 just wrote hooks into, so that work is discarded. Moving the call to after Step 21 is a one-line change and is only safe once the meldr fix has shipped (before that, it would write hooks into `~/fmcevoy` instead).

**`~/.gitconfig` is the same bug class, unfixed.** It is still a symlink into this repo, and `git config --global` and `gh auth setup-git` write straight through it. It needs git's `[include]` mechanism rather than a source shim, so it is a different fix.

**The template's content is one laptop's state.** `enabledPlugins`, `voice`, `theme` and `effortLevel` in `configs/claude/settings.json` got there by write-back from a single machine and are now the shared base for all of them. Worth deciding whether that is the base you want.

**Abandon `setup-runs-private-bootstrap`.** That branch and its commit `0063c5b` exist only on one laptop and were never pushed. The work here re-implements those same three fixes differently and adds more. Delete that branch rather than trying to merge it.

---

## Rollout order

Step 10 installs meldr from `git main`. Until the meldr change merges, every laptop keeps building the binary that resolves the `settings.json` symlink before writing — and on a machine whose overlay re-links that path, it will write hooks into `~/fmcevoy`.

1. Merge `fmcevoy/meldr` `claude/reading-comprehension-c7hlcv`.
2. Then merge this branch.
3. Then re-run `setup.sh` per laptop, `--dry-run` first.
