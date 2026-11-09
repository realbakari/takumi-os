#!/usr/bin/env bash
# Backups through restic, for commands/backup/* and the Palette's backup rows. Sourced, not run; bash 3.2 (the tests
# use fake restic, rclone, udisksctl, lsblk and secret-tool on macOS). See docs/backup.md.
#
# Where backups go and what they skip is ~/.config/takumi/backup.toml. The repository is encrypted with a key that
# lives in the login keyring (secret-tool, service takumi-backup) and on the card shown once at setup. restic asks
# the keyring for it with --password-command, so the key is never on a command line, in the environment or in a file.

backup_config="$HOME/.config/takumi/backup.toml"
backup_state="$HOME/.local/state/takumi/backup"
backup_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}/takumi"
backup_dir_name="Takumi Backups"        # the folder on the disk or in the cloud; inside it, one folder per computer
backup_open="$HOME/Backups"             # where takumi backup restore shows the backups, one folder per date
backup_cloud_remote=takumi-backup       # the rclone remote Takumi makes when it signs in to a cloud
backup_restore_unit=takumi-backup-restore
backup_ask_key="secret-tool lookup service takumi-backup"
backup_repo="" backup_mountpoint="" backup_we_mounted=no
place_kind="" place_name="" place_disk="" place_remote="" place_folder=""

# The clouds Takumi signs in to through rclone, which asks in the browser: id|rclone type|name|settings.
# Google Drive gets drive.file: rclone sees only the files it made, never the rest of the drive.
backup_clouds() {
  printf '%s\n' "google-drive|drive|Google Drive|scope=drive.file" "dropbox|dropbox|Dropbox|" "onedrive|onedrive|OneDrive|" \
    "pcloud|pcloud|pCloud|" "box|box|Box|"
}
backup_cloud() { backup_clouds | awk -F'|' -v id="$1" '$1 == id { print; found = 1 } END { exit !found }'; }

# backup_rclone_type <remote>: its type (drive, dropbox, ...), or nothing when rclone has no such remote.
backup_rclone_type() {
  rclone listremotes --long 2>/dev/null | awk -v n="$1:" 'index($0, n) == 1 { t = substr($0, length(n) + 1); gsub(/^[ \t]+|[ \t]+$/, "", t); print t; exit }'
  return 0
}

# backup_signin <remote> <rclone type> <name> <settings> <log>: makes the rclone remote by signing in, rclone's own way:
# it serves a page on this computer and opens it with xdg-open, which here is Takumi's (gio open, and a note of the
# address, so the Core can show it when no browser came up). Talks through lib/core.sh, and ends the command with
# core_fail 6 when signing in does not finish. Also used by takumi drive cloud (docs/drives.md). The caller's exit
# trap kills $backup_signin_pid, so rclone never outlives a conversation that was stopped.
backup_signin_pid=""
backup_signin() {
  local remote=$1 ctype=$2 name=$3 csettings=$4 log=$5 shim url start told rc settings=()
  shim="$backup_run/signin-$remote"; rm -rf "$shim"; mkdir -p "$shim"
  printf '#!/bin/sh\nprintf "%%s\\n" "$1" >> "%s/opened"\ngio open "$1" >/dev/null 2>&1 || exec /usr/bin/xdg-open "$1"\n' "$shim" > "$shim/xdg-open"
  chmod +x "$shim/xdg-open"
  rclone config delete "$remote" >/dev/null 2>&1 || true
  [[ -z "$csettings" ]] || read -r -a settings <<< "$csettings"
  PATH="$shim:$PATH" rclone config create "$remote" "$ctype" ${settings[@]+"${settings[@]}"} > "$shim/out" 2>&1 &
  backup_signin_pid=$!
  core_note "Opening $name in your browser…"
  url="" start=$(date +%s) told=no
  while kill -0 "$backup_signin_pid" 2>/dev/null; do
    [[ -n "$url" ]] || url=$(grep -m 1 -oE 'http://127\.0\.0\.1:[0-9]+/auth\?state=[A-Za-z0-9_-]+' "$shim/out" 2>/dev/null || true)
    if [[ -n "$url" && $told == no ]]; then core_note "Sign in to $name in your browser, then allow rclone"; told=yes; fi
    if [[ -n "$url" && $told == yes ]] && (( $(date +%s) - start > 20 )); then core_note "Waiting for $name. No browser? Open $url"; told=late; fi
    if (( $(date +%s) - start > 600 )); then core_fail 6 "Signing in to $name took too long. Choose it again to try once more."; fi
    sleep 1
  done
  rc=0; wait "$backup_signin_pid" || rc=$?; backup_signin_pid=""
  cat "$shim/out" >> "$log" 2>/dev/null || true
  rm -rf "$shim"
  (( rc == 0 )) || core_fail 6 "Signing in to $name did not finish. Choose it again to try once more."
  rclone lsd "$remote:" --max-depth 1 >/dev/null 2>> "$log" || core_fail 6 "$name did not answer after signing in. Choose it again to try once more."
}

