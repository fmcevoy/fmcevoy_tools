#!/usr/bin/env bash
# fix_kiro_tmux.sh - Re-apply Kiro CLI tmux neutralization block to ~/.zshrc
#
# Kiro CLI (ex-Fig/Amazon Q) rewrites ~/.zprofile and ~/.zshrc on every upgrade,
# re-inserting its own shell integration blocks. Those blocks install
# fig_precmd/fig_preexec hooks that wrap PS1 with OSC 697 sequences, which
# conflict with starship during tmux pane SIGWINCH events — causing cursor
# corruption and '%' partial-line markers.
#
# We maintain a neutralization block at the END of ~/.zshrc that strips those
# hooks inside tmux. If a Kiro upgrade re-appends its block BELOW ours, this
# script detects the situation, removes both copies, and re-appends ours last.
#
# Usage: just run ~/fmcevoy_tools/mac_setup/scripts/fix_kiro_tmux.sh
# ============================================================

set -euo pipefail

ZSHRC="$HOME/.zshrc"
MARKER="# Kiro CLI tmux neutralization (MUST be after Kiro's post blocks above)"
KIRO_MARKER="# Kiro CLI post block. Keep at the bottom of this file."

if [[ ! -f "$ZSHRC" ]]; then
  echo "ERROR: $ZSHRC not found" >&2
  exit 1
fi

# Check whether Kiro's block is AFTER our neutralization (the bad state)
our_line=$(grep -n "$MARKER" "$ZSHRC" | tail -1 | cut -d: -f1 || true)
kiro_line=$(grep -n "$KIRO_MARKER" "$ZSHRC" | tail -1 | cut -d: -f1 || true)

if [[ -z "$our_line" ]]; then
  echo "Neutralization block not found — your ~/.zshrc is missing the fix."
  echo "Add the block manually or re-apply from fmcevoy_tools."
  exit 1
fi

if [[ -n "$kiro_line" && "$kiro_line" -gt "$our_line" ]]; then
  echo "Kiro block is below our neutralization — re-ordering..."

  # Back up first
  cp "$ZSHRC" "$ZSHRC.bak.$(date +%Y%m%d%H%M%S)"

  # Extract our neutralization block (from "# ===" banner preceding MARKER to the next `fi`)
  tmp=$(mktemp)
  awk -v marker="$MARKER" '
    # Start capture when we see the header banner that contains MARKER
    /^# ====/ && !capturing { banner_line=NR; banner=$0 "\n" }
    index($0, marker) { capturing=1; print banner; banner=""; next }
    capturing { print }
    capturing && /^fi$/ { exit }
  ' "$ZSHRC" > "$tmp"

  if [[ ! -s "$tmp" ]]; then
    echo "ERROR: could not extract neutralization block" >&2
    rm -f "$tmp"
    exit 1
  fi

  # Remove all occurrences of our block from the file, then append our block at the end
  python3 - "$ZSHRC" "$tmp" <<'PY'
import sys, pathlib
zshrc_path, block_path = sys.argv[1], sys.argv[2]
zshrc = pathlib.Path(zshrc_path).read_text()
block = pathlib.Path(block_path).read_text().rstrip() + "\n"
# Remove the neutralization block wherever it appears.
# Identify its header banner + body (ends at first `fi` line).
marker = "# Kiro CLI tmux neutralization (MUST be after Kiro's post blocks above)"
lines = zshrc.splitlines(keepends=True)
out, skipping = [], False
for i, line in enumerate(lines):
    if not skipping and line.rstrip().startswith("# ===="):
        # Peek ahead for marker within next 3 lines
        if any(marker in lines[j] for j in range(i, min(i + 4, len(lines)))):
            skipping = True
            continue
    if skipping:
        if line.strip() == "fi":
            skipping = False
        continue
    out.append(line)
cleaned = "".join(out).rstrip() + "\n\n" + block
pathlib.Path(zshrc_path).write_text(cleaned)
PY

  rm -f "$tmp"
  echo "Fixed. Open a new shell to verify."
else
  echo "Neutralization is correctly placed at the end of ~/.zshrc — nothing to do."
fi
