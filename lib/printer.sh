#!/usr/bin/env bash
# Printers and scanners: CUPS prints, SANE scans. Sourced by commands/printer/*, commands/scan/main and the
# Palette's printer rows; runs on bash 3.2 (the tests use fake CUPS and SANE tools on macOS). See
# docs/printing.md.
#
# A line holds its fields split by the unit separator ($printer_sep), so an empty field (a printer with no
# description) keeps its place. CUPS is read in the C locale: its words are parsed here, never shown.

printer_sep=$'\037'
printer_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
printer_found_file="$printer_run/takumi-printers-found"
printer_scanners_file="$printer_run/takumi-scanners"
printer_testpage=/usr/share/cups/data/testprint

# printer_running: true while the print service runs. Asking systemd never starts it; asking CUPS would
# (cups.socket starts cupsd for anyone who connects).
printer_running() { systemctl is-active --quiet cups.service 2>/dev/null; }

# printer_queues: the printers set up on this computer, one line each:
#   queue  description  state (idle, printing, stopped)  alerts  default (1 or 0)  device uri  message
# One lpstat call: the default, the devices, then each printer in long form, whose "Alerts:" line holds
# CUPS's printer-state-reasons (media-empty-error, offline-report, ...).
printer_queues() {
  local fields="Form mounted|Content types|Printer types|Location|Connection|Interface|On fault|After fault"
  fields+="|Users allowed|Forms allowed|Charset sets|Default pitch|Default page size|Default port settings"
  { LC_ALL=C lpstat -d -v -l -p 2>/dev/null || true; } | awk -v S="$printer_sep" -v F="$fields" '
    /^system default destination: / { def = substr($0, 29); next }
    /^device for / { s = substr($0, 12); i = index(s, ": "); if (i) uri[substr(s, 1, i - 1)] = substr(s, i + 2); next }
    /^printer / {
      cur = $2; order[++n] = cur; first = 1
      st[cur] = ($0 ~ /^printer [^ ]+ now printing /) ? "printing" : ($0 ~ /^printer [^ ]+ disabled since /) ? "stopped" : "idle"
      next }
    /^\t/ && cur != "" {
      line = substr($0, 2)
      if (line ~ /^Description: /) desc[cur] = substr(line, 14)
      else if (line ~ /^Alerts: /) alerts[cur] = substr(line, 9)
      else if (first && line !~ /^\t/ && line !~ ("^(" F "):") && line != "Banner required") msg[cur] = line   # the first line may be its message
      first = 0
      next }
    END { for (i = 1; i <= n; i++) { q = order[i]; print q S desc[q] S st[q] S alerts[q] S (q == def ? 1 : 0) S uri[q] S msg[q] } }'
}

# printer_default: the printer apps use unless told otherwise (yours, else the computer's), or nothing.
printer_default() { { LC_ALL=C lpstat -d 2>/dev/null || true; } | sed -n 's/^system default destination: //p'; }

# printer_label <queue> <description>: the name a person reads: the description, else the queue's name.
printer_label() { if [[ -n "${2:-}" ]]; then printf '%s' "$2"; else printf '%s' "${1//_/ }"; fi; }

# printer_find <name>: the queue a person means, by its own name or its label, in any case; nothing when
# no printer is called that.
printer_find() {
  local want; want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  printer_queues | awk -F "$printer_sep" -v w="$want" '
    { q = tolower($1); l = tolower($2); s = q; gsub(/_/, " ", s) }
    q == w || l == w || s == w { print $1; exit }'
}

