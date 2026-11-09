#!/usr/bin/env bash
# Migration: commands are `takumi <group> <name>` now, kept in /usr/lib/takumi/commands rather than as
# takumi-<group>-<name> files in /usr/bin. Point the niri config's binds and the sudo password helper at them,
# each file copied aside first. See docs/commands.md.
set -euo pipefail
cmds=/usr/lib/takumi/commands
[[ -d "$cmds" ]] || cmds="$(dirname "$(readlink -f "$0")")/../commands"
stamp=$(date +%Y%m%d%H%M%S)
# The words for an old one-word name ("wifi-join" -> "takumi" "wifi" "join"), or nothing when no command
# answers to it (takumi-session and the takumi-sky surface keep their names).
words() {
  local g=${1%%-*} rest=${1#*-}
  [[ "$rest" == "$1" ]] && rest=main
  [[ "$g" == toggle ]] && g=switch
  if [[ "$rest" != main && -x "$cmds/$g/$rest" ]]; then printf '"takumi" "%s" "%s"' "$g" "$rest"
  elif [[ "$rest" == main && -x "$cmds/$g/main" ]]; then printf '"takumi" "%s"' "$g"
  fi
}
for f in "$HOME/.config/niri/config.kdl" "$HOME/.config/niri/takumi/defaults.kdl"; do
  [[ -f "$f" ]] && grep -qE '"(/usr/bin/)?takumi-[a-z]' "$f" || continue
  expr='s|"/usr/bin/takumi-askpass"|"/usr/lib/takumi/commands/approve/askpass"|g;'
  for old in $(grep -oE '"takumi-[a-z]+(-[a-z]+)*"' "$f" | tr -d '"' | sed 's/^takumi-//' | sort -u); do
    new=$(words "$old")
    if [[ -n "$new" ]]; then expr+="s|\"takumi-$old\"|$new|g;"; fi
  done
  out=$(sed "$expr" "$f")
  [[ "$out" == "$(cat "$f")" ]] && continue
  cp "$f" "$f.bak-$stamp"
  printf '%s\n' "$out" > "$f.new" && mv "$f.new" "$f"
done
exit 0
