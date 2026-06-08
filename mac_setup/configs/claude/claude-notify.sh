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
TRANSCRIPT=$(printf '%s' "$HOOK_DATA" | jq -r '.transcript_path // ""' 2>/dev/null)
# Expand leading ~ in transcript path
TRANSCRIPT="${TRANSCRIPT/#\~/$HOME}"

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
  SIDECAR="$STATE_DIR/${MELDR_AGENT_SESSION}.parent_pane"
  PANE_ID=$(cat "$SIDECAR" 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}' 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_NAME=$(tmux display-message -t "$PANE_ID" -p '#{window_name}' 2>/dev/null || true)
elif [ -n "$SESSION_ID" ] && [ -f "$STATE_DIR/${SESSION_ID}.parent_pane" ]; then
  # claude agents path: sidecar written by claude-session-start.sh at session startup
  PANE_ID=$(cat "$STATE_DIR/${SESSION_ID}.parent_pane" 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}' 2>/dev/null || true)
  [ -n "$PANE_ID" ] && WINDOW_NAME=$(tmux display-message -t "$PANE_ID" -p '#{window_name}' 2>/dev/null || true)
fi

# Inspect the last assistant turn in the transcript to classify Stop events.
# Returns "waiting" when the turn ends with a question, contains "needs input:",
# or used the AskUserQuestion tool; "done" otherwise. Best-effort: falls back to
# "done" on any parse failure so the flash always fires.
classify_stop_status() {
  local transcript="$1"
  [ -z "$transcript" ] || [ ! -f "$transcript" ] && { echo "done"; return; }

  local last_asst
  last_asst=$(grep -a '"role"[[:space:]]*:[[:space:]]*"assistant"' "$transcript" 2>/dev/null | tail -1)
  [ -z "$last_asst" ] && { echo "done"; return; }

  # AskUserQuestion tool_use in content array → always waiting
  if printf '%s' "$last_asst" | \
      jq -e '(.message.content // .content // [])[] | select(.type=="tool_use" and .name=="AskUserQuestion")' \
      >/dev/null 2>&1; then
    echo "waiting"; return
  fi

  local text
  text=$(printf '%s' "$last_asst" | \
    jq -r '[(.message.content // .content // [])[] | select(.type=="text") | .text] | join("")' \
    2>/dev/null) || true
  [ -z "$text" ] && { echo "done"; return; }

  local trimmed
  trimmed=$(printf '%s' "$text" | sed 's/[[:space:]]*$//')

  if printf '%s' "$trimmed" | grep -qE '[?]$' || \
     printf '%s' "$text"    | grep -qi 'needs input:'; then
    echo "waiting"
  else
    echo "done"
  fi
}

# Sound + tmux bell based on event type
case "$EVENT" in
  stop)
    STATUS=$(classify_stop_status "$TRANSCRIPT")
    if [ "$STATUS" = "waiting" ]; then
      afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &
    else
      afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    fi
    ;;
  notify)
    STATUS="waiting"
    afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &
    ;;
  *)
    STATUS="$EVENT"
    ;;
esac

# Write state file (atomic write via mktemp+mv)
if [ -n "$SESSION_ID" ]; then
  TMP=$(mktemp "$STATE_DIR/.${SESSION_ID}.XXXXXX")
  printf '{"status":"%s","ts":%s,"cwd":"%s","pane":"%s","window":"%s","window_name":"%s"}\n' \
    "$STATUS" "$(date +%s)" "$CWD" "$PANE_ID" "$WINDOW_ID" "$WINDOW_NAME" \
    > "$TMP" && mv -f "$TMP" "$STATE_DIR/${SESSION_ID}.json" || rm -f "$TMP"
fi

# Set @cc_status on the tmux window so the tab flashes.
# Generation guard (GEN) prevents one pane's clear-timer from wiping a
# later flash from a different pane in the same window.
if [ -n "$WINDOW_ID" ]; then
  GEN="$(date +%s%N)-$$"
  TIMEOUT="${MELDR_CC_TIMEOUT:-5}"
  tmux set-option -w -t "$WINDOW_ID" @cc_status "$STATUS" 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" @cc_status_gen "$GEN" 2>/dev/null || true
  # Per-pane status for the border indicator (pane-border-format in tmux.conf)
  [ -n "$PANE_ID" ] && tmux set-option -p -t "$PANE_ID" @cc_pane_status "$STATUS" 2>/dev/null || true
  tmux run-shell -b "sleep $TIMEOUT; \
    CUR=\$(tmux show-options -wqv -t '$WINDOW_ID' @cc_status_gen 2>/dev/null); \
    [ \"\$CUR\" = '$GEN' ] && tmux set-option -wu -t '$WINDOW_ID' @cc_status 2>/dev/null; \
    tmux set-option -wu -t '$WINDOW_ID' @cc_status_gen 2>/dev/null; \
    [ -n '$PANE_ID' ] && tmux set-option -pu -t '$PANE_ID' @cc_pane_status 2>/dev/null" \
    2>/dev/null || true
fi
