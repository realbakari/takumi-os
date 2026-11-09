#!/usr/bin/env bash
# Power: profiles, the battery, staying awake, when the screen locks and the computer sleeps, the lid, hibernation
# and the charge limit. Sourced by commands/power/* and the Palette's power rows; runs on bash 3.2. See
# docs/power.md.
#
# What a person chose is in ~/.config/takumi/power.toml, written whole: a profile and idle times for
# battery and for power. A laptop changes profile and idle times by itself when it is plugged in or
# unplugged (takumi power battery, every two minutes, and at once when asked). The lid, what sleep means,
# hibernation and the charge limit are the computer's, kept in system files (below).

power_config="$HOME/.config/takumi/power.toml"
power_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
power_supply="${TAKUMI_POWER_SUPPLY:-/sys/class/power_supply}"

# power_battery: "<percent> <charging|discharging|full|unknown> <minutes left or -1>" for the first battery,
# or nothing on a computer without one. Minutes come from the battery's own energy and power figures.
power_battery() {
  local b cap st e p m=-1
  for b in "$power_supply"/BAT*; do
    [[ -r "$b/capacity" ]] || continue
    cap=$(cat "$b/capacity"); st=$(tr '[:upper:]' '[:lower:]' < "$b/status" 2>/dev/null || echo unknown)
    case "$st" in "not charging") st=full ;; esac
    e=$(cat "$b/energy_now" 2>/dev/null || cat "$b/charge_now" 2>/dev/null || echo 0)
    p=$(cat "$b/power_now" 2>/dev/null || cat "$b/current_now" 2>/dev/null || echo 0)
    if [[ "$st" == discharging ]] && (( p > 0 )); then m=$(( e * 60 / p )); fi
    printf '%s %s %s\n' "$cap" "$st" "$m"
    return 0
  done
}

# power_source: battery or power. A computer with no battery is always on power.
power_source() {
  local a
  for a in "$power_supply"/A* "$power_supply"/*AC*; do
    [[ -r "$a/online" ]] || continue
    [[ "$(cat "$a/online")" == 1 ]] && { echo power; return; }
    echo battery; return
  done
  [[ -n "$(power_battery)" && "$(power_battery | cut -d' ' -f2)" == discharging ]] && { echo battery; return; }
  echo power
}

# power_duration <minutes>: "2 h 10 min", "45 min".
power_duration() {
  local h=$(( $1 / 60 )) m=$(( $1 % 60 ))
  if (( h > 0 )); then printf '%s h %s min' "$h" "$m"; else printf '%s min' "$m"; fi
}

# power_setting <table> <key> <default>: from power.toml.
power_setting() {
  local v=""
  [[ -f "$power_config" ]] && v=$(sed -n "/^\[$1\]/,/^\[/s/^$2 *= *\"\{0,1\}\([A-Za-z0-9.-]*\).*/\1/p" "$power_config" | head -n 1)
  printf '%s' "${v:-$3}"
}
power_profile_for() { if [[ "$1" == battery ]]; then power_setting profile battery power-saver; else power_setting profile power balanced; fi; }
power_lock_after()  { if [[ "$1" == battery ]]; then power_setting battery lock 10; else power_setting power lock 20; fi; }
power_sleep_after() { if [[ "$1" == battery ]]; then power_setting battery sleep 30; else power_setting power sleep 0; fi; }

