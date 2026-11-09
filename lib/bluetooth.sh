#!/usr/bin/env bash
# Bluetooth through BlueZ's bluetoothctl, for commands/bluetooth/* and the Palette's Bluetooth rows.
# Sourced, not run. Runs on bash 3.2 (the tests use a fake bluetoothctl on macOS). See docs/bluetooth.md.

# bluetoothctl waits for the Bluetooth service forever when it is not running (a computer without an
# adapter never starts it), so every call has a time limit.
bt_ctl() { if command -v timeout >/dev/null; then timeout "${TAKUMI_BT_WAIT:-4}" bluetoothctl "$@"; else bluetoothctl "$@"; fi; }
# True when an adapter is here and the Bluetooth service answers. Under systemd a stopped service is
# answer enough, without asking bluetoothctl at all.
bt_present() {
  command -v bluetoothctl >/dev/null || return 1
  if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null; then systemctl is-active --quiet bluetooth 2>/dev/null || return 1; fi
  [[ -n "$(bt_ctl list 2>/dev/null)" ]]
}
bt_on() { [[ "$(bt_ctl show 2>/dev/null)" == *"Powered: yes"* ]]; }
bt_valid() { [[ "${1:-}" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; }

# Devices, one per line: address <tab> name. $1: empty for every one BlueZ knows, Paired or Connected.
bt_devices() {
  local line
  # shellcheck disable=SC2086 # no filter is no argument
  bt_ctl devices ${1:-} 2>/dev/null | while IFS= read -r line; do
    case "$line" in Device\ ??:??:??:??:??:??\ *) printf '%s\t%s\n' "${line:7:17}" "${line:25}" ;; esac
  done
}
# bt_field <address> <key>: one line of `bluetoothctl info`, without its key ("Icon" gives audio-headset).
bt_field() {
  bt_ctl info "$1" 2>/dev/null | while IFS= read -r line; do
    line=${line#"${line%%[![:space:]]*}"}
    case "$line" in "$2: "*) printf '%s\n' "${line#"$2: "}"; break ;; esac
  done
}
# The battery a device reports, 0-100, or nothing ("Battery Percentage: 0x50 (80)").
bt_battery() {
  local v; v=$(bt_field "$1" "Battery Percentage"); v=${v##*(}; v=${v%)}
  [[ "$v" =~ ^[0-9]+$ ]] && printf '%s\n' "$v"
  return 0
}
# What a device is, in one word for its icon and its words: headphones, keyboard, mouse, phone, device.
bt_kind() {
  case "$(bt_field "$1" Icon)" in
    audio-head*|audio-card) echo headphones ;; input-keyboard) echo keyboard ;;
    input-mouse|input-tablet|input-gaming) echo mouse ;; phone) echo phone ;; *) echo device ;;
  esac
}
# A name worth showing: unnamed devices come as their address with dashes, which means nothing to anyone.
bt_named() { [[ -n "$2" && ! "$2" =~ ^([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}$ ]]; }
# Look for nearby devices in the background for $1 seconds, one search at a time.
bt_scan() {
  local f="${XDG_RUNTIME_DIR:-/tmp}/takumi-bt-scan" pid
  if [[ -r "$f" ]] && read -r pid < "$f" && kill -0 "$pid" 2>/dev/null; then return 0; fi
  bluetoothctl --timeout "${1:-12}" scan on >/dev/null 2>&1 &
  echo $! > "$f"
}
