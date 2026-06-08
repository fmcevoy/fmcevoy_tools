#!/usr/bin/env bats
# Tests for claude-session-start.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../configs/claude" && pwd)/claude-session-start.sh"

setup() {
  FAKE_HOME="$(mktemp -d)"
  LAUNCHER_DIR="$FAKE_HOME/.cache/claude-agents/launchers"
  STATE_DIR="$FAKE_HOME/.cache/claude-agents"
  mkdir -p "$LAUNCHER_DIR"
}

teardown() {
  rm -rf "$FAKE_HOME"
}

_launcher() {
  local pane="$1" cwd="$2" ts="$3"
  printf '{"pane":"%s","window":"@1","cwd":"%s","ts":%s}\n' "$pane" "$cwd" "$ts" \
    > "$LAUNCHER_DIR/${ts}-$$.json"
}

_stdin() {
  local sid="$1" cwd="$2"
  printf '{"session_id":"%s","cwd":"%s","source":"startup"}\n' "$sid" "$cwd"
}

@test "writes parent_pane sidecar from MELDR_TMUX_PANE env (path 1)" {
  _stdin "test-session-1" "/projects/foo" | \
    env HOME="$FAKE_HOME" MELDR_TMUX_PANE="%99" bash "$SCRIPT"
  [ -f "$STATE_DIR/test-session-1.parent_pane" ]
  run cat "$STATE_DIR/test-session-1.parent_pane"
  [ "$output" = "%99" ]
}

@test "cwd-prefix match picks correct launcher over unrelated one" {
  _launcher "%5" "/projects/myapp"       1000
  _launcher "%9" "/other/unrelated"      2000  # newer but wrong prefix
  _stdin "test-session-2" "/projects/myapp/src" | \
    env HOME="$FAKE_HOME" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-2.parent_pane"
  [ "$output" = "%5" ]
}

@test "falls back to most-recent launcher when no cwd prefix matches" {
  _launcher "%1" "/projects/alpha"  1000
  _launcher "%2" "/projects/beta"   9000  # most recent
  _stdin "test-session-3" "/completely/different" | \
    env HOME="$FAKE_HOME" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-3.parent_pane"
  [ "$output" = "%2" ]
}

@test "most-recent prefix match wins over older prefix match" {
  _launcher "%1" "/projects/app" 1000
  _launcher "%3" "/projects/app" 5000  # same prefix, newer
  _stdin "test-session-4" "/projects/app/lib" | \
    env HOME="$FAKE_HOME" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-4.parent_pane"
  [ "$output" = "%3" ]
}

@test "exact cwd match treated as prefix match" {
  _launcher "%7" "/projects/exact" 1000
  _stdin "test-session-5" "/projects/exact" | \
    env HOME="$FAKE_HOME" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-5.parent_pane"
  [ "$output" = "%7" ]
}

@test "exits 0 and writes nothing when no launchers and no env" {
  rm -f "$LAUNCHER_DIR"/*.json 2>/dev/null
  run env HOME="$FAKE_HOME" bash "$SCRIPT" <<< '{"session_id":"empty-session","cwd":"/x"}'
  [ "$status" -eq 0 ]
  [ ! -f "$STATE_DIR/empty-session.parent_pane" ]
}

@test "exits 0 and writes nothing when session_id is missing from payload" {
  run env HOME="$FAKE_HOME" bash "$SCRIPT" <<< '{"cwd":"/x"}'
  [ "$status" -eq 0 ]
}

@test "skips malformed JSON launcher files and continues" {
  printf 'not json {{' > "$LAUNCHER_DIR/bad-$$.json"
  _launcher "%4" "/projects/ok" 9999
  _stdin "test-session-6" "/projects/ok/src" | \
    env HOME="$FAKE_HOME" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-6.parent_pane"
  [ "$output" = "%4" ]
}

@test "MELDR_TMUX_PANE takes priority over launcher registry" {
  _launcher "%99" "/projects/any" 9999999
  _stdin "test-session-7" "/projects/any" | \
    env HOME="$FAKE_HOME" MELDR_TMUX_PANE="%env-wins" bash "$SCRIPT"
  run cat "$STATE_DIR/test-session-7.parent_pane"
  [ "$output" = "%env-wins" ]
}
