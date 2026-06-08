#!/usr/bin/env bats
# Tests for the new SESSION_ID.parent_pane fallback in claude-notify.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../configs/claude" && pwd)/claude-notify.sh"

setup() {
  FAKE_HOME="$(mktemp -d)"
  STATE_DIR="$FAKE_HOME/.cache/claude-agents"
  mkdir -p "$STATE_DIR"

  # Mock tmux: records calls to a log and returns predictable values
  MOCK_BIN="$(mktemp -d)"
  TMUX_CALL_LOG="$MOCK_BIN/tmux_calls.log"
  cat > "$MOCK_BIN/tmux" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$TMUX_CALL_LOG"
case "\$*" in
  *"window_id"*) echo "@99" ;;
  *"window_name"*) echo "test-window" ;;
  *"pane_id"*) echo "%55" ;;
  *"set-option"*) exit 0 ;;
  *"run-shell"*) exit 0 ;;
  *"display-message"*) echo "%55" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCK_BIN/tmux"
  # Also mock afplay so the sound call doesn't fail
  cat > "$MOCK_BIN/afplay" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/afplay"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$FAKE_HOME" "$MOCK_BIN"
}

_hook_stdin() {
  local sid="$1" cwd="${2:-/tmp}"
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop"}\n' "$sid" "$cwd"
}

@test "resolves pane from session_id.parent_pane sidecar" {
  local SID="abc-123-def"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  # Verify state file was written with correct pane
  [ -f "$STATE_DIR/${SID}.json" ]
  run jq -r '.pane' "$STATE_DIR/${SID}.json"
  [ "$output" = "%55" ]
}

@test "MELDR_AGENT_SESSION sidecar wins over session_id.parent_pane sidecar" {
  local SID="session-priority-test"
  local MAS="1234-5678-1"
  printf '%%agent-session-pane' > "$STATE_DIR/${MAS}.parent_pane"
  printf '%%uuid-session-pane'  > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="$MAS" \
    bash "$SCRIPT" stop

  run jq -r '.pane' "$STATE_DIR/${SID}.json"
  [ "$output" = "%agent-session-pane" ]
}

@test "state file pane is empty when no sidecar and no env vars" {
  local SID="no-context-session"
  _hook_stdin "$SID" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  [ -f "$STATE_DIR/${SID}.json" ]
  run jq -r '.pane' "$STATE_DIR/${SID}.json"
  [ "$output" = "" ]
}

@test "exits 0 even when tmux set-option fails" {
  local SID="tmux-fail-session"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"
  # Override tmux mock to fail on set-option
  cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *"set-option"*) exit 1 ;;
  *"display-message"*) echo "%55" ;;
  *) exit 0 ;;
esac
EOF

  run env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop <<< "{\"session_id\":\"$SID\",\"cwd\":\"/tmp\",\"hook_event_name\":\"Stop\"}"
  [ "$status" -eq 0 ]
}
