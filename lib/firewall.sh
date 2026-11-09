#!/usr/bin/env bash
# The firewall, ufw, for commands/firewall/*, install/steps/25-firewall.sh and the Palette's firewall rows.
# Sourced, not run; bash 3.2 (the tests use a fake ufw on macOS). See docs/firewall.md.
#
# ufw keeps its rules where only root can read them, so the Core reads what anyone can: whether ufw is on
# (/etc/ufw/ufw.conf and its unit), what happens to a connection nobody allowed (/etc/default/ufw), and Takumi's
# note of what is let in (/etc/takumi/firewall), which takumi firewall writes from ufw's own list whenever it
# changes a rule.

firewall_etc=${TAKUMI_FIREWALL_ETC:-/etc}
firewall_units=${TAKUMI_FIREWALL_UNITS:-/usr/lib/systemd/system}
firewall_record="$firewall_etc/takumi/firewall"

# The apps Takumi knows, one per line: ufw profile | words it answers to | what letting it in does | how to tell
# it is on this computer (flatpak:<id>, command:<name>, ssh for an SSH server that starts with the computer, or
# while-on for one that opens the firewall itself only while it runs and is never offered to allow by hand).
# LocalSend, the two game streamers and remote help are etc/ufw/applications.d/takumi; SSH is ufw's own
# (ufw-loginserver). Remote help (takumi screen remote, docs/capture.md) lets itself in when it starts and goes
# when it stops, so its row only shows while it is let in: "Block Remote help".
firewall_catalog() {
  cat <<'APPS'
LocalSend|localsend airdrop share send files phone nearby|receives files from nearby devices|flatpak:org.localsend.localsend_app command:localsend command:localsend_app
KDEConnect|kde connect kdeconnect phone|connects your phone to this computer|command:kdeconnectd
SSH|ssh remote login server terminal|lets other computers log in to this one|ssh
Steam Remote Play|steam remote play games gaming streaming|streams your games to other devices on this network|flatpak:com.valvesoftware.Steam command:steam
Sunshine|sunshine moonlight games gaming streaming|streams this computer's games to Moonlight on other devices|flatpak:dev.lizardbyte.app.Sunshine command:sunshine
Remote help|remote help vnc wayvnc support|lets the person helping you see and use this screen|while-on
APPS
}

firewall_installed() { command -v ufw >/dev/null; }

# on, restart (on now, off after a restart: its unit is not enabled), off, or none (ufw is not installed).
firewall_state() {
  firewall_installed || { echo none; return 0; }
  local enabled
  enabled=$(sed -n 's/^ENABLED=//p' "$firewall_etc/ufw/ufw.conf" 2>/dev/null | tr -d '"' | tail -n 1) || true
  case "$enabled" in yes|YES) ;; *) echo off; return 0 ;; esac
  if [[ "$(systemctl is-enabled ufw.service 2>/dev/null || true)" == enabled ]]; then echo on; else echo restart; fi
}

# What happens to a connection nobody allowed: deny (dropped), reject (refused) or allow.
firewall_incoming() {
  local p
  p=$(sed -n 's/^DEFAULT_INPUT_POLICY=//p' "$firewall_etc/default/ufw" 2>/dev/null | tr -d '"' | tail -n 1) || true
  case "$p" in ACCEPT) echo allow ;; REJECT) echo reject ;; *) echo deny ;; esac
}

# What the firewall lets in, from Takumi's note: apps by their profile, and other rules in ufw's own words.
firewall_allowed_apps() { sed -n 's/^app //p' "$firewall_record" 2>/dev/null || true; }
firewall_other_rules() { sed -n 's/^rule //p' "$firewall_record" 2>/dev/null || true; }
firewall_allowed() { grep -qxF -- "$1" <<< "$(firewall_allowed_apps)"; }

