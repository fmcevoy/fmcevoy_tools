#!/usr/bin/env bash
# SessionStart hook — resolve which tmux pane owns this new background session
# and write ~/.cache/claude-agents/<session_id>.parent_pane so claude-notify.sh
# can flash the correct tab when the session stops or needs input.
STATE_DIR="$HOME/.cache/claude-agents"
LAUNCHER_DIR="$STATE_DIR/launchers"

HOOK_DATA=$(cat)
SESSION_ID=$(printf '%s' "$HOOK_DATA" | jq -r '.session_id // ""' 2>/dev/null)
SESSION_CWD=$(printf '%s' "$HOOK_DATA" | jq -r '.cwd // ""' 2>/dev/null)

[ -z "$SESSION_ID" ] && exit 0

# Path 1: env var set (foreground session or env survived the daemon spawn)
PANE_ID="${MELDR_TMUX_PANE:-}"

# Path 2: most-recent launcher whose cwd is a prefix of session cwd
# Path 3: most-recent launcher unconditionally (last-resort)
if [ -z "$PANE_ID" ] && [ -d "$LAUNCHER_DIR" ]; then
  BEST_PANE=""
  BEST_TS=-1
  FALLBACK_PANE=""
  FALLBACK_TS=-1

  while IFS= read -r FILE; do
    [ -f "$FILE" ] || continue
    ENTRY=$(jq -r '.' "$FILE" 2>/dev/null) || continue
    LPANE=$(printf '%s' "$ENTRY" | jq -r '.pane // ""' 2>/dev/null)
    LDIR=$(printf '%s' "$ENTRY" | jq -r '.cwd // ""' 2>/dev/null)
    LTS=$(printf '%s' "$ENTRY" | jq -r '.ts // 0' 2>/dev/null)
    [ -z "$LPANE" ] && continue

    # Track global most-recent as unconditional fallback
    if [ "$LTS" -gt "$FALLBACK_TS" ] 2>/dev/null; then
      FALLBACK_PANE="$LPANE"
      FALLBACK_TS="$LTS"
    fi

    # Prefer the most-recent entry whose cwd is a path-prefix of session cwd
    [ -z "$LDIR" ] && continue
    if [ "${SESSION_CWD#"$LDIR"}" != "$SESSION_CWD" ] || [ "$SESSION_CWD" = "$LDIR" ]; then
      if [ "$LTS" -gt "$BEST_TS" ] 2>/dev/null; then
        BEST_PANE="$LPANE"
        BEST_TS="$LTS"
      fi
    fi
  done < <(find "$LAUNCHER_DIR" -name '*.json' -not -empty 2>/dev/null)

  PANE_ID="${BEST_PANE:-$FALLBACK_PANE}"
fi

# Write the sidecar keyed by Claude's session UUID
if [ -n "$PANE_ID" ]; then
  mkdir -p "$STATE_DIR"
  printf '%s' "$PANE_ID" > "$STATE_DIR/${SESSION_ID}.parent_pane"
fi

exit 0
