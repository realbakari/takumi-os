#!/usr/bin/env bash
# Takumi setup: helpers shared by the takumi-setup-* commands on the setup disc. Sourced, never run.
# See docs/setup.md.

setup_run() { printf '%s/takumi-setup' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; }
TAKUMI_ZONEINFO=${TAKUMI_ZONEINFO:-/usr/share/zoneinfo}
TAKUMI_XKB_RULES=${TAKUMI_XKB_RULES:-/usr/share/X11/xkb/rules/evdev.lst}
TAKUMI_KBD_MAP=${TAKUMI_KBD_MAP:-/usr/share/systemd/kbd-model-map}
TAKUMI_EFIVARS=${TAKUMI_EFIVARS:-/sys/firmware/efi/efivars}

# The language the computer's own firmware speaks ("en-US", "de-DE"): a first guess at the keyboard and
# the place. Four bytes of attributes come before the text.
setup_firmware_lang() {
  local f=$TAKUMI_EFIVARS/PlatformLang-8be4df61-93ca-11d2-aa0d-00e098032b8c
  [[ -r "$f" ]] || return 0
  tail -c +5 "$f" | tr -d '\000'
}

# "en-US" → US; a language alone → the country most of its speakers type in.
setup_country() {
  local lang=$1 cc
  cc=$(printf '%s' "$lang" | sed -n 's/^[a-zA-Z]\{2,3\}[-_]\([a-zA-Z]\{2\}\).*/\1/p' | tr a-z A-Z)
  if [[ -z "$cc" ]]; then
    case "${lang%%[-_]*}" in
      de) cc=DE ;; fr) cc=FR ;; es) cc=ES ;; it) cc=IT ;; pt) cc=PT ;; nl) cc=NL ;; sv) cc=SE ;; nb|nn|no) cc=NO ;;
      da) cc=DK ;; fi) cc=FI ;; pl) cc=PL ;; cs) cc=CZ ;; sk) cc=SK ;; hu) cc=HU ;; ro) cc=RO ;; tr) cc=TR ;;
      el) cc=GR ;; ru) cc=RU ;; uk) cc=UA ;; ja) cc=JP ;; ko) cc=KR ;; zh) cc=CN ;; he) cc=IL ;; *) cc=US ;;
    esac
  fi
  printf '%s' "$cc"
}

# The keyboard most people in a country type on, as an XKB layout.
setup_country_layout() {
  local cc=$1 l
  case "$cc" in
    US|CA|AU|NZ|IE|ZA|IN|SG|PH|MY|ID|NG|KE|NL|CN|TW|HK) l=us ;;
    GB) l=gb ;;
    MX|AR|CL|CO|PE|VE|UY|EC|BO|PY|CR|GT|HN|NI|PA|SV|DO|CU) l=latam ;;
    *) l=$(printf '%s' "$cc" | tr A-Z a-z) ;;
  esac
  if [[ -r "$TAKUMI_XKB_RULES" ]] && ! awk -v l="$l" '/^! layout/ { s = 1; next } /^!/ { s = 0 } s && $1 == l { f = 1 } END { exit !f }' "$TAKUMI_XKB_RULES"; then
    l=us
  fi
  printf '%s' "$l"
}

# A country's first time zone in tzdata's table ("FR" → Europe/Paris).
setup_country_zone() {
  local z=""
  [[ -r "$TAKUMI_ZONEINFO/zone.tab" ]] && z=$(awk -F'\t' -v c="$1" '$1 == c { print $3; exit }' "$TAKUMI_ZONEINFO/zone.tab")
  printf '%s' "${z:-UTC}"
}

# Layouts that type no Latin letters: the password is typed in US English first, Left Alt + Right Alt
# reaches the rest, as on the login screen (commands/greeter/main).
SETUP_NONLATIN=" am ara bd bg by et ge gr il in iq ir kg kh kz la lk mk mm mn mv np rs ru sy th tj ua "
setup_latin() { [[ "$SETUP_NONLATIN" != *" $1 "* ]]; }

