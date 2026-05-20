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

# Skip subagent invocations — only the main agent should flash/beep.
# Per docs, agent_id is present *only* when the hook fires inside a subagent.
if printf '%s' "$HOOK_DATA" | jq -e 'has("agent_id")' >/dev/null 2>&1; then
  exit 0
fi

SESSION_ID=$(printf '%s' "$HOOK_DATA" | jq -r '.session_id // ""' 2>/dev/null)
CWD=$(printf '%s' "$HOOK_DATA" | jq -r '.cwd // ""' 2>/dev/null)

# Collect tmux context (inherited from the Claude process environment)
PANE_ID=""
WINDOW_ID=""
WINDOW_NAME=""
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  PANE_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_id}' 2>/dev/null || true)
  WINDOW_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null || true)
  WINDOW_NAME=$(tmux display-message -t "$TMUX_PANE" -p '#{window_name}' 2>/dev/null || true)
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

# Write state file now that STATUS is resolved
if [ -n "$SESSION_ID" ]; then
  printf '{"status":"%s","ts":%s,"cwd":"%s","pane":"%s","window":"%s","window_name":"%s"}\n' \
    "$STATUS" "$(date +%s)" "$CWD" "$PANE_ID" "$WINDOW_ID" "$WINDOW_NAME" \
    > "$STATE_DIR/${SESSION_ID}.json"
fi

# Set @cc_status on the tmux window — tmux.conf format conditionals render the flash.
# Works on both focused and inactive tabs. Clears via pane-focus-in hook (tmux.conf)
# or the 60s safety timer below, whichever comes first.
if [ -n "${TMUX:-}" ] && [ -n "$WINDOW_ID" ]; then
  tmux set-option -w -t "$WINDOW_ID" @cc_status "$STATUS" 2>/dev/null || true
  # Use a short timeout when the user is already looking at the Claude tab
  ACTIVE_WINDOW=$(tmux display-message -p '#{window_id}' 2>/dev/null || true)
  TIMEOUT=60
  [ "$ACTIVE_WINDOW" = "$WINDOW_ID" ] && TIMEOUT=3
  tmux run-shell -b "sleep $TIMEOUT; tmux set-option -w -u -t '$WINDOW_ID' @cc_status 2>/dev/null" 2>/dev/null || true
fi