# power_save <key> <value>: change one value, writing the file whole so it always reads the same.
# Keys: profile.battery profile.power battery.lock battery.sleep power.lock power.sleep.
power_save() {
  local pb pp bl bs pl ps
  pb=$(power_profile_for battery); pp=$(power_profile_for power)
  bl=$(power_lock_after battery); bs=$(power_sleep_after battery); pl=$(power_lock_after power); ps=$(power_sleep_after power)
  case "$1" in
    profile.battery) pb=$2 ;; profile.power) pp=$2 ;;
    battery.lock) bl=$2 ;; battery.sleep) bs=$2 ;; power.lock) pl=$2 ;; power.sleep) ps=$2 ;;
    *) return 1 ;;
  esac
  mkdir -p "$(dirname "$power_config")"
  {
    printf '# Power, as set from the Core. See docs/power.md. Minutes; 0 means never.\n\n'
    printf '[profile]\nbattery = "%s"   # power-saver | balanced | performance\npower = "%s"\n\n' "$pb" "$pp"
    printf '[battery]\nlock = %s\nsleep = %s\n\n' "$bl" "$bs"
    printf '[power]\nlock = %s\nsleep = %s\n' "$pl" "$ps"
  } > "$power_config.tmp"
  mv "$power_config.tmp" "$power_config"
}

# power_profiles: the profiles this computer offers, one per line, the one in use marked with "*".
power_profiles() { powerprofilesctl list 2>/dev/null | sed -n 's/^\(\*\{0,1\}\) *\([a-z-]*\):$/\1\2/p'; }
power_profile_now() { powerprofilesctl get 2>/dev/null || true; }
power_profile_name() { case "$1" in power-saver) echo "Power saver" ;; balanced) echo Balanced ;; performance) echo Performance ;; *) echo "$1" ;; esac; }

# Staying awake: one background job holds the sleep inhibitor and keeps the idle watcher stopped; its
# marker holds "<pid> <until, epoch seconds>".
power_awake_marker="$power_run/takumi-awake"
power_awake_until() {
  local pid until
  [[ -r "$power_awake_marker" ]] && read -r pid until < "$power_awake_marker" || return 1
  kill -0 "$pid" 2>/dev/null || { rm -f "$power_awake_marker"; return 1; }
  printf '%s' "$until"
}
power_clock() { date -d "@$1" +%H:%M 2>/dev/null || date -r "$1" +%H:%M; }

# --- The lid and what sleep means ----------------------------------------------------------------------------
# These belong to the computer, not to one person, so they are system files changed with the password. Where the
# system's files are: / on a computer, a folder that pretends to be one in the tests.
power_root=${TAKUMI_POWER_ROOT:-}
power_lid_conf="$power_root/etc/systemd/logind.conf.d/takumi-lid.conf"
power_sleep_conf="$power_root/etc/systemd/sleep.conf.d/takumi.conf"
power_swapfile="$power_root/swap/swapfile"
power_charge_file="$power_root/var/lib/takumi/charge-limit"

# What closing the lid does is Takumi's logind drop-in, takumi-lid.conf: HandleLidSwitch for battery, and
# HandleLidSwitchExternalPower when plugged in has a choice of its own. "Sleep" is logind's sleep action, which
# does what SleepOperation= says: suspend, or suspend-then-hibernate when the computer hibernates after some hours
# asleep (HibernateDelaySec in Takumi's sleep.conf drop-in), falling back to suspend when it cannot hibernate.
# "Nothing" keeps the computer running and locks the screen.

# power_has_lid: true when an input device reports a lid switch (SW_LID, the lowest bit of its switch events).
power_has_lid() {
  awk '/^B: SW=/ { n = split(substr($0, 7), w, " "); if (index("13579bdfBDF", substr(w[n], length(w[n]), 1)) > 0) f = 1 }
       END { exit !f }' "$power_root/proc/bus/input/devices" 2>/dev/null
}

power_logind_get() { [[ -r "$power_lid_conf" ]] || return 0; sed -n "s/^$1=//p" "$power_lid_conf" | tail -n 1; }

# power_lid_choice <battery|power>: sleep, hibernate or nothing. Plugged in follows battery unless it has its own.
power_lid_choice() {
  local a c
  a=$(power_logind_get HandleLidSwitch)
  if [[ "$1" == power ]]; then c=$(power_logind_get HandleLidSwitchExternalPower); [[ -z "$c" ]] || a=$c; fi
  case "$a" in hibernate) echo hibernate ;; lock | ignore) echo nothing ;; *) echo sleep ;; esac
}
power_lid_own_charger() { [[ -n "$(power_logind_get HandleLidSwitchExternalPower)" ]]; }

