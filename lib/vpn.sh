#!/usr/bin/env bash
# VPNs: WireGuard and OpenVPN through NetworkManager, and Tailscale, for commands/vpn/* and the Palette's VPN rows.
# Sourced, not run; bash 3.2 (the tests use a fake nmcli and a fake tailscale on macOS). See docs/vpn.md.
# nmcli prints with --escape no and a name is always the last field, so a colon in a name is kept.

# Saved VPNs, most recently used first: uuid <tab> type <tab> state <tab> name. type is wireguard, or vpn for a
# NetworkManager plugin such as OpenVPN; state is activated, activating, deactivating or off.
vpn_list() {
  local line uuid type state ts
  while IFS= read -r line; do
    uuid=${line%%:*}; line=${line#*:}
    type=${line%%:*}; line=${line#*:}
    state=${line%%:*}; line=${line#*:}
    ts=${line%%:*}; line=${line#*:}
    case "$type" in vpn|wireguard) ;; *) continue ;; esac
    [[ -n "$uuid" && -n "$line" ]] || continue
    case "$state" in ""|deactivated) state=off ;; esac
    printf '%s\t%s\t%s\t%s\t%s\n' "${ts:-0}" "$uuid" "$type" "$state" "$line"
  done < <(LC_ALL=C nmcli -t -e no -f UUID,TYPE,STATE,TIMESTAMP,NAME connection show 2>/dev/null) |
    sort -t "$(printf '\t')" -k1,1nr | cut -f2-
}

# vpn_uuid <name>: the saved VPN with that name; the most recently used when two share it.
vpn_uuid() { vpn_list | N="$1" awk -F '\t' '{ n = $0; sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", n) } n == ENVIRON["N"] { print $1; exit }'; }
# vpn_uuids <name>: every saved VPN with that name, one uuid per line.
vpn_uuids() { vpn_list | N="$1" awk -F '\t' '{ n = $0; sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", n) } n == ENVIRON["N"] { print $1 }'; }
# vpn_state <uuid>: activated, activating, deactivating or off; nothing for no such VPN.
vpn_state() { vpn_list | U="$1" awk -F '\t' '$1 == ENVIRON["U"] { print $3; exit }'; }

# vpn_kind <uuid>: wireguard, openvpn, or the last word of another plugin's name (openconnect, vpnc…).
vpn_kind() {
  local type svc
  type=$(LC_ALL=C nmcli -e no -g connection.type connection show uuid "$1" 2>/dev/null) || true
  if [[ "$type" == wireguard ]]; then echo wireguard; return 0; fi
  svc=$(LC_ALL=C nmcli -e no -g vpn.service-type connection show uuid "$1" 2>/dev/null) || true
  echo "${svc##*.}"
}
vpn_kind_name() { case "$1" in wireguard) echo WireGuard ;; openvpn) echo OpenVPN ;; openconnect) echo OpenConnect ;; *) echo VPN ;; esac; }

# vpn_data <uuid> <key>: one item of a plugin's settings ("connection-type", "username", "ca"), which nmcli prints as
# "key = value, key = value".
vpn_data() {
  local data
  data=$(LC_ALL=C nmcli -e no -g vpn.data connection show uuid "$1" 2>/dev/null) || true
  K="$2" awk '{
    n = split($0, part, /, /)
    for (i = 1; i <= n; i++) { p = index(part[i], " = "); if (p && substr(part[i], 1, p - 1) == ENVIRON["K"]) { print substr(part[i], p + 3); exit } }
  }' <<< "$data"
}

# vpn_needs <uuid>: what connecting asks for: "username password", "password", or nothing. OpenVPN profiles made
# for a username and a password ask; WireGuard keeps its key in the profile and asks for nothing.
vpn_needs() {
  [[ "$(vpn_kind "$1")" == openvpn ]] || return 0
  case "$(vpn_data "$1" connection-type)" in
    password|password-tls) if [[ -n "$(vpn_data "$1" username)" ]]; then echo password; else echo "username password"; fi ;;
  esac
  return 0
}

# A value inside nmcli's list of options (vpn.data, vpn.secrets): a backslash, a comma or an equals sign would end
# it or start the next one, so each gets a backslash.
vpn_escape() { printf '%s' "$1" | sed 's/[\\,=]/\\&/g'; }

# vpn_store <uuid> <username or nothing> <password>: keep them with the profile, so connecting needs nobody standing
# by. A username is no secret and goes as an argument; the password reaches nmcli's editor on stdin, never a command
# line. An OpenVPN import leaves the password to a keyring (password-flags 1); 0 keeps it with the profile, which only
# root can read, as a Wi-Fi password is.
vpn_store() {
  local out
  if [[ -n "$2" ]]; then LC_ALL=C nmcli connection modify uuid "$1" +vpn.data "username=$(vpn_escape "$2")" >/dev/null 2>&1 || return 1; fi
  LC_ALL=C nmcli connection modify uuid "$1" +vpn.data password-flags=0 >/dev/null 2>&1 || return 1
  out=$(printf 'set vpn.secrets password=%s\nsave persistent\nquit\n' "$(vpn_escape "$3")" | LC_ALL=C nmcli connection edit uuid "$1" 2>&1) || true
  [[ "$out" == *"successfully updated"* ]]
}