# printer_problem <state> <alerts> <message>: what is wrong, in one word, or nothing: jam, paper, empty (ink
# or toner), cover, offline, paused, stopped, or low (ink or toner, still printing). The alerts are CUPS's
# printer-state-reasons, with their -error, -warning and -report endings.
printer_problem() {
  local a=" ${2:-} "
  case "$a" in
    *" media-jam"*) echo jam; return ;;
    *" media-empty"*|*" media-needed"*) echo paper; return ;;
    *" toner-empty"*|*" marker-supply-empty"*) echo empty; return ;;
    *" door-open"*|*" cover-open"*|*" interlock-open"*) echo cover; return ;;
    *" offline"*) echo offline; return ;;
  esac
  if [[ "$1" == stopped ]]; then
    case "$a" in *" paused"*) echo paused; return ;; esac
    case "${3:-}" in
      *"nable to locate"*|*"not responding"*|*"nable to connect"*|*"No route"*|*"Host is down"*|*"unreachable"*|*"timed out"*) echo offline ;;
      *) echo stopped ;;
    esac
    return
  fi
  case "$a" in *" toner-low"*|*" marker-supply-low"*) echo low ;; esac
}

# printer_supply <queue>: toner, ink, or "ink or toner" when the printer does not say (lpoptions shows what
# CUPS last heard from it, marker-types among it).
printer_supply() {
  local t
  t=$( { LC_ALL=C lpoptions -p "$1" 2>/dev/null || true; } | tr ' ' '\n' | sed -n 's/^marker-types=//p' | head -n 1)
  case "$t" in *toner*) echo toner ;; *ink*) echo ink ;; *) echo "ink or toner" ;; esac
}

# printer_words <problem> <state> [supply]: how a printer is, in words.
printer_words() {
  local s=${3:-ink or toner}
  case "$1" in
    jam) echo "Paper is stuck" ;;
    paper) echo "Out of paper" ;;
    empty) echo "Out of $s" ;;
    cover) echo "A cover is open" ;;
    offline) echo "Offline" ;;
    paused) echo "Paused" ;;
    stopped) echo "Stopped" ;;
    low) if [[ "$2" == printing ]]; then echo "Printing · low on $s"; else echo "Ready · low on $s"; fi ;;
    *) if [[ "$2" == printing ]]; then echo "Printing"; else echo "Ready"; fi ;;
  esac
}

# printer_status <queue> <state> <alerts> <message>: printer_words for a queue, asking which supply only
# when one is low or out.
printer_status() {
  local p supply=""
  p=$(printer_problem "$2" "$3" "$4")
  case "$p" in empty|low) supply=$(printer_supply "$1") ;; esac
  printer_words "$p" "$2" "$supply"
}

# printer_admin <why> <command> [args...]: a change to CUPS (lpadmin, cupsenable, cupsaccept). CUPS lets an
# administrator's own account make it over its local socket (the wheel group is in its SystemGroup), so
# usually nothing is asked. When CUPS refuses, sudo asks for the password, in the Core when the Core runs us.
# On failure it prints the tool's own words, for the caller to turn into a sentence.
printer_admin() {
  local why=$1 out rc=0; shift
  out=$(LC_ALL=C "$@" </dev/null 2>&1) || rc=$?
  if (( rc != 0 )); then
    case "$out" in
      *Forbidden*|*Unauthorized*|*"ot authorized"*|*"ot allowed"*|*[Pp]assword*)
        rc=0
        # sudo: cupsd writes /etc/cups/printers.conf and /etc/cups/ppd/<queue>.ppd for this command
        out=$(core_sudo "$why" env LC_ALL=C "$@" </dev/null 2>&1) || rc=$? ;;
    esac
  fi
  (( rc == 0 )) || printf '%s\n' "$out"
  return "$rc"
}

# printer_refused <words>: true when printer_admin failed for want of rights rather than for the printer.
printer_refused() {
  case "$1" in *sudoers*|*Forbidden*|*Unauthorized*|*"ot authorized"*|*"ot allowed"*) return 0 ;; esac
  return 1
}
# printer_unanswered <words>: true when sudo asked for the password and none, or no right one, came.
printer_unanswered() {
  case "$1" in *"no password was provided"*|*"password is required"*|*"incorrect password"*) return 0 ;; esac
  return 1
}

# printer_said <words>: a tool's last line without its name ("lpadmin: ..."), for a sentence.
printer_said() { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1 | sed 's/^[a-z]*: //'; }

