#!/bin/sh
d=$PWD; ws=""; wsdir=""
while [ "$d" != / ]; do
  [ -f "$d/meldr.toml" ] && ws=$(awk -F'"' '/^name/{print $2; exit}' "$d/meldr.toml") && wsdir="$d" && break
  d=$(dirname "$d")
done
if [ -n "$ws" ]; then
  printf '\033[1;38;5;208m⚙ %s\033[0m' "$ws"
  rel="${PWD#"$wsdir/worktrees/"}"
  if [ "$rel" != "$PWD" ]; then
    wt="${rel%%/*}"
    c=$(cat ~/.meldr_wt_color 2>/dev/null || echo 51)
    printf '\033[1;38;5;%sm/%s\033[0m' "$c" "$wt"
  fi
fi
