#!/usr/bin/env bash
# claude-notify.sh — Claude Code hook script for Stop and Notification events.
# Wired via settings.json hooks: Stop → "stop", Notification → "notify"
#
# On each event:
#   - Plays a distinct sound (afplay, backgrounded so hook doesn't block)
#   - Sets @cc_status on the tmux window so the tab flashes (format conditionals in tmux.conf)
#   - Writes ~/.cache/claude-agents/<session_id>.json for dashboard tools (recon, etc.)

EVENT="${1:-stop}"
STATE_DIR="$HOME/.cache/claude-agents"
mkdir -p "$STATE_DIR"

# Read hook JSON from stdin
HOOK_DATA=$(cat)

# Skip subagent events only — not every event that happens to carry agent_id.
# A tighter check: skip only when agent_id is non-empty AND the event name
# explicitly identifies a subagent (e.g. SubagentStop). Main-agent Stop/Notification
# events that carry a stray agent_id field still flash.
if printf '%s' "$HOOK_DATA" | jq -e '(.agent_id // "") != "" and ((.hook_event_name // "") | test("Subagent"))' >/dev/null 2>&1; then
  exit 0
fi

SESSION_ID=$(printf '%s' "$HOOK_DATA" | jq -r '.session_id // ""' 2>/dev/null)
CWD=$(printf '%s' "$HOOK_DATA" | jq -r '.cwd // ""' 2>/dev/null)

# Collect tmux context. Prefer MELDR_TMUX_* vars injected at spawn time (M2 fix)
# since TMUX/TMUX_PANE are often stripped by Node.js wrappers before the hook runs.
PANE_ID=""
WINDOW_ID=""
WINDOW_NAME=""
if [ -n "${MELDR_TMUX_PANE:-}" ]; then
  PANE_ID="$MELDR_TMUX_PANE"
  WINDOW_ID="$MELDR_TMUX_WINDOW_ID"
  WINDOW_NAME=$(tmux display-message -t "$PANE_ID" -p '#{window_name}' 2>/dev/null || true)
elif [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  PANE_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_id}' 2>/dev/null || true)
  WINDOW_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null || true)
  WINDOW_NAME=$(tmux display-message -t "$TMUX_PANE" -p '#{window_name}' 2>/dev/null || true)
elif [ -n "${MELDR_AGENT_SESSION:-}" ]; then
  SIDECAR="$HOME/.cache/claude-agents/${MELDR_AGENT_SESSION}.parent_pane"
  PANE_ID=$(cat "$SIDECAR" 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}' 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_NAME=$(tmux display-message -t "$PANE_ID" -p '#{window_name}' 2>/dev/null || true)
fi

# Write state file (readable by recon, meldr agents, etc.) — must come after STATUS is set
# STATUS is set in the case block below; pre-initialize to avoid empty writes on unknown events
STATUS="$EVENT"

# Sound + tmux bell based on event type
case "$EVENT" in
  stop)
    STATUS="done"
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    ;;
  notify)
    STATUS="waiting"
    afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &
    ;;
  *)
    STATUS="$EVENT"
    ;;
esac

# Write state file now that STATUS is resolved (atomic write via mktemp+mv)
if [ -n "$SESSION_ID" ]; then
  TMP=$(mktemp "$STATE_DIR/.${SESSION_ID}.XXXXXX")
  printf '{"status":"%s","ts":%s,"cwd":"%s","pane":"%s","window":"%s","window_name":"%s"}\n' \
    "$STATUS" "$(date +%s)" "$CWD" "$PANE_ID" "$WINDOW_ID" "$WINDOW_NAME" \
    > "$TMP" && mv -f "$TMP" "$STATE_DIR/${SESSION_ID}.json" || rm -f "$TMP"
fi

# Set @cc_status on the tmux window so the tab flashes.
# Generation guard (GEN) prevents one pane's 120s clear-timer from wiping a
# later flash from a different pane in the same window.
if [ -n "$WINDOW_ID" ]; then
  GEN="$(date +%s%N)-$$"
  tmux set-option -w -t "$WINDOW_ID" @cc_status "$STATUS" 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" @cc_status_gen "$GEN" 2>/dev/null || true
  # Per-pane status for the border indicator (pane-border-format in tmux.conf)
  [ -n "$PANE_ID" ] && tmux set-option -p -t "$PANE_ID" @cc_pane_status "$STATUS" 2>/dev/null || true
  TIMEOUT="${MELDR_CC_TIMEOUT:-120}"
  tmux run-shell -b "sleep $TIMEOUT; \
    CUR=\$(tmux show-options -wqv -t '$WINDOW_ID' @cc_status_gen 2>/dev/null); \
    [ \"\$CUR\" = '$GEN' ] && tmux set-option -wu -t '$WINDOW_ID' @cc_status 2>/dev/null; \
    tmux set-option -wu -t '$WINDOW_ID' @cc_status_gen 2>/dev/null; \
    [ -n '$PANE_ID' ] && tmux set-option -pu -t '$PANE_ID' @cc_pane_status 2>/dev/null" \
    2>/dev/null || true
fi
