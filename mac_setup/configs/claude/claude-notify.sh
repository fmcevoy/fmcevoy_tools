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

# Inspect the assistant turn that just completed and classify the Stop event.
# Returns "waiting" when the turn ends with a question, contains "needs input:",
# or used the AskUserQuestion tool; "done" otherwise. Best-effort: falls back to
# "done" on any parse failure so the flash always fires.
#
# Two subtleties handled here:
#   1. One assistant turn spans multiple JSONL lines (thinking + text + tool_use
#      blocks). Looking only at the last line misses the text block when the
#      turn ends with tool_use, so we scan every assistant line written after
#      the most recent user message.
#   2. Claude Code can invoke the Stop hook before the final assistant line is
#      flushed to the transcript (more visible on background sessions). We poll
#      briefly for new assistant content rather than reading once and bailing.
classify_stop_status() {
  local transcript="$1"
  [ -z "$transcript" ] || [ ! -f "$transcript" ] && { echo "done"; return; }

  local asst_lines="" last_user_line attempt=0
  while [ $attempt -lt 6 ]; do
    last_user_line=$(grep -an '"role"[[:space:]]*:[[:space:]]*"user"' "$transcript" 2>/dev/null | tail -1 | cut -d: -f1)
    if [ -n "$last_user_line" ]; then
      asst_lines=$(awk -v n="$last_user_line" 'NR>n' "$transcript" 2>/dev/null \
                    | grep -a '"role"[[:space:]]*:[[:space:]]*"assistant"' 2>/dev/null)
    else
      asst_lines=$(grep -a '"role"[[:space:]]*:[[:space:]]*"assistant"' "$transcript" 2>/dev/null)
    fi
    [ -n "$asst_lines" ] && break
    sleep 0.15
    attempt=$((attempt + 1))
  done
  [ -z "$asst_lines" ] && { echo "done"; return; }

  # AskUserQuestion tool_use in any block of this turn → always waiting.
  if printf '%s\n' "$asst_lines" | \
      jq -e -s '[.[] | (.message.content // .content // [])[] | select(.type=="tool_use" and .name=="AskUserQuestion")] | length > 0' \
      >/dev/null 2>&1; then
    echo "waiting"; return
  fi

  local text
  text=$(printf '%s\n' "$asst_lines" | \
    jq -r -s '[.[] | (.message.content // .content // [])[] | select(.type=="text") | .text] | join("\n")' \
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