# Every ufw profile on this computer, ufw's own and Takumi's, one name per line.
firewall_profiles() { sed -n 's/^[[:space:]]*\[\(.*\)\][[:space:]]*$/\1/p' "$firewall_etc"/ufw/applications.d/* 2>/dev/null || true; }

firewall_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# firewall_find <word>: the profile a word means: an app's name or one of its words ("ssh", "localsend", "steam"),
# or any other ufw profile by its name. Case does not matter.
firewall_find() {
  local w name words
  w=$(firewall_lower "$1")
  [[ -n "$w" ]] || return 1
  while IFS='|' read -r name words _; do
    [[ -n "$name" ]] || continue
    if [[ "$(firewall_lower "$name")" == "$w" || " $words " == *" $w "* ]]; then printf '%s\n' "$name"; return 0; fi
  done <<< "$(firewall_catalog)"
  while IFS= read -r name; do
    [[ -n "$name" && "$(firewall_lower "$name")" == "$w" ]] && { printf '%s\n' "$name"; return 0; }
  done <<< "$(firewall_profiles)"
  return 1
}

# firewall_what <profile>: what letting it in does, in words: "receives files from nearby devices".
firewall_what() {
  local name what
  while IFS='|' read -r name _ what _; do
    [[ "$name" == "$1" ]] && { printf '%s\n' "$what"; return 0; }
  done <<< "$(firewall_catalog)"
  echo "lets other devices connect to it"
}

# True when this computer's SSH server starts with it: the links systemctl enable makes, which a chroot has too.
firewall_ssh_server_on() {
  [[ -e "$firewall_etc/systemd/system/multi-user.target.wants/sshd.service" ||
     -e "$firewall_etc/systemd/system/sockets.target.wants/sshd.socket" ]]
}

# firewall_present <profile>: true when the app is on this computer. Flatpak is asked once per run.
firewall_flatpaks=""
firewall_present() {
  local name how h
  while IFS='|' read -r name _ _ how; do
    [[ "$name" == "$1" ]] || continue
    for h in $how; do
      case "$h" in
        flatpak:*)
          [[ -n "$firewall_flatpaks" ]] || firewall_flatpaks=" $( (flatpak list --app --columns=application 2>/dev/null || true) | tr '\n' ' ') "
          [[ "$firewall_flatpaks" == *" ${h#flatpak:} "* ]] && return 0 ;;
        command:*) command -v "${h#command:}" >/dev/null && return 0 ;;
        ssh) firewall_ssh_server_on && return 0 ;;
      esac
    done
    return 1
  done <<< "$(firewall_catalog)"
  return 1
}

# firewall_parse_added: `ufw show added` on stdin, Takumi's note on stdout: "app <profile>" for an app let in from
# anywhere, "rule <ufw words>" for anything else let in. Outgoing and routed rules are not about other devices
# reaching this computer, and deny rules let nothing in, so they are left out.
firewall_parse_added() {
  local line spec profiles
  profiles=$(firewall_profiles)
  while IFS= read -r line; do
    case "$line" in "ufw allow "*|"ufw limit "*) ;; *) continue ;; esac
    spec=${line#ufw }; spec=${spec#* }
    case "$spec" in "log "*|"log-all "*) spec=${spec#* } ;; esac
    case "$spec" in out|"out "*) continue ;; esac
    spec=${spec% comment \'*}
    if [[ "$spec" == \'*\' ]]; then spec=${spec#\'}; spec=${spec%\'}; fi
    [[ -n "$spec" ]] || continue
    if grep -qxF -- "$spec" <<< "$profiles"; then echo "app $spec"; else echo "rule $spec"; fi
  done | awk '!seen[$0]++'
}

# firewall_note: write Takumi's note again from ufw's own list. Root only: takumi firewall apply runs it.
firewall_note() {
  local added
  added=$(LC_ALL=C ufw show added 2>/dev/null) || return 1
  mkdir -p "${firewall_record%/*}"
  {
    printf '%s\n' "# What the firewall lets in, for the Core (docs/firewall.md). takumi firewall writes it from ufw's own" \
                  "# rules whenever it changes them; ufw keeps the rules themselves in /etc/ufw."
    firewall_parse_added <<< "$added"
  } > "$firewall_record.tmp"
  chmod 644 "$firewall_record.tmp"
  mv -f "$firewall_record.tmp" "$firewall_record"
}

# firewall_count: what the firewall lets in, counted in words ("1 app", "2 apps and 1 more rule"), or nothing.
firewall_count() {
  local a r out=""
  a=$(firewall_allowed_apps | grep -c . || true); r=$(firewall_other_rules | grep -c . || true)
  (( a == 1 )) && out="1 app"
  (( a > 1 )) && out="$a apps"
  if (( r > 0 )); then
    local rules="rule"; (( r > 1 )) && rules="rules"
    if [[ -n "$out" ]]; then out="$out and $r more $rules"; else out="$r $rules"; fi
  fi
  printf '%s' "$out"
}

# firewall_rows <query, lowercase> <topic yes|no>: the Palette's firewall rows as JSON lines. For the topic
# ("firewall"): whether it is on, each app Takumi knows that is here or let in, and turning it off. Otherwise only
# the app whose name holds every word of the query ("localsend", "steam"), so "files" does not bring up LocalSend.
firewall_rows() {
  local ql=$1 topic=$2 state="" count sub glyph run name words what allowed hay w ok
  local -a qw=()
  if [[ $topic == no ]]; then firewall_installed || return 0
  else
    state=$(firewall_state)
    glyph=warn run=on
    case "$state" in
      none) sub="Not set up · Enter sets it up" ;;
      off) sub="Off · other devices can connect to this computer · Enter turns it on" ;;
      restart) sub="On until the computer restarts · Enter keeps it on" ;;
      *)
        glyph=lock run=""; count=$(firewall_count)
        if [[ "$(firewall_incoming)" == allow ]]; then sub="On, but it lets every connection in"
        elif [[ -n "$count" ]]; then sub="On · $count allowed"
        else sub="On · other devices cannot connect to this computer"; fi ;;
    esac
    S=$sub G=$glyph RUN=$run jq -cn '{id: "firewall:status", title: "Firewall", subtitle: env.S, glyph: env.G, kind: "Firewall",
      keywords: "firewall security incoming connections ports block allow", steady: true, score: 0.9}
      + (if env.RUN == "" then {run: ["true"]} else {run: ["takumi", "firewall", "on"], converse: true, risk: 1} end)'
    [[ $state != none ]] || return 0
  fi
  read -r -a qw <<< "$ql"
  while IFS='|' read -r name words what _; do
    [[ -n "$name" ]] || continue
    if [[ $topic == no ]]; then
      hay=$(firewall_lower "$name"); ok=yes
      for w in ${qw[@]+"${qw[@]}"}; do [[ "$hay" == *"$w"* ]] || ok=no; done
      [[ $ok == yes && ${#qw[@]} -gt 0 ]] || continue
    fi
    allowed=no; firewall_allowed "$name" && allowed=yes
    [[ $allowed == yes ]] || firewall_present "$name" || continue
    N=$name W=$words WHAT=$what A=$allowed jq -cn '
      (env.WHAT[0:1] | ascii_upcase) as $first
      | {id: ("firewall:app:" + env.N), kind: "Firewall", glyph: "shield", steady: true, converse: true, risk: 1,
         keywords: ("firewall allow block let in " + env.W)}
      + (if env.A == "yes" then {title: ("Block " + env.N), subtitle: ($first + env.WHAT[1:] + " · allowed now"),
                                  run: ["takumi", "firewall", "deny", env.N], score: 0.86}
         else {title: ("Allow " + env.N), subtitle: ($first + env.WHAT[1:] + " · blocked now"),
               run: ["takumi", "firewall", "allow", env.N], score: 0.85} end)'
  done <<< "$(firewall_catalog)"
  if [[ $topic == yes && ( $state == on || $state == restart ) ]]; then
    jq -cn '{id: "firewall:off", title: "Turn the firewall off", subtitle: "Other devices could connect to this computer", glyph: "warn",
      kind: "Firewall", keywords: "firewall off disable turn", converse: true, risk: 1, run: ["takumi", "firewall", "off"], score: 0.4}'
  fi
  return 0
}