# power_hibernate_after: the hours asleep before the computer hibernates, or nothing when sleep stays sleep.
power_hibernate_after() { [[ -r "$power_sleep_conf" ]] || return 0; sed -n 's/^HibernateDelaySec=\([0-9][0-9]*\)h$/\1/p' "$power_sleep_conf" | tail -n 1; }

# power_logind_sleeps: true when logind has its sleep action and SleepOperation= (systemd 256 and later).
power_logind_sleeps() {
  local v; v=$(systemctl --version 2>/dev/null | awk 'NR == 1 { print $2 + 0 }' || true)
  [[ "$v" =~ ^[0-9]+$ ]] && (( v >= 256 ))
}

# power_lid_action <sleep|hibernate|nothing> <logind's word for sleep>: logind's word for it.
power_lid_action() { case "$1" in hibernate) echo hibernate ;; nothing) echo lock ;; *) echo "$2" ;; esac; }

# power_logind_conf <on battery> <plugged in, or empty to follow battery> <hours asleep before hibernating, or
# empty>: takumi-lid.conf, whole. An older systemd gets the plain actions, without the fallback.
power_logind_conf() {
  local s=sleep new=yes
  if ! power_logind_sleeps; then new=no; if [[ -n "$3" ]]; then s=suspend-then-hibernate; else s=suspend; fi; fi
  printf '%s\n' "# Takumi: what closing the lid does, and what sleep means (docs/power.md). Written whole by takumi power" \
    "# lid, hibernate and hibernate-after; a setting of your own goes in a file of your own in this folder." \
    "[Login]" "HandleLidSwitch=$(power_lid_action "$1" "$s")"
  if [[ -n "$2" && "$2" != "$1" ]]; then printf 'HandleLidSwitchExternalPower=%s\n' "$(power_lid_action "$2" "$s")"; fi
  if [[ $new == no ]]; then return 0; fi
  if [[ -n "$3" ]]; then echo "SleepOperation=suspend-then-hibernate suspend"; else echo "SleepOperation=suspend"; fi
}

# power_sleep_text <hours>: Takumi's sleep.conf drop-in, whole.
power_sleep_text() {
  printf '%s\n' "# Takumi: how long the computer sleeps before it hibernates (takumi power hibernate-after, docs/power.md)." \
    "[Sleep]" "HibernateDelaySec=${1}h"
}

# power_sleep_verb: what systemctl is asked for to sleep. Once takumi-lid.conf says what sleep means, logind's own
# sleep (the same one the lid uses); on an older systemd, suspend-then-hibernate when sleep turns into
# hibernation; otherwise plain suspend.
power_sleep_verb() {
  if grep -qs '^SleepOperation=' "$power_lid_conf"; then echo sleep
  elif [[ -n "$(power_hibernate_after)" ]] && power_hibernate_ready; then echo suspend-then-hibernate
  else echo suspend; fi
}

# --- Hibernation ------------------------------------------------------------------------------------------------
# A swapfile the size of the memory in a Btrfs subvolume of its own, @swap, beside the rooms (a subvolume that
# holds a swapfile in use cannot be snapshotted), mounted at /swap; resume= and resume_offset= in
# /etc/kernel/cmdline, which every room's boot entry copies. The systemd initramfs wakes from it by itself, after
# the disk is unlocked when it is encrypted.

# power_swap_active: true when the hibernation swapfile is in use.
power_swap_active() { awk '$1 ~ /\/swap\/swapfile$/ { f = 1 } END { exit !f }' "$power_root/proc/swaps" 2>/dev/null; }