# printer_discover: printers CUPS can reach on the network and over USB, one line each:
#   uri  name  make and model  how (network or usb)  device id
# One line per printer: CUPS's own browsing folds a printer's IPP and IPPS announcements into one, and a USB
# printer that also shows on the network (ipp-usb shares it there) keeps the network line, which needs no
# driver. The name is the one it announces, without the "[4C1A2B]" some add, unless two would read the
# same. Takes some seconds: CUPS listens for printers announcing themselves.
printer_discover() {
  LC_ALL=C lpinfo --timeout "${TAKUMI_PRINTER_LISTEN:-8}" --include-schemes dnssd,ipp,ipps,usb -l -v 2>/dev/null | awk -v S="$printer_sep" '
    function flush() {
      if (uri ~ /:\/\//) { n++; u[n] = uri; nm[n] = info; mm[n] = mam; cl[n] = (uri ~ /^usb:/) ? "usb" : "network"; id[n] = devid }
      uri = ""; info = ""; mam = ""; devid = ""
    }
    function bare(s) { sub(/ \[[^]]*\]$/, "", s); return s }
    /^Device: uri = / { flush(); uri = substr($0, 15); next }
    /^[ \t]+info = / { info = $0; sub(/^[ \t]+info = /, "", info); next }
    /^[ \t]+make-and-model = / { mam = $0; sub(/^[ \t]+make-and-model = /, "", mam); next }
    /^[ \t]+device-id = / { devid = $0; sub(/^[ \t]+device-id = /, "", devid); next }
    END {
      flush()
      for (i = 1; i <= n; i++) if (cl[i] == "network") { net[tolower(nm[i])] = 1; b = tolower(bare(nm[i])); same[b]++; seenb[b] = 1 }
      for (i = 1; i <= n; i++) {
        k = tolower(nm[i]); b = tolower(bare(nm[i]))
        if (cl[i] == "usb" && ((k in net) || (b in seenb))) continue
        if (k in done) continue
        done[k] = 1
        name = (cl[i] == "network" && same[b] > 1) ? nm[i] : bare(nm[i])
        if (mm[i] == "Unknown") mm[i] = ""
        print u[i] S name S mm[i] S cl[i] S id[i]
      }
    }'
}

# printer_found [--cached]: printer_discover's lines, kept a minute in $printer_found_file. --cached never
# waits (the Palette): it answers from the file and, when that is old or missing, looks again in the
# background, one search at a time.
printer_found() {
  if [[ "${1:-}" == --cached ]]; then
    if [[ ! -f "$printer_found_file" || -n "$(find "$printer_found_file" -mmin +1 2>/dev/null)" ]]; then
      (printer_refresh "$printer_found_file" printer_discover >/dev/null 2>&1 &)
    fi
  else
    printer_refresh "$printer_found_file" printer_discover
  fi
  cat "$printer_found_file" 2>/dev/null || true
}

# printer_refresh <file> <function>: writes the function's lines to the file, unless another search for it
# is running. A search that found nothing still writes the file: it was asked. A search that died more
# than two minutes ago leaves its lock behind; it is cleared.
printer_refresh() {
  local lock="$1.lock"
  mkdir -p "$printer_run"
  if [[ -n "$(find "$lock" -maxdepth 0 -mmin +2 2>/dev/null)" ]]; then rmdir "$lock" 2>/dev/null || true; fi
  mkdir "$lock" 2>/dev/null || return 0
  "$2" > "$1.tmp" 2>/dev/null || true
  mv -f "$1.tmp" "$1"
  rmdir "$lock" 2>/dev/null || true
}

