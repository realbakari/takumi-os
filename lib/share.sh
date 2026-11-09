#!/usr/bin/env bash
# Sending to phones and computers nearby through LocalSend, and your phone through KDE Connect, for commands/share/*,
# commands/phone/* and the Palette's phone rows. Sourced, not run; bash 3.2 (the tests use fakes on macOS).
# See docs/sharing.md.

share_app=org.localsend.localsend_app      # LocalSend, from Flathub
share_state="$HOME/.local/state/takumi/share"
share_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}/takumi"
share_scripts="$HOME/.local/share/nautilus/scripts"   # Files: right-click › Scripts

# --- What you copied in Files ---

# The files on the clipboard (copied in Files with Super+C), one path per line; nothing when it holds no files.
share_copied() {
  command -v wl-paste >/dev/null || return 0
  local types u
  types=$(wl-paste --list-types 2>/dev/null || true)
  grep -qx 'text/uri-list' <<< "$types" || return 0
  wl-paste --no-newline --type text/uri-list 2>/dev/null | tr -d '\r' | while IFS= read -r u; do
    case "$u" in file://*) ;; *) continue ;; esac
    u=${u#file://}; u=${u#localhost}
    printf '%b\n' "$(printf '%s' "$u" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"
  done
  return 0
}

# share_script <name> <command words...>: a script in Files' right-click › Scripts that runs a takumi command with
# the files selected there, by their full paths.
share_script() {
  local n=$1; shift
  mkdir -p "$share_scripts"
  {
    printf '#!/bin/sh\n# Takumi: right-click selected files › Scripts › %s (docs/sharing.md).\n' "$n"
    printf 'n=$#; while [ "$n" -gt 0 ]; do f=$1; shift; case $f in /*) ;; *) f=$PWD/$f ;; esac; set -- "$@" "$f"; n=$((n - 1)); done\n'
    printf 'exec %s "$@"\n' "$*"
  } > "$share_scripts/$n"
  chmod +x "$share_scripts/$n"
}

# --- Making photos and videos smaller to send (takumi share shrink) ---

share_picked="$share_run/shrink-files"   # what was picked in Files for shrinking, one path per line, for the Palette

# share_kind <file>: photo, video, or nothing, by its name's ending. A GIF, a RAW or a "(small)" copy is left alone.
share_kind() {
  local l; l=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$l" in *" (small)."* | *" (small "[0-9]*")."*) return 0 ;; esac
  case "$l" in
    *.heic|*.heif|*.jpg|*.jpeg|*.png|*.webp|*.tif|*.tiff|*.avif) echo photo ;;
    *.mov|*.mp4|*.m4v|*.mkv|*.webm|*.avi|*.3gp|*.mts) echo video ;;
  esac
  return 0
}
# share_small_name <file>: where its smaller copy goes, next to it: "IMG_0042 (small).jpg", "clip (small).mp4".
# A name already taken (an earlier copy, or "IMG_0042.heic" beside "IMG_0042.png") gets a number: "(small 2)".
share_small_name() {
  local d b e out n=2; d=$(dirname "$1"); b=$(basename "$1"); b=${b%.*}
  case "$(share_kind "$1")" in photo) e=jpg ;; video) e=mp4 ;; *) return 0 ;; esac
  out="$d/$b (small).$e"
  while [[ -e "$out" ]]; do out="$d/$b (small $n).$e"; n=$((n + 1)); done
  printf '%s' "$out"
}
# share_counted <photos> <videos>: "3 photos", "a video", "2 photos and a video".
share_counted() {
  local p="" v=""
  case "$1" in 0) ;; 1) p="a photo" ;; *) p="$1 photos" ;; esac
  case "$2" in 0) ;; 1) v="a video" ;; *) v="$2 videos" ;; esac
  if [[ -n "$p" && -n "$v" ]]; then printf '%s and %s' "$p" "$v"; else printf '%s%s' "$p" "$v"; fi
}

# --- LocalSend ---

# How LocalSend starts here: flatpak (from Flathub, as Takumi gets it) or the name of a LocalSend installed another
# way. Fails when there is none.
share_localsend() {
  if command -v flatpak >/dev/null && flatpak info "$share_app" >/dev/null 2>&1; then echo flatpak; return 0; fi
  local b; for b in localsend_app localsend; do command -v "$b" >/dev/null && { echo "$b"; return 0; }; done
  return 1
}
share_running() { pgrep -u "$(id -u)" -x 'localsend|localsend_app' >/dev/null 2>&1; }