# --- backup.toml: [place] is where backups go, written by takumi backup setup; [skip] is the person's own list ---

# A home made before backups existed has no backup.toml: it gets the one Takumi ships.
backup_seed() {
  [[ -f "$backup_config" ]] && return 0
  local s here
  here=$(dirname "${BASH_SOURCE[0]}")
  for s in /usr/share/takumi/config/takumi/backup.toml "$here/../config/takumi/backup.toml"; do
    [[ -f "$s" ]] && { mkdir -p "$(dirname "$backup_config")"; cp "$s" "$backup_config"; return 0; }
  done
  mkdir -p "$(dirname "$backup_config")"
  printf '[place]\nkind = ""\nname = ""\ndisk = ""\nremote = ""\nfolder = ""\n\n[skip]\nfolders = [\n  ".cache",\n  ".local/share/Trash",\n]\n' > "$backup_config"
}

backup_get() {  # <key>: a value from [place]
  [[ -f "$backup_config" ]] || return 0
  sed -n '/^\[place\]/,/^\[/s/^'"$1"' *= *"\([^"]*\)".*/\1/p' "$backup_config" | head -n 1
}

# Sets place_kind (disk, cloud or nothing), place_name, place_disk (a filesystem's UUID), place_remote (rclone) and
# place_folder (the folder that holds this computer's backups, from the top of the disk or the remote).
backup_load() {
  place_kind=$(backup_get kind); place_name=$(backup_get name); place_disk=$(backup_get disk)
  place_remote=$(backup_get remote); place_folder=$(backup_get folder)
  case "$place_kind" in disk|cloud) ;; *) place_kind="" ;; esac
  [[ -n "$place_name" ]] || place_name="the backup disk"
}

