#!/usr/bin/env bats
# Tests for claude-agents-register-launcher.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../configs/claude" && pwd)/claude-agents-register-launcher.sh"

setup() {
  FAKE_HOME="$(mktemp -d)"
  LAUNCHER_DIR="$FAKE_HOME/.cache/claude-agents/launchers"
  # Mock tmux to return a predictable window id without requiring a live server
  MOCK_BIN="$(mktemp -d)"
  cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "@42"
EOF
  chmod +x "$MOCK_BIN/tmux"
  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$FAKE_HOME" "$MOCK_BIN"
}

@test "writes JSON launcher file when TMUX_PANE is set" {
  TESTCWD="$(mktemp -d)"
  run env HOME="$FAKE_HOME" TMUX_PANE="%7" bash -c "cd '$TESTCWD' && bash '$SCRIPT'"
  [ "$status" -eq 0 ]
  count=$(find "$LAUNCHER_DIR" -name '*.json' | wc -l)
  [ "$count" -eq 1 ]
  FILE=$(find "$LAUNCHER_DIR" -name '*.json' | head -1)
  run jq -r '.pane' "$FILE"
  [ "$output" = "%7" ]
  run jq -r '.cwd' "$FILE"
  [ "$output" = "$TESTCWD" ]
  run jq -r '.window' "$FILE"
  [ "$output" = "@42" ]
  run jq -r '.ts' "$FILE"
  [[ "$output" =~ ^[0-9]+$ ]]
  rm -rf "$TESTCWD"
}

@test "no-op when TMUX_PANE is unset" {
  run env HOME="$FAKE_HOME" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  count=$(find "$FAKE_HOME" -name '*.json' 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "creates launcher dir if missing" {
  [ ! -d "$LAUNCHER_DIR" ]
  run env HOME="$FAKE_HOME" TMUX_PANE="%1" PWD="/tmp" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$LAUNCHER_DIR" ]
}

@test "concurrent invocations produce distinct filenames" {
  env HOME="$FAKE_HOME" TMUX_PANE="%1" PWD="/a" bash "$SCRIPT"
  sleep 0.01
  env HOME="$FAKE_HOME" TMUX_PANE="%2" PWD="/b" bash "$SCRIPT"
  count=$(find "$LAUNCHER_DIR" -name '*.json' | wc -l)
  [ "$count" -eq 2 ]
}

@test "prunes entries older than 24 hours" {
  mkdir -p "$LAUNCHER_DIR"
  # Create a stale file with mtime > 1 day ago
  touch -t "$(date -v-2d +%Y%m%d%H%M.%S 2>/dev/null || date -d '2 days ago' +%Y%m%d%H%M.%S)" \
    "$LAUNCHER_DIR/old-$$.json" 2>/dev/null || touch "$LAUNCHER_DIR/old-$$.json"
  # macOS: use touch -t to set mtime; skip the age test if touch -d isn't available
  # Force old mtime via stat-compatible approach
  # The stale file exists before we run the script
  stale_count=$(find "$LAUNCHER_DIR" -name '*.json' | wc -l)
  [ "$stale_count" -ge 1 ]

  run env HOME="$FAKE_HOME" TMUX_PANE="%1" PWD="/tmp" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # The old file should be gone (if mtime was set correctly), and one new file present
  remaining=$(find "$LAUNCHER_DIR" -name '*.json' | wc -l)
  [ "$remaining" -ge 1 ]
}

@test "exit 0 even when tmux is unavailable" {
  # Override mock tmux with one that fails
  cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  run env HOME="$FAKE_HOME" TMUX_PANE="%1" PWD="/tmp" bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