# share_launch [--hidden] [file...]: start LocalSend, or hand the files to the one already running, which shows its
# window with them on the Send page. Files reach the Flatpak through the document portal (--file-forwarding), so it
# can read them wherever they are.
share_launch() {
  local how hidden=() files=()
  how=$(share_localsend) || return 1
  if [[ "${1:-}" == --hidden ]]; then hidden=(--hidden); shift; fi
  if (( $# )); then files=("$@"); fi
  if [[ $how == flatpak ]]; then
    if (( ${#files[@]} )); then
      flatpak run --file-forwarding "$share_app" ${hidden[@]+"${hidden[@]}"} @@ "${files[@]}" @@
    else
      flatpak run "$share_app" ${hidden[@]+"${hidden[@]}"}
    fi
  else
    "$how" ${hidden[@]+"${hidden[@]}"} ${files[@]+"${files[@]}"}
  fi
}

# Where LocalSend keeps its settings and the list of what it received.
share_prefs() {
  local f
  for f in "$HOME/.var/app/$share_app/data/$share_app/shared_preferences.json" "${XDG_DATA_HOME:-$HOME/.local/share}/$share_app/shared_preferences.json"; do
    [[ -f "$f" ]] && { printf '%s' "$f"; return 0; }
  done
  printf '%s' "$HOME/.var/app/$share_app/data/$share_app/shared_preferences.json"
}

# What LocalSend received, one line each: id <tab> file or message <tab> sender <tab> name (a message's text) <tab>
# path (none for a message: last, since read joins empty fields). LocalSend keeps each entry as JSON in a string.
share_received() {
  jq -r '(.["flutter.ls_receive_history"] // [])[] | (try fromjson catch null) | (if type == "string" then (try fromjson catch null) else . end)
    | select(type == "object")
    | [(.id // ""), (if .isMessage == true then "message" else "file" end), (.senderAlias // "someone nearby"), (.fileName // ""), (.path // "")]
    | map(tostring | gsub("[\t\n\r]"; " ")) | @tsv' "$(share_prefs)" 2>/dev/null || true
}

# The name this computer shows to phones and computers nearby in LocalSend.
share_alias() { jq -r '.["flutter.ls_alias"] // empty' "$(share_prefs)" 2>/dev/null || true; }

# --- Your phone, through KDE Connect ---

phone_unit=takumi-phone.service
phone_have() { command -v kdeconnect-cli >/dev/null && command -v kdeconnectd >/dev/null; }
# KDE Connect over D-Bus, never starting it: it runs in takumi-phone.service or not at all.
phone_bus() { busctl --user --auto-start=no --json=short "$@" 2>/dev/null; }
phone_up() { phone_bus call org.kde.kdeconnect /modules/kdeconnect org.kde.kdeconnect.daemon devices bb false false >/dev/null; }

phone_prop() {  # <device id> <property> [plugin]: a property of a device, or of one of its plugins (battery)
  local path="/modules/kdeconnect/devices/$1" iface=org.kde.kdeconnect.device
  if [[ -n "${3:-}" ]]; then path+="/$3"; iface+=".$3"; fi
  phone_bus get-property org.kde.kdeconnect "$path" "$iface" "$2" | jq -r '.data // empty' 2>/dev/null || true
}

# Every device KDE Connect knows or sees, one line each: id <tab> name <tab> paired (0/1) <tab> reachable (0/1)
# <tab> asks to pair (0/1) <tab> type (smartphone, tablet, desktop, laptop, tv).
phone_devices() {
  local names reach paired id name p r a
  names=$(phone_bus call org.kde.kdeconnect /modules/kdeconnect org.kde.kdeconnect.daemon deviceNames bb false false |
    jq -r '.data[0] // {} | to_entries[] | [.key, (.value | gsub("[\t\n]"; " "))] | @tsv' 2>/dev/null || true)
  [[ -n "$names" ]] || return 0
  reach=$(phone_bus call org.kde.kdeconnect /modules/kdeconnect org.kde.kdeconnect.daemon devices bb true false | jq -r '.data[0][]?' 2>/dev/null || true)
  paired=$(phone_bus call org.kde.kdeconnect /modules/kdeconnect org.kde.kdeconnect.daemon devices bb false true | jq -r '.data[0][]?' 2>/dev/null || true)
  while IFS=$'\t' read -r id name; do
    [[ -n "$id" ]] || continue
    p=0; r=0; a=0
    grep -qxF -- "$id" <<< "$paired" && p=1
    grep -qxF -- "$id" <<< "$reach" && r=1
    [[ $p == 0 && "$(phone_prop "$id" isPairRequestedByPeer)" == true ]] && a=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "$p" "$r" "$a" "$(phone_prop "$id" type)"
  done <<< "$names"
}

# phone_pick [id]: sets phone_id and phone_name to the phone a command acts on: the one named, else the paired one
# that is connected, else the first paired one. Fails when no phone is paired.
phone_pick() {
  local line
  phone_id="" phone_name=""
  line=$(phone_devices | awk -F'\t' -v want="${1:-}" '
    $3 == 1 && (want == "" || $1 == want || tolower($2) == tolower(want)) { if ($4 == 1 && !r) { r = $0 } else if (!f) { f = $0 } }
    END { if (r) print r; else if (f) print f }')
  [[ -n "$line" ]] || return 1
  phone_id=$(cut -f1 <<< "$line"); phone_name=$(cut -f2 <<< "$line")
  [[ "$(cut -f4 <<< "$line")" == 1 ]] && phone_near=yes || phone_near=no
  return 0
}

# phone_start: KDE Connect running, as this user's service, once a phone was paired (takumi phone pair enables the
# service; forgetting the last phone disables it). Waits up to ten seconds for it to answer.
phone_start() {
  local _
  phone_up && return 0
  systemctl --user is-enabled --quiet "$phone_unit" 2>/dev/null || return 1
  systemctl --user start "$phone_unit" >/dev/null 2>&1 || return 1
  for _ in 1 2 3 4 5 6 7 8 9 10; do phone_up && return 0; sleep 1; done
  return 1
}