# The text console's keymap for an XKB layout: systemd's own table, else a keymap of the same name, else
# US. A layout without Latin letters gets US, the keyboard its password was typed with.
setup_console_keymap() {
  local layout=$1 variant=${2:-} k=""
  setup_latin "$layout" || { printf 'us'; return 0; }
  [[ -r "$TAKUMI_KBD_MAP" ]] && k=$(awk -v l="$layout" -v v="${variant:--}" '
    /^#/ { next } $2 == l && $4 == v { print $1; exit }' "$TAKUMI_KBD_MAP")
  [[ -z "$k" && -r "$TAKUMI_KBD_MAP" ]] && k=$(awk -v l="$layout" '/^#/ { next } $2 == l && $4 == "-" { print $1; exit }' "$TAKUMI_KBD_MAP")
  printf '%s' "${k:-us}"
}

# The disk the setup disc itself is on, so it is never offered: by the disc's UUID.
setup_media_disk() {
  local uuid dev pk
  uuid=$(cat /etc/takumi/live-media 2>/dev/null) || return 0
  dev=$(readlink -f "/dev/disk/by-uuid/$uuid" 2>/dev/null) || return 0
  [[ -b "$dev" ]] || return 0
  pk=$(lsblk -ndo PKNAME "$dev" 2>/dev/null)
  printf '%s' "${pk:+/dev/$pk}"
  [[ -n "$pk" ]] || printf '%s' "$dev"
}

# --- The language (docs/setup.md). glibc's own list of what it can make: /usr/share/i18n/SUPPORTED.
TAKUMI_I18N=${TAKUMI_I18N:-/usr/share/i18n}

# setup_locale_ok <code>: glibc can make this UTF-8 locale ("fr_FR.UTF-8", "hi_IN"). Read as glibc installs the
# list ("fr_FR.UTF-8 UTF-8") and as its sources write it ("fr_FR.UTF-8/UTF-8 \").
setup_locale_ok() {
  [[ "$1" =~ ^[a-z]{2,3}_[A-Z]{2}(\.UTF-8)?(@[a-z]+)?$ && -r "$TAKUMI_I18N/SUPPORTED" ]] || return 1
  sed 's/[[:space:]]*\\$//; s|/| |' "$TAKUMI_I18N/SUPPORTED" | awk -v c="$1" '$1 == c && $2 == "UTF-8" { f = 1 } END { exit !f }'
}

# setup_locale_guess <firmware language> <country>: "fr-FR" → fr_FR.UTF-8, "de" in DE → de_DE.UTF-8; English
# (US) when glibc has no such locale.
setup_locale_guess() {
  local ll c
  ll=$(printf '%s' "$1" | sed -n 's/^\([a-zA-Z]\{2,3\}\).*/\1/p' | tr A-Z a-z)
  for c in "${ll}_$2.UTF-8" "${ll}_$2"; do
    [[ -n "$ll" ]] && setup_locale_ok "$c" && { printf '%s' "$c"; return 0; }
  done
  printf 'en_US.UTF-8'
}

# --- The first start: a computer set up for someone else, or erased, asks its owner at its next start
# (takumi setup owner, takumi-first-start.service). The mark holds the disk's temporary password, root's only.
TAKUMI_FIRST_START=${TAKUMI_FIRST_START:-/var/lib/takumi/first-start}
TAKUMI_ERASE_MARK=${TAKUMI_ERASE_MARK:-/var/lib/takumi/erase}
TAKUMI_FIRST_SUDOERS=${TAKUMI_FIRST_SUDOERS:-/etc/sudoers.d/takumi-first-start}

# The skies the setup screen paints, one palette per part of the day: the disc carries them; an installed
# computer draws them from its default theme when the first start begins (takumi setup start --owner).
setup_skies() { printf '%s' "${TAKUMI_SETUP_SKIES:-${TAKUMI_SETUP_SHARE:-/usr/share/takumi}/setup}"; }

# The people's accounts on this computer: what useradd makes for a person (UID 1000 to 59999), never one a
# package or systemd made for itself.
setup_people() { awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' "${1:-/etc/passwd}"; }