# vpn_keeps_password <uuid>: true when the profile keeps its password (password-flags 0, the default), so connecting
# can try it before asking.
vpn_keeps_password() { local f; f=$(vpn_data "$1" password-flags); [[ -z "$f" || "$f" == 0 ]]; }

# vpn_ask <uuid> <name> <again yes|no> <why>: a conversation (lib/core.sh, sourced by the caller) for what the VPN
# needs: its username when none is saved (again: Enter keeps the saved one) and its password, then both are kept
# with the profile. Exits 3 with <why> when no answer comes.
vpn_ask() {
  local uuid=$1 name=$2 again=$3 why=$4 user u="" p=""
  user=$(vpn_data "$uuid" username)
  if [[ -z "$user" ]]; then
    while :; do
      core_ask u "Username for VPN $name" || core_fail 3 "$why"
      [[ -n "$u" ]] && break
      core_wrong "VPN $name needs your username"; core_in_core || core_fail 3 "VPN $name needs your username"
    done
  elif [[ $again == yes ]]; then
    core_ask u "Username, or Enter to keep $user" || core_fail 3 "$why"
    [[ "$u" != "$user" ]] || u=""
  fi
  while :; do
    core_secret p "Password for VPN $name" || core_fail 3 "$why"
    [[ -n "$p" ]] && break
    core_wrong "VPN $name needs your password"; core_in_core || core_fail 3 "VPN $name needs your password"
  done
  vpn_store "$uuid" "$u" "$p" || core_fail 1 "The password could not be kept for VPN $name"
}

# vpn_up <uuid>: connect with nobody standing by to answer for secrets, so a wrong password fails at once instead of
# being asked for until a timeout. 0 connected · 4 the username or password did not work, or none is saved · 1
# anything else, with $vpn_reason in words.
vpn_reason=""
vpn_up() {
  local out low
  vpn_reason=""
  if out=$(LC_ALL=C nmcli --wait 90 connection up uuid "$1" </dev/null 2>&1); then return 0; fi
  low=$(printf '%s' "$out" | tr '[:upper:]' '[:lower:]')
  case "$low" in
    *"not authorized"*|*"not authorised"*) vpn_reason="this account may not change the network" ;;
    *secret*|*"login failed"*|*"authentication failed"*|*auth_failed*) return 4 ;;
    *timeout*|*"timed out"*) vpn_reason="the server did not answer in time" ;;
    *"not installed"*|*plugin*) vpn_reason="this kind of VPN is not installed on this computer" ;;
    *) vpn_reason=$(sed -n 's/^Error: //p' <<< "$out" | sed 's/^Connection activation failed: //; s/^([0-9]*) //' | head -n 1) ;;
  esac
  return 1
}
vpn_down() { LC_ALL=C nmcli connection down uuid "$1" >/dev/null 2>&1; }

# Tailscale's state as JSON (tailscale status --json), or nothing when it is not installed or its service is off.
vpn_ts_status() { command -v tailscale >/dev/null || return 0; LC_ALL=C tailscale status --json 2>/dev/null || true; }

# The words for an exit node in jq: a Mullvad node by its city and country, any other by its machine name.
vpn_ts_label='def nodename: if (.Location.City // "") != "" then .Location.City + (if (.Location.Country // "") != "" then ", " + .Location.Country else "" end)
  else (.HostName // ((.DNSName // "") | split(".")[0])) end;'

# vpn_in_use: one line for the resting Core: "up <name>" while a VPN carries this computer's traffic, "connecting
# <name>" while one starts, nothing otherwise. Tailscale counts while one of its exit nodes carries the traffic.
vpn_in_use() {
  local list line=""
  list=$(vpn_list)
  line=$(awk -F '\t' '$3 == "activated" { n = $0; sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", n); print "up " n; exit }' <<< "$list")
  [[ -n "$line" ]] || line=$(awk -F '\t' '$3 == "activating" { n = $0; sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", n); print "connecting " n; exit }' <<< "$list")
  if [[ -z "$line" ]] && command -v jq >/dev/null; then
    [[ "$(vpn_ts_status | jq -r 'if .BackendState == "Running" and .ExitNodeStatus != null then "yes" else "" end' 2>/dev/null)" == yes ]] && line="up Tailscale"
  fi
  [[ -z "$line" ]] || printf '%s\n' "$line"
}