# backup_set_place <kind> <name> <disk> <remote> <folder>: rewrites [place] only, keeping the rest of the file as it is.
backup_set_place() {
  backup_seed
  local tmp="$backup_config.tmp" v=() a
  for a in "$@"; do v+=("$(printf '%s' "$a" | tr -d '"\\' | tr '\n\t' '  ')"); done
  {
    printf '[place]\n'
    printf 'kind = "%s"%*s# disk or cloud; empty while backups are off\n' "${v[0]}" $(( 12 - ${#v[0]} > 1 ? 12 - ${#v[0]} : 1 )) ""
    printf 'name = "%s"\n' "${v[1]}"
    printf 'disk = "%s"\n' "${v[2]}"
    printf 'remote = "%s"\n' "${v[3]}"
    printf 'folder = "%s"\n' "${v[4]}"
  } > "$tmp.place"
  awk -v place="$tmp.place" '
    function block(  l) { while ((getline l < place) > 0) print l; close(place) }
    /^\[place\]/ { block(); done = 1; skip = 1; next }
    /^\[/ { if (skip) { skip = 0; print "" } }
    !skip { print }
    END { if (!done) { print ""; block() } }' "$backup_config" > "$tmp"
  mv "$tmp" "$backup_config"
  rm -f "$tmp.place"
}

# The folders that are not backed up, one per line, from the home folder. Each is a quoted string in the folders
# list of [skip]; a # outside quotes starts a comment.
backup_skips() {
  [[ -f "$backup_config" ]] || return 0
  awk '
    /^folders[ \t]*=[ \t]*\[/ { on = 1 }
    on {
      s = $0; out = ""; q = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q) { if (c == "\"") { if (out != "") print out; out = ""; q = 0 } else out = out c }
        else if (c == "\"") q = 1
        else if (c == "#") break
        else if (c == "]") { on = 0; break }
      }
    }' "$backup_config"
}

# backup_excludes <file>: restic's exclude patterns, each anchored at the home folder. The folder where restore shows
# the backups is never backed up.
backup_excludes() {
  { backup_skips; echo Backups; } | while IFS= read -r f; do
    f=${f#./}; f=${f#/}; f=${f%/}
    [[ -n "$f" ]] && printf '%s/%s\n' "$HOME" "$f"
  done > "$1"
}

# --- Words ---

backup_size() {  # <bytes>: "41 GB", "1.5 TB", "820 MB", with a point whatever the language
  LC_ALL=C awk -v b="${1:-0}" 'BEGIN {
    split("bytes KB MB GB TB PB", u, " "); i = 1
    while (b >= 1000 && i < 6) { b /= 1000; i++ }
    if (i == 1) printf "%d bytes", b
    else if (b < 10) { s = sprintf("%.1f", b); sub(/\.0$/, "", s); printf "%s %s", s, u[i] }
    else printf "%d %s", int(b + 0.5), u[i] }'
}

backup_date() { date -d "@$1" "+$2" 2>/dev/null || date -r "$1" "+$2"; }   # <epoch> <format>

backup_ago() {  # <epoch> [now]: "just now", "3 min ago", "2 h ago", "today at 07:10", "yesterday at 14:30", "on 3 Nov"
  local then=$1 now=${2:-$(date +%s)} d
  d=$(( now - then ))
  if (( d < 60 )); then echo "just now"
  elif (( d < 3600 )); then echo "$(( d / 60 )) min ago"
  elif (( d < 12 * 3600 )); then echo "$(( d / 3600 )) h ago"
  elif [[ "$(backup_date "$then" %F)" == "$(backup_date "$now" %F)" ]]; then echo "today at $(backup_date "$then" %H:%M)"
  elif [[ "$(backup_date "$then" %F)" == "$(backup_date $(( now - 86400 )) %F)" ]]; then echo "yesterday at $(backup_date "$then" %H:%M)"
  elif [[ "$(backup_date "$then" %Y)" == "$(backup_date "$now" %Y)" ]]; then echo "on $(backup_date "$then" '%d %b' | sed 's/^0//')"
  else echo "on $(backup_date "$then" '%d %b %Y' | sed 's/^0//')"; fi
}

# This computer's folder name: its host name, with anything but letters, digits, dots, dashes and underscores made a dash.
backup_host() { local h; h=$(uname -n 2>/dev/null || echo computer); h=${h%%.*}; printf '%s' "${h:-computer}" | tr -c 'A-Za-z0-9._-' '-'; }

# --- Disks, through udisks2 ---

# USB and other removable disks that hold a filesystem of 1 GB or more, one JSON object per line:
# {uuid, path, fstype, name, model, size, sizeText, mountpoint, free, freeText, ok, why}. ok is false, with why in
# words, for a disk this computer cannot write to (a Mac's, a locked one). A disk the system runs from never shows.
backup_disks() {
  command -v lsblk >/dev/null || return 0
  lsblk -J -b -o PATH,TYPE,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT,FSAVAIL,TRAN,RM,HOTPLUG,MODEL,VENDOR 2>/dev/null | jq -c '
    def yes: . == true or . == "1" or . == 1;
    def num: if type == "number" then . elif type == "string" and test("^[0-9]+$") then tonumber else 0 end;
    def words: (. // "") | tostring | gsub("^\\s+|\\s+$"; "") | gsub("\\s+"; " ");
    def bytes: if . >= 1e12 then ((. / 1e11 | floor) / 10 | tostring | sub("\\.0$"; "")) + " TB"
               elif . >= 1e9 then ((. / 1e9 + 0.5 | floor) | tostring) + " GB"
               else ((. / 1e6 + 0.5 | floor) | tostring) + " MB" end;
    def writable: IN("ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "exfat", "vfat", "ntfs", "ntfs3");
    def why: if IN("apfs", "hfsplus", "hfs") then "It is formatted for a Mac, and this computer cannot write to that"
             elif . == "crypto_LUKS" then "It is encrypted: open it in Files first"
             elif . == "BitLocker" then "It is locked with BitLocker"
             else "This computer cannot write to its format (" + . + ")" end;
    .blockdevices[]? | select(.type == "disk") | select((.tran // "") == "usb" or (.rm | yes) or (.hotplug | yes))
    | . as $d
    | [$d, (($d.children // [])[]), (($d.children // [])[] | (.children // [])[])] as $all
    | select($all | map(.mountpoint // "") | any(IN("/", "/efi", "/boot", "/home", "[SWAP]")) | not)
    | ([$d.vendor, $d.model] | map(words) | map(select(. != "")) | join(" ")) as $model
    | $all[]
    | select((.fstype // "") != "" and (.uuid // "") != "" and (.size | num) >= 1e9)
    | select(.fstype | IN("swap", "iso9660", "udf", "squashfs", "LVM2_member", "linux_raid_member", "zfs_member") | not)
    | select((.fstype == "crypto_LUKS" and ((.children // []) | length) > 0) | not)
    | . as $p
    | {uuid: $p.uuid, path: $p.path, fstype: $p.fstype,
       name: (($p.label | words) as $l | if $l != "" then $l elif $model != "" then $model else "USB disk" end),
       model: $model, size: ($p.size | num), sizeText: ($p.size | num | bytes), mountpoint: ($p.mountpoint // ""),
       free: ($p.fsavail | num), freeText: (if $p.fsavail == null then "" else ($p.fsavail | num | bytes) end),
       ok: ($p.fstype | writable), why: (if ($p.fstype | writable) then "" else ($p.fstype | why) end)}'
}

backup_disk() { backup_disks | jq -c --arg u "$1" 'select(.uuid == $u)'; }   # <uuid>: that disk, when it is plugged in

# The disk in words: "1 TB, 820 GB free", or "1 TB" when it is not open yet.
backup_disk_words() { jq -r '.sizeText + (if .freeText != "" then ", " + .freeText + " free" else "" end)' <<< "$1"; }

# backup_mount <uuid> [ask|wait]: sets backup_mountpoint, opening the disk through udisks2 when nobody has; then
# backup_we_mounted is yes. ask lets udisks2 ask for a password in the Core; wait gives a disk that was just plugged
# in ten seconds to settle. Fails when the disk is not here or will not open.
backup_mount() {
  local d mp try out
  backup_mountpoint=""
  for try in 1 2 3 4 5 6 7 8 9 10; do
    d=$(backup_disk "$1")
    [[ -n "$d" || "${2:-}" == wait ]] || return 1
    if [[ -n "$d" ]]; then
      mp=$(jq -r .mountpoint <<< "$d")
      [[ -n "$mp" ]] && { backup_mountpoint=$mp; return 0; }
      if [[ "${2:-}" == ask ]]; then out=$(udisksctl mount -b "$(jq -r .path <<< "$d")" 2>&1) || out=""
      else out=$(udisksctl mount --no-user-interaction -b "$(jq -r .path <<< "$d")" 2>&1) || out=""; fi
      if [[ -n "$out" ]]; then
        backup_we_mounted=yes
        mp=$(backup_disk "$1" | jq -r .mountpoint)
        [[ -n "$mp" ]] || mp=$(sed -n 's/^Mounted .* at \(.*\)$/\1/p' <<< "$out" | sed 's/\.$//')
        [[ -n "$mp" ]] && { backup_mountpoint=$mp; return 0; }
      fi
    fi
    [[ "${2:-}" == wait ]] || return 1
    sleep 1
  done
  return 1
}

backup_unmount() {  # <uuid>: close the disk, when udisks2 opened it for a backup
  local d; d=$(backup_disk "$1")
  [[ -n "$d" ]] && udisksctl unmount --no-user-interaction -b "$(jq -r .path <<< "$d")" >/dev/null 2>&1 || true
}

# backup_locate [ask|wait]: sets backup_repo, the restic repository for [place], opening the disk when it must.
# 0 ready, 3 the disk is not plugged in, 4 it is here but would not open.
backup_locate() {
  backup_repo=""
  case "$place_kind" in
    disk)
      [[ -n "$(backup_disk "$place_disk")" || "${1:-}" == wait ]] || return 3
      backup_mount "$place_disk" "${1:-}" || { [[ -n "$(backup_disk "$place_disk")" ]] && return 4; return 3; }
      backup_repo="$backup_mountpoint/$place_folder" ;;
    cloud) backup_repo="rclone:$place_remote:$place_folder" ;;
    *) return 1 ;;
  esac
}

# --- The key ---

# restic with this home's repository, the key coming from the keyring.
backup_restic() { RESTIC_PROGRESS_FPS=${RESTIC_PROGRESS_FPS:-0.2} restic --repo "$backup_repo" --password-command "$backup_ask_key" "$@"; }
# backup_restic_typed <key> <args...>: restic with a key the person typed, handed over on a pipe.
backup_restic_typed() { local k=$1; shift; restic --repo "$backup_repo" --password-file <(printf '%s' "$k") "$@"; }

backup_key_store() { secret-tool store --label="Takumi backup key" service takumi-backup 2>/dev/null; }   # the key on stdin
backup_key_have() { secret-tool lookup service takumi-backup >/dev/null 2>&1; }
backup_key_forget() { secret-tool clear service takumi-backup >/dev/null 2>&1 || true; }

# 32 digits in eight groups of four (106 bits): every keyboard types digits, none is mistaken for a letter, and the
# shape is never mistaken for the disk's recovery code (six groups of six). The key itself is the digits alone.
backup_new_key() {
  local d="" b
  while (( ${#d} < 32 )); do
    for b in $(od -An -tu1 -N64 /dev/urandom); do
      if (( b < 250 && ${#d} < 32 )); then d+=$(( b % 10 )); fi
    done
  done
  printf '%s' "$d"
}
backup_key_shown() { local k=$1; printf '%s-%s-%s-%s-%s-%s-%s-%s' "${k:0:4}" "${k:4:4}" "${k:8:4}" "${k:12:4}" "${k:16:4}" "${k:20:4}" "${k:24:4}" "${k:28:4}"; }
# What a person typed: a key's 32 digits, with or without dashes and spaces; anything else as it was typed.
backup_key_typed() {
  local k; k=$(printf '%s' "$1" | tr -d ' -')
  if [[ "$k" =~ ^[0-9]{32}$ ]]; then printf '%s' "$k"; else printf '%s' "$1"; fi
}

# backup_card <kicker> <title> <detail> <key>: the card the Core shows once, with the key behind Enter and as a code a
# phone camera keeps. The key reaches qrencode and jq on stdin, never as an argument.
backup_card() {
  local qr=""
  if command -v qrencode >/dev/null; then qr=$(printf '%s' "$4" | qrencode -t ASCII -m 0 -o - 2>/dev/null | sed 's/##/1/g; s/  /0/g' || true); fi
  { printf '%s\n%s\n%s\n' "$1" "$2" "$3"; backup_key_shown "$4"; printf '\n%s\n' "$qr"; } | jq -Rsc 'split("\n") as $l
    | {kicker: $l[0], title: $l[1], detail: $l[2], secretLabel: "Key", secret: $l[3], qr: ($l[4:] | map(select(length > 0)))}'
}

# --- What happened ---

backup_stamp() { mkdir -p "$backup_state"; date +%s > "$backup_state/$1"; }   # seen, reminded, pruned, said
backup_age() {  # <stamp>: seconds since it was written; a very long time when it never was
  local t; t=$(cat "$backup_state/$1" 2>/dev/null || true)
  [[ "$t" =~ ^[0-9]+$ ]] || t=0
  echo $(( $(date +%s) - t ))
}
backup_last() { jq -r --arg f "$1" '.[$f] // empty' "$backup_state/last.json" 2>/dev/null || true; }   # when, bytes, files, snapshot

# One backup at a time; a lock left by a run that died is taken over.
backup_lock() {
  local pid
  mkdir -p "$backup_run"
  if mkdir "$backup_run/backup.lock" 2>/dev/null; then echo $$ > "$backup_run/backup.lock/pid"; return 0; fi
  pid=$(cat "$backup_run/backup.lock/pid" 2>/dev/null || true)
  [[ -z "$pid" ]] && return 1
  kill -0 "$pid" 2>/dev/null && return 1
  rm -rf "$backup_run/backup.lock"
  mkdir "$backup_run/backup.lock" 2>/dev/null || return 1
  echo $$ > "$backup_run/backup.lock/pid"
}
backup_unlock() { rm -rf "$backup_run/backup.lock"; }

# The backup running now, {pid, started, percent, place}, or nothing.
backup_running() {
  local f="$backup_run/backup.json" pid
  [[ -f "$f" ]] || return 1
  pid=$(jq -r '.pid // empty' "$f" 2>/dev/null || true)
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 1
  cat "$f"
}

backup_restore_open() { systemctl --user is-active --quiet "$backup_restore_unit" 2>/dev/null; }

# backup_words <restic exit status> <log>: what went wrong, in words.
backup_words() {
  case "$1" in
    10) echo "The backups on $place_name are missing"; return ;;
    11) echo "$place_name is busy with another backup; it tries again later"; return ;;
    12) echo "The key in your keyring does not open the backups on $place_name"; return ;;
  esac
  local first
  if grep -qi 'no space left' "$2" 2>/dev/null; then echo "$place_name is full"
  elif grep -qiE 'wrong password|no key found' "$2" 2>/dev/null; then echo "The key in your keyring does not open the backups on $place_name"
  elif grep -qiE 'password.command|secret-tool' "$2" 2>/dev/null; then echo "Your keyring did not give the backup key"
  elif grep -qiE 'repository does not exist|unable to open config file|is there a repository' "$2" 2>/dev/null; then echo "The backups on $place_name are missing"
  elif grep -qiE 'dial tcp|no such host|network is unreachable|connection refused|i/o timeout|couldn.t connect|failed to create file system' "$2" 2>/dev/null; then echo "$place_name could not be reached"
  else
    first=$(grep -m 1 -iE '^(fatal|error)' "$2" 2>/dev/null | sed 's/^[Ff]atal: //; s/^[Ee]rror: //' | cut -c 1-100 || true)
    echo "The backup did not finish${first:+: $first}"
  fi
}

# The backup trigger: a link that starts takumi-backup.service when the backup disk is plugged in. systemd starts what
# a device unit wants as the device appears; device units have no file, so the link is made by hand.
backup_trigger_on() {  # <uuid>
  local u
  u=$(systemd-escape --path --suffix=device "/dev/disk/by-uuid/$1" 2>/dev/null) || return 0
  [[ -n "$u" ]] || return 0
  mkdir -p "$HOME/.config/systemd/user/$u.wants"
  ln -sf /usr/lib/systemd/user/takumi-backup.service "$HOME/.config/systemd/user/$u.wants/takumi-backup.service"
}
backup_trigger_off() {
  local w
  for w in "$HOME/.config/systemd/user/"dev-disk-by*.device.wants; do
    [[ -L "$w/takumi-backup.service" || -e "$w/takumi-backup.service" ]] || continue
    rm -f "$w/takumi-backup.service"
    rmdir "$w" 2>/dev/null || true
  done
}

# Where backups stand, as one JSON object for takumi backup status and the Palette:
# {setup, place, kind, state (off, running, done, never), line, detail, when, bytes, percent, present, problem, open}.
backup_status_json() {
  backup_load
  if [[ -z "$place_kind" ]]; then
    jq -cn '{setup: false, state: "off", line: "Backups are off", detail: "Set them up to back up every hour, to a USB disk or a cloud"}'
    return 0
  fi
  local running last when ago="" present=null open=false problem
  running=$(backup_running || true)
  last=$(cat "$backup_state/last.json" 2>/dev/null || true)
  jq -e 'type == "object"' >/dev/null 2>&1 <<< "${running:-0}" || running=""
  jq -e 'type == "object"' >/dev/null 2>&1 <<< "${last:-0}" || last=""
  when=$(backup_last when)
  [[ -n "$when" ]] && ago=$(backup_ago "$when")
  problem=$(cat "$backup_state/problem" 2>/dev/null || true)
  if [[ $place_kind == disk ]]; then
    if [[ -n "$(backup_disk "$place_disk")" ]]; then present=true; else present=false; fi
  fi
  if backup_restore_open; then open=true; fi
  jq -cn --arg place "$place_name" --arg kind "$place_kind" --arg ago "$ago" --arg problem "$problem" \
    --argjson running "${running:-null}" --argjson last "${last:-null}" --argjson present "$present" --argjson open "$open" \
    --arg size "$(backup_size "$(backup_last bytes)")" '
    (if $running != null then "running" elif $last != null then "done" else "never" end) as $state
    | {setup: true, place: $place, kind: $kind, state: $state, present: $present, open: $open, problem: $problem,
       when: ($last.when // null), bytes: ($last.bytes // null), percent: ($running.percent // null),
       line: (if $state == "running" then "Backing up · " + (($running.percent // 0) | tostring) + "%"
              elif $state == "done" then "Backed up " + $ago + " · " + $size
              else "Not backed up yet" end),
       detail: (if $present == false then "Waiting for " + $place + ": plug it in to back up"
                elif $problem != "" and $state != "running" then $problem
                else "On " + $place + ", every hour on the charger" end)}'
}
