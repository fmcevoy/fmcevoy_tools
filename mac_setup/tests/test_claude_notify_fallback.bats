#!/usr/bin/env bats
# Tests for claude-notify.sh: pane-resolution fallback and Stop classifier

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
  local sid="$1" cwd="${2:-/tmp}" transcript="${3:-}"
  if [ -n "$transcript" ]; then
    printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop","transcript_path":"%s"}\n' \
      "$sid" "$cwd" "$transcript"
  else
    printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop"}\n' "$sid" "$cwd"
  fi
}

_make_transcript() {
  local dir="$1" last_text="$2"
  local f="$dir/transcript.jsonl"
  printf '{"role":"user","content":"hello"}\n' >> "$f"
  printf '{"role":"assistant","content":[{"type":"text","text":"%s"}]}\n' "$last_text" >> "$f"
  echo "$f"
}

# ── pane-resolution fallback ──────────────────────────────────────────────────

@test "resolves pane from session_id.parent_pane sidecar" {
  local SID="abc-123-def"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

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

# ── Stop classifier ───────────────────────────────────────────────────────────

@test "Stop with transcript ending in '?' → status=waiting" {
  local SID="q-session"
  local TF
  TF=$(_make_transcript "$FAKE_HOME" "Should I use tabs or spaces?")
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" "/tmp" "$TF" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "waiting" ]
}

@test "Stop with transcript containing 'needs input:' → status=waiting" {
  local SID="ni-session"
  local TF
  TF=$(_make_transcript "$FAKE_HOME" "needs input: should I add tests")
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" "/tmp" "$TF" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "waiting" ]
}

@test "Stop with transcript ending in statement → status=done" {
  local SID="done-session"
  local TF
  TF=$(_make_transcript "$FAKE_HOME" "All tests pass.")
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" "/tmp" "$TF" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "done" ]
}

@test "Stop with missing transcript_path → falls back to status=done" {
  local SID="no-transcript-session"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "done" ]
}

@test "Stop with nonexistent transcript file → falls back to status=done" {
  local SID="missing-file-session"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" "/tmp" "/nonexistent/path/transcript.jsonl" \
    | env HOME="$FAKE_HOME" \
      MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
      bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "done" ]
}

@test "Stop with AskUserQuestion tool_use → status=waiting" {
  local SID="askq-session"
  local TF="$FAKE_HOME/askq_transcript.jsonl"
  printf '{"role":"user","content":"hi"}\n' > "$TF"
  printf '{"role":"assistant","content":[{"type":"tool_use","name":"AskUserQuestion","id":"t1","input":{"questions":[]}}]}\n' >> "$TF"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  _hook_stdin "$SID" "/tmp" "$TF" | env HOME="$FAKE_HOME" \
    MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
    bash "$SCRIPT" stop

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "waiting" ]
}

# ── Timeout default ───────────────────────────────────────────────────────────

@test "notify event still produces status=waiting" {
  local SID="notify-session"
  printf '%%55' > "$STATE_DIR/${SID}.parent_pane"

  printf '{"session_id":"%s","cwd":"/tmp","hook_event_name":"Notification"}\n' "$SID" \
    | env HOME="$FAKE_HOME" \
      MELDR_TMUX_PANE="" TMUX="" TMUX_PANE="" MELDR_AGENT_SESSION="" \
      bash "$SCRIPT" notify

  run jq -r '.status' "$STATE_DIR/${SID}.json"
  [ "$output" = "waiting" ]
}
