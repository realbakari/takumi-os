#!/usr/bin/env bash
# Wi-Fi through NetworkManager, for commands/wifi/* and the Palette's Wi-Fi rows. Sourced, not run.
# See docs/wifi.md. nmcli prints with --escape no and a network's name is always the last field, so a
# colon, a backslash or a trailing space in a name is kept exactly. Runs on bash 3.2 (the tests use a
# fake nmcli on macOS).

# True when a Wi-Fi device is here and NetworkManager manages it.
wifi_present() {
  local t s
  while IFS=: read -r t s; do
    [[ "$t" == wifi && "$s" != unmanaged ]] && return 0
  done < <(LC_ALL=C nmcli -t -f TYPE,STATE device 2>/dev/null)
  return 1
}

# True when the Wi-Fi radio is on.
wifi_on() { [[ "$(LC_ALL=C nmcli radio wifi 2>/dev/null)" == enabled ]]; }

# full, portal (a sign-in page is in the way), limited, none or unknown.
wifi_connectivity() { LC_ALL=C nmcli -t -f CONNECTIVITY general 2>/dev/null || echo unknown; }

# Nearby networks, one line each: in-use (1 or 0) <tab> signal 0-100 <tab> kind <tab> name.
# The one in use comes first, then the strongest; one line per name. kind is open, owe, psk, sae, wep
# or enterprise. Networks without a name (hidden ones) are left out. $1: rescan yes, no or auto.
wifi_scan() {
  local line use sig sec kind
  while IFS= read -r line; do
    [[ "$line" == *:*:*:* ]] || continue
    use=${line%%:*}; line=${line#*:}
    sig=${line%%:*}; line=${line#*:}
    sec=${line%%:*}; line=${line#*:}
    [[ -n "$line" ]] || continue
    case "$sec" in
      *802.1X*)     kind=enterprise ;;
      *WPA1*|*WPA2*) kind=psk ;;          # WPA2 and WPA3 together: the password works either way
      *WPA3*)       kind=sae ;;
      *OWE*)        kind=owe ;;
      *WEP*)        kind=wep ;;
      *)            kind=open ;;
    esac
    [[ "$use" == '*' ]] && use=1 || use=0
    printf '%s\t%s\t%s\t%s\n' "$use" "${sig:-0}" "$kind" "$line"
  done < <(LC_ALL=C nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan "${1:-no}" 2>/dev/null) |
    sort -t "$(printf '\t')" -k1,1nr -k2,2nr | awk -F '\t' '!seen[$4]++'
}

# Saved networks, most recently used first: uuid <tab> name. Profiles for an access point this
# computer makes (a hotspot) are not networks to join and are left out. Two nmcli calls in all.
wifi_saved() {
  local uuid type ts args=()
  while IFS=: read -r uuid type ts; do
    [[ "$type" == 802-11-wireless ]] && args+=(uuid "$uuid")
  done < <(LC_ALL=C nmcli -t -f UUID,TYPE,TIMESTAMP connection show 2>/dev/null | sort -t: -k3,3nr)
  [[ ${#args[@]} -gt 0 ]] || return 0
  LC_ALL=C nmcli -e no -g connection.uuid,802-11-wireless.ssid,802-11-wireless.mode connection show "${args[@]}" 2>/dev/null |
    awk 'BEGIN { RS = ""; FS = "\n" } $3 == "" || $3 == "infrastructure" { print $1 "\t" $2 }'
}

# The saved profiles for one network name, one uuid per line.
wifi_saved_uuids() { wifi_saved | N="$1" awk -F '\t' '$2 == ENVIRON["N"] { print $1 }'; }

# The name of the network in use, or nothing.
wifi_current() { wifi_scan no | awk -F '\t' '$1 == 1 { sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, ""); print; exit }'; }

# Store a password in a saved profile without putting it on a command line, where any user could read
# it in the process list: nmcli's editor reads it from stdin. nmcli drops spaces at either end.
wifi_store_secret() {  # uuid property secret
  local out
  out=$(printf 'set %s %s\nsave persistent\nquit\n' "$2" "$3" | LC_ALL=C nmcli connection edit uuid "$1" 2>&1) || true
  [[ "$out" == *"successfully updated"* ]]
}

# The secret property for a kind of network.
wifi_secret_key() {
  case "$1" in wep) echo 802-11-wireless-security.wep-key0 ;; enterprise) echo 802-1x.password ;; *) echo 802-11-wireless-security.psk ;; esac
}

# A work or school network (WPA2 or WPA3-Enterprise, eduroam) is checked before it gets a password: its server's
# certificate must come from an authority this computer trusts (the system's list) and belong to the domain your IT
# department names, so a look-alike network cannot collect it.
wifi_ca_bundle=${TAKUMI_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}

# wifi_domain_clean <text>: a domain as typed, made plain: lowercase, no spaces, no "*." in front, no dot behind.
wifi_domain_clean() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | sed 's/^\*\.//; s/\.$//'; }
# True for what can be a domain: two or more names joined by dots.
wifi_domain_ok() { local re='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'; [[ "$1" =~ $re ]]; }
# wifi_realm <username>: the domain in "name@school.edu", which is often the server's own; nothing otherwise.
wifi_realm() {
  local r
  [[ "$1" == *@* ]] || return 0
  r=$(wifi_domain_clean "${1##*@}")
  if wifi_domain_ok "$r"; then printf '%s\n' "$r"; fi
  return 0
}

# wifi_cert_problem <since, epoch seconds>: why a work or school network turned us away, when wpa_supplicant wrote
# down a certificate error since then: "domain" (the certificate is for another domain) or "trust" (no authority this
# computer trusts signed it). Nothing otherwise, and nothing for an account that may not read the system's journal.
wifi_cert_problem() {
  local log
  log=$(journalctl --quiet --no-pager -o cat -t wpa_supplicant --since "@$1" 2>/dev/null || true)
  if grep -qiE 'EAP-TLS-CERT-ERROR.*domain' <<< "$log"; then echo domain
  elif grep -q 'EAP-TLS-CERT-ERROR' <<< "$log"; then echo trust; fi
  return 0
}

# A name or password inside the WIFI: text a phone camera reads, with \ ; , : " escaped. sed through a
# pipe rather than ${s//...}: bash 3.2 and bash 5 disagree about backslashes in a replacement.
wifi_qr_escape() { printf '%s' "$1" | sed 's/[\;,:"]/\\&/g'; }
