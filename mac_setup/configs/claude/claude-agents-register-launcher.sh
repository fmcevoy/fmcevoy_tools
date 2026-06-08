#!/usr/bin/env bash
# Write a launcher-registry entry so claude-session-start.sh can associate
# a new 'claude agents' background session with the tmux pane that opened it.
# Called from the zshrc claude() wrapper when the 'agents' subcommand is used.
PANE="${TMUX_PANE:-}"
[ -z "$PANE" ] && exit 0  # not in tmux — nothing to register

WIN=$(tmux display-message -p '#{window_id}' 2>/dev/null || true)

DIR="$HOME/.cache/claude-agents/launchers"
mkdir -p "$DIR"

TS=$(( $(date +%s) * 1000 ))
TMP=$(mktemp "$DIR/.launcher-XXXXXX")
printf '{"pane":"%s","window":"%s","cwd":"%s","ts":%s}\n' \
  "$PANE" "$WIN" "$PWD" "$TS" > "$TMP" && mv -f "$TMP" "$DIR/${TS}-$$.json" || rm -f "$TMP"

# Prune entries older than 24 hours
find "$DIR" -name '*.json' -mtime +1 -delete 2>/dev/null || true
