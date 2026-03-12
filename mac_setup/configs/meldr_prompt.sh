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
    if [ -f ~/.meldr_wt_color_"$wt" ]; then
      c=$(cat ~/.meldr_wt_color_"$wt")
    else
      hash=$(printf '%s' "$wt" | cksum | awk '{print $1}')
      colors="196 208 226 46 51 33 93 201 214 159"
      set -- $colors; shift $((hash % 10)); c=$1
    fi
    printf '\033[1;38;5;%sm/%s\033[0m' "$c" "$wt"
    # Check if git branch matches worktree directory
    warn=$(meldr prompt-check 2>&1)
    if [ -n "$warn" ]; then
      printf ' \033[1;38;5;196m%s\033[0m' "$warn"
    fi
  fi
fi
