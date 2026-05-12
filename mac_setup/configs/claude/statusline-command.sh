#!/usr/bin/env bash
# ~/.claude/statusline-command.sh
# Claude Code status line: git repo, worktree, model, context usage, rate limits

input=$(cat)

# --- Model
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

# --- CWD
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Git repo / worktree / branch (meldr-aware)
# cd into the workspace current_dir so all git commands reflect Claude's actual cwd.
repo_label=""

_meldr_branch() {
  # Print branch from cwd; falls back to short SHA on detached HEAD; empty if not a git repo.
  local b
  b=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$b" = "HEAD" ]; then
    b=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --short HEAD 2>/dev/null)
  fi
  printf '%s' "$b"
}

if [ -n "$cwd" ] && cd "$cwd" 2>/dev/null; then

  # --- 1. Walk up looking for a meldr workspace root ---
  meldr_root=""
  d="$cwd"
  while [ "$d" != "/" ]; do
    if [ -f "$d/meldr.toml" ]; then
      meldr_root="$d"
      break
    fi
    d=$(dirname "$d")
  done

  if [ -n "$meldr_root" ]; then
    # --- meldr workspace detected ---
    # Determine where inside the workspace we are.
    rel_path=${cwd#$meldr_root/}
    rel_path=${rel_path%/}

    case "$rel_path" in
      worktrees/*)
        # rel_path = worktrees/{wt}[/{pkg}[/...]]
        meldr_wt=${rel_path#worktrees/}
        meldr_wt=${meldr_wt%%/*}
        after_wt=${rel_path#worktrees/$meldr_wt}
        after_wt_slash=${after_wt#/}
        if [ "$after_wt_slash" = "$meldr_wt" ]; then
          meldr_pkg=""
        else
          meldr_pkg=${after_wt_slash%%/*}
        fi
        if [ -z "$meldr_pkg" ]; then
          repo_label="${meldr_wt}"
        else
          branch=$(_meldr_branch)
          if [ -z "$branch" ] || [ "$branch" = "$meldr_wt" ]; then
            repo_label="${meldr_pkg}/${branch}"
          else
            repo_label="${meldr_pkg}/${branch}/${meldr_wt}"
          fi
        fi
        ;;
      "")
        repo_label="$(basename "$meldr_root")"
        ;;
      *)
        git_common_dir=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
        if [ -n "$git_common_dir" ]; then
          git_pkg=$(basename "$(dirname "$git_common_dir")")
          git_branch=$(_meldr_branch)
          repo_label="${git_pkg}/${git_branch}"
        fi
        ;;
    esac

  else
    # --- 2. Not a meldr workspace — plain git fallback ---
    git_common_dir=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if [ -n "$git_common_dir" ]; then
      git_pkg=$(basename "$(dirname "$git_common_dir")")
      git_toplevel=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --show-toplevel 2>/dev/null)
      git_dir=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --path-format=absolute --git-dir 2>/dev/null)
      git_branch=$(_meldr_branch)

      # Is this a linked worktree? (git-dir differs from git-common-dir)
      if [ "$git_dir" != "$git_common_dir" ] && [ -n "$git_toplevel" ]; then
        git_wt_name=$(basename "$git_toplevel")
        if [ -z "$git_branch" ] || [ "$git_branch" = "$git_wt_name" ]; then
          repo_label="${git_pkg}/${git_branch}"
        else
          repo_label="${git_pkg}/${git_branch}/${git_wt_name}"
        fi
      else
        repo_label="${git_pkg}/${git_branch}"
      fi
    fi
  fi
  # --- 3. Not in any git repo — fall back to basename of cwd
  # (Handled in the assembly block below via the empty repo_label check)
fi

# --- Context window ---
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Format context window size (e.g. 200k)
if [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  ctx_size_fmt=$(awk "BEGIN { printf \"%.0fk\", $ctx_size/1000 }")
else
  ctx_size_fmt=""
fi

# Format used/remaining
ctx_info=""
if [ -n "$used_pct" ] && [ -n "$ctx_size_fmt" ]; then
  # Prefer .context_window.used_tokens when present; otherwise derive from ctx_size * used_pct / 100
  used_tokens_raw=$(echo "$input" | jq -r '.context_window.used_tokens // empty')
  if [ -z "$used_tokens_raw" ]; then
    used_tokens_raw=$(awk "BEGIN { printf \"%.0f\", $ctx_size * $used_pct / 100 }")
  fi
  used_tokens_fmt=$(awk -v t="$used_tokens_raw" '
    BEGIN {
      if (t < 10000) { printf "%.1fk", t/1000 }
      else           { printf "%.0fk", t/1000 }
    }')
  ctx_info="${used_tokens_fmt}/${ctx_size_fmt}"
fi

# Format token counts (in/out)
token_info=""
if [ "$total_input" -gt 0 ] 2>/dev/null || [ "$total_output" -gt 0 ] 2>/dev/null; then
  in_fmt=$(awk "BEGIN { printf \"%.1fk\", $total_input/1000 }")
  out_fmt=$(awk "BEGIN { printf \"%.1fk\", $total_output/1000 }")
  token_info="in:${in_fmt} out:${out_fmt}"
fi

# --- Session cost ---
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
cost_info=""
if [ -n "$total_cost" ]; then
  cost_nonzero=$(awk "BEGIN { print ($total_cost > 0.0005) ? \"yes\" : \"no\" }")
  if [ "$cost_nonzero" = "yes" ]; then
    cost_info=$(awk "BEGIN { printf \"\$%.2f\", $total_cost }")
  fi
fi

# --- Rate limits (Claude.ai subscription spend/usage) ---
rate_info=""
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
if [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  rate_info="${five_int}%"
fi
if [ -n "$week_pct" ]; then
  week_int=$(printf "%.0f" "$week_pct")
  rate_info="${rate_info:+$rate_info }7d:${week_int}%"
fi

# --- Assemble output (status line renders in dimmed context) ---
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

C_REPO="\033[38;5;75m"        # steel blue   - repo/worktree
C_MODEL="\033[38;5;183m"      # soft purple  - model
C_CTX="\033[38;5;150m"        # muted green  - context
C_TOKENS="\033[38;5;180m"     # warm tan     - tokens
C_RATE="\033[38;5;209m"       # soft orange  - rate limits
C_COST="\033[38;5;221m"       # soft gold    - session cost
C_DATE="\033[38;5;244m"       # soft grey    - date/time
C_DIRTY="\033[38;5;174m"      # muted red/coral - dirty file count
C_MR_OK="\033[38;5;77m"       # muted green  - MR pipeline success
C_MR_FAIL="\033[38;5;174m"    # muted red    - MR pipeline failed
C_MR_PENDING="\033[38;5;214m" # light tan    - MR in-progress/unknown
C_AWS="\033[38;5;215m"        # muted orange - AWS profile

sep() { printf "${DIM} | ${RESET}"; }

_join_parts() {
  local result=""
  local part
  for part in "$@"; do
    if [ -z "$result" ]; then
      result="$part"
    else
      result="$result$(sep)$part"
    fi
  done
  printf "%b" "$result"
}

# --- Effort level ---
effort_level=$(echo "$input" | jq -r '.effort.level // empty')

# --- Line 1: spend/usage theme — model [effort] | ctx | cost | rate_limits | tokens ---
line1_parts=()

if [ -n "$effort_level" ]; then
  line1_parts+=("$(printf "${C_MODEL}%s${DIM}[%s]${RESET}" "$model" "$effort_level")")
else
  line1_parts+=("$(printf "${C_MODEL}%s${RESET}" "$model")")
fi

if [ -n "$ctx_info" ]; then
  line1_parts+=("$(printf "${C_CTX}%s${RESET}" "$ctx_info")")
fi

if [ -n "$cost_info" ]; then
  line1_parts+=("$(printf "${C_COST}%s${RESET}" "$cost_info")")
fi

if [ -n "$rate_info" ]; then
  line1_parts+=("$(printf "${C_RATE}%s${RESET}" "$rate_info")")
fi

if [ -n "$token_info" ]; then
  line1_parts+=("$(printf "${C_TOKENS}%s${RESET}" "$token_info")")
fi

# --- Line 2: location/time theme — repo_label | dirty | aws | mr | date_time ---
line2_parts=()

if [ -n "$repo_label" ]; then
  line2_parts+=("$(printf "${C_REPO}${BOLD}%s${RESET}" "$repo_label")")
elif [ -n "$cwd" ]; then
  line2_parts+=("$(printf "${C_REPO}${BOLD}%s${RESET}" "$(basename "$cwd")")")
fi

# --- Git dirty marker ---
# Count modified+staged+untracked files; omit if 0 or not in a git repo.
if [ -n "$cwd" ]; then
  dirty_count=$(cd "$cwd" 2>/dev/null && GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1 2>/dev/null | wc -l | tr -d '[:space:]')
  if [ -n "$dirty_count" ] && [ "$dirty_count" -gt 0 ] 2>/dev/null; then
    line2_parts+=("$(printf "${C_DIRTY}%s${RESET}" "$dirty_count")")
  fi
fi

# AWS profile (with optional region)
aws_profile="${AWS_PROFILE:-}"
if [ -n "$aws_profile" ]; then
  aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  if [ -n "$aws_region" ]; then
    line2_parts+=("$(printf "${C_AWS}%s/%s${RESET}" "$aws_profile" "$aws_region")")
  else
    line2_parts+=("$(printf "${C_AWS}%s${RESET}" "$aws_profile")")
  fi
fi

# --- GitLab MR status ---
# Requires glab in PATH and a git repo. Results are cached per-branch (TTL 120s).
# Background refresh is used so glab network calls never block the status line.
_glab_mr_segment() {
  command -v glab >/dev/null 2>&1 || return
  [ -n "$cwd" ] || return
  cd "$cwd" 2>/dev/null || return

  local branch
  branch=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return

  local repo_top
  repo_top=$(GIT_OPTIONAL_LOCKS=0 git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$repo_top" ] || return

  local cachedir="$HOME/.cache/claude-statusline"
  mkdir -p "$cachedir" 2>/dev/null || true

  local cache_key cache_file tmp_file
  cache_key=$(printf '%s:%s' "$repo_top" "$branch" | shasum -a 1 2>/dev/null | awk '{print $1}')
  [ -n "$cache_key" ] || return
  cache_file="$cachedir/glab-$cache_key.txt"
  tmp_file="$cachedir/glab-$cache_key.txt.tmp"

  local now mtime age
  now=$(date +%s)
  if [ -f "$cache_file" ]; then
    mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    if [ -n "$mtime" ]; then
      age=$(( now - mtime ))
      if [ "$age" -lt 120 ]; then
        cat "$cache_file" 2>/dev/null
        return
      fi
    fi
  fi

  # Cache is missing or stale — spawn a background refresh (if not already in flight)
  local spawn=1
  if [ -f "$tmp_file" ]; then
    local tmp_mtime tmp_age
    tmp_mtime=$(stat -f %m "$tmp_file" 2>/dev/null)
    if [ -n "$tmp_mtime" ]; then
      tmp_age=$(( now - tmp_mtime ))
      if [ "$tmp_age" -lt 30 ]; then
        spawn=0
      fi
    fi
  fi

  if [ "$spawn" -eq 1 ]; then
    local _branch="$branch" _cache_file="$cache_file" _tmp_file="$tmp_file"
    (
      : > "$_tmp_file" 2>/dev/null
      raw=$(glab mr list --source-branch "$_branch" --state opened --output json 2>/dev/null)
      iid=$(printf '%s' "$raw" | jq -r '.[0].iid // empty' 2>/dev/null)
      if [ -n "$iid" ]; then
        pipeline=$(printf '%s' "$raw" | jq -r '.[0].pipeline.status // ""' 2>/dev/null)
        case "$pipeline" in
          success)         sym="✓" ;;
          failed|canceled) sym="✗" ;;
          *)               sym="∘" ;;
        esac
        printf '!MR%s %s' "$iid" "$sym" > "$_tmp_file" 2>/dev/null
      else
        : > "$_tmp_file" 2>/dev/null
      fi
      mv "$_tmp_file" "$_cache_file" 2>/dev/null
    ) >/dev/null 2>&1 &
  fi

  # While waiting for first fetch, or between stale/fresh, use stale cache if available
  if [ -f "$cache_file" ]; then
    cat "$cache_file" 2>/dev/null
  fi
  # If no cache file at all, output nothing this tick
}

mr_segment=$(_glab_mr_segment)
if [ -n "$mr_segment" ]; then
  case "$mr_segment" in
    *✓) mr_color="$C_MR_OK" ;;
    *✗) mr_color="$C_MR_FAIL" ;;
    *)  mr_color="$C_MR_PENDING" ;;
  esac
  line2_parts+=("$(printf "${mr_color}%s${RESET}" "$mr_segment")")
fi

# Date/time (always present)
line2_parts+=("$(printf "${C_DATE}%s${RESET}" "$(date '+%a %d/%m %H:%M')")")

# --- Output ---
printf "%b\n%b" "$(_join_parts "${line1_parts[@]}")" "$(_join_parts "${line2_parts[@]}")"