# power_hibernate_ready: true when the computer can hibernate now: the swapfile is in use and the kernel options
# say where to wake from.
power_hibernate_ready() {
  power_swap_active || return 1
  [[ " $(cat "$power_root/etc/kernel/cmdline" 2>/dev/null || true) " == *" resume="* ]]
}

# power_initramfs_systemd: true when the initramfs is the systemd one, which wakes from hibernation by itself.
power_initramfs_systemd() {
  (
    set +eu
    HOOKS=()
    # shellcheck source=/dev/null
    . "$power_root/etc/mkinitcpio.conf" >/dev/null 2>&1
    for f in "$power_root"/etc/mkinitcpio.conf.d/*.conf; do
      # shellcheck source=/dev/null
      if [[ -f "$f" ]]; then . "$f" >/dev/null 2>&1; fi
    done
    [[ " ${HOOKS[*]} " == *" systemd "* ]]
  )
}

# power_hibernate_unable: why hibernation cannot be set up on this computer, in words; nothing when it can.
power_hibernate_unable() {
  local lockdown
  if [[ "$(findmnt -no FSTYPE / 2>/dev/null || true)" != btrfs ]] || ! takumi room enabled >/dev/null 2>&1; then
    echo "Hibernation needs the disk layout a Takumi install has, and this computer does not have it"
  elif [[ "$(cat "$power_root/sys/power/state" 2>/dev/null || true)" != *disk* ]]; then
    lockdown=$(cat "$power_root/sys/kernel/security/lockdown" 2>/dev/null || true)
    if [[ "$lockdown" == *"[integrity]"* || "$lockdown" == *"[confidentiality]"* ]]; then
      echo "Secure Boot has locked this computer's system, and a locked system cannot hibernate"
    elif [[ " $(cat "$power_root/proc/cmdline" 2>/dev/null || true) " == *" nohibernate "* ]]; then
      echo "Hibernation is turned off in this computer's start options"
    else
      echo "This computer's system cannot hibernate"
    fi
  elif [[ -f "$power_root/etc/mkinitcpio.conf" ]] && ! power_initramfs_systemd; then
    echo "This computer starts in an older way that cannot wake from hibernation"
  fi
  return 0
}

# power_memory_gib: the memory in whole GiB, rounded up: the size of the swapfile hibernation needs.
power_memory_gib() {
  local g; g=$(awk '/^MemTotal:/ { print int(($2 + 1048575) / 1048576); exit }' "$power_root/proc/meminfo" 2>/dev/null || true)
  echo "${g:-0}"
}
# power_swapfile_gib: the swapfile's size in whole GiB; 0 when there is none. Read without opening it (it is root's).
power_swapfile_gib() {
  local s; s=$(ls -ln "$power_swapfile" 2>/dev/null | awk '{ print $5 }' || true)
  [[ "$s" =~ ^[0-9]+$ ]] || s=0
  echo $(( s / 1073741824 ))
}
# power_disk_free_gib: free space on the system disk, in whole GiB.
power_disk_free_gib() {
  local f; f=$(df -Pk "$power_root/" 2>/dev/null | awk 'NR == 2 { print int($4 / 1048576) }' || true)
  echo "${f:-0}"
}

# power_without_resume: kernel options on stdin, less the ones that say where to wake from hibernation.
power_without_resume() {
  awk '{ s = ""; for (i = 1; i <= NF; i++) if ($i !~ /^resume(_offset)?=/ && $i != "noresume") s = s (s == "" ? "" : " ") $i; print s }'
}

# --- The charge limit ---------------------------------------------------------------------------------------------
# The kernel holds a battery below full through charge_control_end_threshold where the laptop offers it. The
# choice is kept in /var/lib/takumi/charge-limit, which every room shares, and takumi-charge-limit.service sets it
# again at each start and after waking, because some laptops forget it.

# power_charge_batteries: the batteries whose charge can be held below full, one folder per line.
power_charge_batteries() {
  local b
  for b in "$power_supply"/*; do
    [[ -r "$b/charge_control_end_threshold" ]] || continue
    [[ "$(cat "$b/type" 2>/dev/null || echo Battery)" == Battery && "$(cat "$b/scope" 2>/dev/null || echo System)" != Device ]] || continue
    printf '%s\n' "$b"
  done
  return 0
}
# power_charge_limit_now: where the first such battery stops charging (100 is full), or nothing without one.
power_charge_limit_now() {
  local b; b=$(power_charge_batteries); b=${b%%$'\n'*}
  [[ -z "$b" ]] || cat "$b/charge_control_end_threshold"
}

# power_close_apps: before shutting down, restarting or logging out, ask every open window to close, as its own
# close button does, and wait for them to go (TAKUMI_CLOSE_WAIT seconds, 8 by default). An app with unsaved
# work answers with a question in its own window ("Save changes?"); that window stays open and so does the
# computer. Returns 0 when nothing is open any more (or niri is not there to ask); otherwise prints the names
# of the apps still open, one per line, brings the first one to the front, and returns 1.
power_close_apps() {
  command -v niri >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 0
  local all id left wait=${TAKUMI_CLOSE_WAIT:-8} tick=0 first
  all=$(niri msg --json windows 2>/dev/null) || return 0
  [[ -n "$all" && "$all" != "[]" ]] || return 0
  while IFS= read -r id; do
    [[ -n "$id" ]] && niri msg action close-window --id "$id" >/dev/null 2>&1 || true
  done < <(jq -r '.[].id' <<< "$all")
  while (( tick < wait * 4 )); do
    left=$(niri msg --json windows 2>/dev/null || echo "[]")
    [[ "$(jq 'length' <<< "$left" 2>/dev/null || echo 0)" == 0 ]] && return 0
    sleep 0.25; tick=$((tick + 1))
  done
  first=$(jq -r '.[0].id' <<< "$left")
  niri msg action focus-window --id "$first" >/dev/null 2>&1 || true
  jq -r '.[] | [(.app_id // ""), (.title // "")] | @tsv' <<< "$left" | while IFS=$'\t' read -r app title; do
    power_app_name "$app" "$title"
  done | awk '!seen[$0]++'
  return 1
}

# power_app_name <app_id> <title>: what a person calls the app: its .desktop Name, else the window's title.
power_app_name() {
  local d f name=""
  for d in "$HOME/.local/share/applications" /usr/share/applications /var/lib/flatpak/exports/share/applications; do
    f="$d/$1.desktop"
    [[ -n "$1" && -r "$f" ]] || continue
    name=$(sed -n 's/^Name=//p' "$f" | head -n 1); break
  done
  printf '%s\n' "${name:-${2:-An app}}"
}

# power_leave <what to do in words, "shut down"> : close the apps first; when one stays, say so in the Core and
# stop (exit 3), leaving the computer as it is.
power_leave() {
  local left n words
  left=$(power_close_apps) && return 0
  n=$(grep -c . <<< "$left" || true)
  words=$(head -n 1 <<< "$left"); (( n > 1 )) && words="$words and $((n - 1)) more"
  takumi notice power "$words still open" "Save or close it, then $1 again" >/dev/null 2>&1 || true
  echo "$words still open: save or close it, then $1 again" >&2
  exit 3
}

# power_hold_awake <why>: while the calling script runs, the computer does not go to sleep by itself: a logind
# inhibitor lock (the same as takumi power awake's) held by a watcher that ends with the script, however the
# script ends. Closing the lid still sleeps it (logind's LidSwitchIgnoreInhibited): that is a decision.
power_hold_awake() {
  command -v systemd-inhibit >/dev/null 2>&1 || return 0
  systemd-inhibit --what=sleep:idle --who=Takumi --why="$1" --mode=block tail --pid=$$ -f /dev/null >/dev/null 2>&1 &
}