# printer_scanners_now: scanners SANE answers for, one line each: device <sep> name. Cameras (v4l) are left
# out, and a network scanner found two ways (eSCL and WSD, by sane-airscan) keeps one line, eSCL first.
printer_scanners_now() {
  LC_ALL=C scanimage -L 2>/dev/null | awk -v S="$printer_sep" '
    /^device `/ {
      s = substr($0, 9); i = index(s, "\047 is a "); if (!i) next
      dev = substr(s, 1, i - 1); name = substr(s, i + 7)
      if (dev ~ /^v4l:/) next
      sub(/^(eSCL|WSD) /, "", name); sub(/ ip=[^ ]*$/, "", name)
      sub(/ (flatbed scanner|sheetfed scanner|all-in-one|multi-function peripheral|virtual device|scanner)$/, "", name)
      n++; d[n] = dev; nm[n] = name; w[n] = (dev ~ /^airscan:w/) }
    END {
      for (pass = 0; pass <= 1; pass++) for (i = 1; i <= n; i++) {
        k = tolower(nm[i]); if (w[i] != pass || (k in done)) continue
        done[k] = 1; print d[i] S nm[i]
      }
    }'
}

# printer_scanners [--cached]: printer_scanners_now's lines, kept five minutes in $printer_scanners_file;
# --cached never waits, like printer_found. An empty file means SANE was asked and found none.
printer_scanners() {
  if [[ "${1:-}" == --cached ]]; then
    if [[ ! -f "$printer_scanners_file" || -n "$(find "$printer_scanners_file" -mmin +5 2>/dev/null)" ]]; then
      (printer_refresh "$printer_scanners_file" printer_scanners_now >/dev/null 2>&1 &)
    fi
  else
    printer_refresh "$printer_scanners_file" printer_scanners_now
  fi
  cat "$printer_scanners_file" 2>/dev/null || true
}

# printer_queue_name <name>: a name CUPS takes for a new printer (letters, digits, _ . -) that no printer
# here has yet, in any case: "HP LaserJet M110w" is HP_LaserJet_M110w, a second one HP_LaserJet_M110w_2.
printer_queue_name() {
  local base q n=1 taken
  base=$(printf '%s' "$1" | LC_ALL=C sed 's/[^A-Za-z0-9_.-]/_/g; s/__*/_/g; s/^_//; s/_$//' | cut -c1-120)
  [[ -n "$base" ]] || base=Printer
  taken=$(printer_queues | cut -d "$printer_sep" -f1 | tr '[:upper:]' '[:lower:]')
  q=$base
  while grep -qxF "$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')" <<< "$taken"; do n=$((n + 1)); q="${base}_$n"; done
  printf '%s' "$q"
}

# printer_name_from_uri <uri>: a name to show for a printer known only by its address: the name it
# announces (dnssd, without a "[4C1A2B]" at its end), its make and model (usb), else "Printer at <host>".
printer_name_from_uri() {
  local n
  case "$1" in
    dnssd://*) n=${1#dnssd://}; n=${n%%._*} ;;
    usb://*) n=${1#usb://}; n=${n%%\?*}; n=${n/\// } ;;
    *) n=${1#*://}; n=${n%%/*}; n=${n%:*}; printf 'Printer at %s' "$n"; return ;;
  esac
  printer_unescape "$n" | sed 's/ \[[^]]*\]$//'
}

# printer_unescape <text>: %20 and the like back to the characters they stand for. sed, not ${s//...}: bash
# 3.2 and bash 5 disagree about backslashes in a replacement.
printer_unescape() { printf '%b' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"; }

# printer_drivers <make and model> [device id]: drivers this computer has for a printer that needs one, the
# closest first (cups-driverd ranks them by how well they match), at most three: ppd <sep> description.
# Only drivers made for the printer's brand, never the raw queue or the driverless one already tried.
printer_drivers() {
  local out="" make
  if [[ -n "${2:-}" ]]; then out=$(LC_ALL=C lpinfo --device-id "$2" -m 2>/dev/null || true); fi
  [[ -n "$out" ]] || out=$(LC_ALL=C lpinfo --make-and-model "$1" -m 2>/dev/null || true)
  make=$(printf '%s' "$1" | awk '{ m = tolower($1); if (m == "hewlett-packard") m = "hp"; if (m == "seiko") m = "epson"; print m }')
  awk -v S="$printer_sep" -v make="$make" '
    NF < 2 { next }
    { ppd = $1; d = $0; sub(/^[^ ]+ +/, "", d) }
    ppd == "raw" || ppd == "everywhere" || ppd ~ /^driverless:/ { next }
    make != "" && index(tolower(d), make) == 0 { next }
    !(d in seen) { seen[d] = 1; print ppd S d; if (++n == 3) exit }' <<< "$out"
}
