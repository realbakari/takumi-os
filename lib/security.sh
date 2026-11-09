#!/usr/bin/env bash
# Signing in and starting safely: fingerprints through fprintd, the PAM lines that let a finger answer for sudo
# and polkit, passwords checked without an argument, and Secure Boot through sbctl. Sourced by
# commands/security/*, commands/password/main, commands/disk/tpm, commands/palette/security and
# install/steps/27-security.sh; runs on bash 3.2. See docs/security.md.
#
# The TAKUMI_* variables point the tests at fake places. sudo clears them, so a command running as root always
# reads the real ones.

security_pam_dir=${TAKUMI_PAM_DIR:-/etc/pam.d}
security_vendor_pam=${TAKUMI_VENDOR_PAM_DIR:-/usr/lib/pam.d}
security_fprint_dir=${TAKUMI_FPRINT_DIR:-/var/lib/fprint}
security_lid=${TAKUMI_LID:-/proc/acpi/button/lid}
security_efivars=${TAKUMI_EFIVARS:-/sys/firmware/efi/efivars}
security_sbctl=${TAKUMI_SBCTL_DIR:-/var/lib/sbctl}
security_usr_lib=${TAKUMI_USR_LIB:-/usr/lib}
security_fwupd_conf=${TAKUMI_FWUPD_CONF:-/etc/fwupd/fwupd.conf}

# security_write <file> <text>: the file holds the text, replaced in one step (a new file beside it, then a
# rename), so nothing ever reads half of it. As root for system files.
security_write() {
  local tmp
  tmp="$(dirname "$1")/.$(basename "$1").takumi"
  printf '%s\n' "$2" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod 644 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$1"
}

# --- Passwords ---

# security_password_is <user> <password>: checked the way the Lock checks it, by pam_unix's own helper, which
# reads it on stdin (ended by a NUL) and never as an argument.
security_password_is() { printf '%s\0' "$2" | unix_chkpwd "$1" nonull >/dev/null 2>&1; }

# security_sudo_stdin <password> <command...>: the command as root with a password the Core already asked for.
# sudo reads it from stdin's first line and hands the rest of stdin to the command. setsid takes the terminal
# away first, so sudo goes straight to that line instead of waiting for a finger (the PAM lines below ask for
# one only at a terminal). The caller names the files the command changes.
security_sudo_stdin() {
  local pw=$1 run
  shift
  run=(sudo -k -S -p '' "$@")   # the files the caller names
  command -v setsid >/dev/null && run=(setsid -w "${run[@]}")
  { printf '%s\n' "$pw"; cat; } | "${run[@]}" 2>/dev/null
}

# --- Fingerprints ---

# security_fingers <user>: the user's enrolled fingers, one label per line ("right-index-finger"). Fails when
# fprintd is missing or sees no reader.
security_fingers() {
  local out
  command -v fprintd-list >/dev/null || return 1
  out=$(LC_ALL=C fprintd-list "$1" 2>/dev/null) || true
  [[ "$out" == *"Device at "* ]] || return 1
  sed -n 's/^ - #[0-9]*: //p' <<< "$out"
}
security_count() { if [[ -z "$1" ]]; then echo 0; else printf '%s\n' "$1" | wc -l | tr -d ' '; fi; }

# The labels fprintd keeps prints under, in the order Takumi offers them. fprintd never checks a label against
# the finger that touches, so a label only keeps two prints apart.
security_finger_order="right-index-finger left-index-finger right-thumb left-thumb right-middle-finger left-middle-finger right-ring-finger left-ring-finger right-little-finger left-little-finger"
security_next_finger() {  # <enrolled, one per line>: the first free label
  local f
  for f in $security_finger_order; do
    [[ $'\n'"$1"$'\n' == *$'\n'"$f"$'\n'* ]] || { echo "$f"; return 0; }
  done
  return 1
}

# A closed lid covers the sensor on a laptop.
security_lid_closed() {
  local f s
  for f in "$security_lid"/*/state; do
    [[ -r "$f" ]] || continue
    s=""; read -r _ s < "$f" || true
    [[ "$s" == closed ]] && return 0
  done
  return 1
}

# security_any_prints: someone on this computer has a fingerprint (as root: fprintd's folder is root's alone).
security_any_prints() { [[ -n "$(find "$security_fprint_dir" -type f 2>/dev/null)" ]]; }

# --- A finger for sudo and polkit ---
# sudo's and polkit's PAM files belong to their packages and have no folder for extras, so Takumi puts four lines
# of its own in front of their "auth include system-auth": a finger first, then the password as before. pam_exec
# asks takumi security finger-ready whether a finger may be asked for now: not for sudo without a terminal (a
# Takumi command whose password comes from the Core), not with the lid closed. Ten seconds without a touch, or
# three wrong fingers, and the password is asked.
security_pam_files="sudo polkit-1"
security_pam_mark='# takumi-fingerprint'
security_pam_block() {
  printf '%s\n' "$security_pam_mark: begin (takumi security fingerprint; docs/security.md)" \
    'auth       [success=ignore default=1]  pam_exec.so quiet /usr/lib/takumi/commands/security/finger-ready' \
    'auth       sufficient                  pam_fprintd.so timeout=10' \
    "$security_pam_mark: end"
}
# security_pam_without <file> [mark]: the file's text without Takumi's lines (the finger's, or another mark's).
security_pam_without() {
  [[ -r "$1" ]] || return 1
  M=${2:-$security_pam_mark} awk 'index($0, ENVIRON["M"] ": begin") == 1 { skip = 1; next }
    skip && index($0, ENVIRON["M"] ": end") == 1 { skip = 0; next }
    !skip' "$1"
}
# security_pam_with <file>: the file's text with Takumi's lines in front of its first auth line for system-auth.
# Fails when it has none: a file someone rewrote by hand stays as it is.
security_pam_with() {
  local text
  text=$(security_pam_without "$1") || return 1
  B=$(security_pam_block) awk '!done && $1 == "auth" && ($2 == "include" || $2 == "substack") && $3 == "system-auth" { print ENVIRON["B"]; done = 1 }
    { print }
    END { exit !done }' <<< "$text"
}
security_finger_pam_is_on() { grep -qs "^$security_pam_mark: begin" "$security_pam_dir/sudo" "$security_pam_dir/polkit-1"; }
# security_finger_pam <on|off>: as root. Puts the lines in, or takes them out. A file is written only when its
# text changes, and in one step. A package that keeps its file in /usr/lib/pam.d gets a copy in /etc/pam.d with
# the lines, which PAM reads first, and the copy goes again with them. Says what changed.
security_finger_pam() {
  local name f v src want
  for name in $security_pam_files; do
    f="$security_pam_dir/$name" v="$security_vendor_pam/$name"   # /etc/pam.d/sudo, /etc/pam.d/polkit-1
    if [[ "$1" == on ]]; then
      if [[ -f "$f" ]]; then src=$f; elif [[ -f "$v" ]]; then src=$v; else continue; fi
      want=$(security_pam_with "$src") || { echo "security: $src has no auth line for system-auth; left as it is" >&2; continue; }
    else
      grep -qs "^$security_pam_mark: begin" "$f" || continue
      want=$(security_pam_without "$f")
      if [[ -f "$v" && "$want" == "$(cat "$v")" ]]; then
        rm -f "$f"; echo "security: fingerprint off, $f is the package's own again"; continue
      fi
    fi
    if [[ -f "$f" && "$want" == "$(cat "$f")" ]]; then continue; fi
    security_write "$f" "$want" || return 1
    echo "security: fingerprint $1 in $f"
  done
}

# --- Secure Boot ---

# security_efivar <name>: the value (0 or 1) of one of UEFI's own variables, after its four bytes of
# attributes. Fails when the firmware does not have it.
security_efivar() {
  local f="$security_efivars/$1-8be4df61-93ca-11d2-aa0d-00e098032b8c" v
  [[ -r "$f" ]] || return 1
  v=$(od -An -tu1 -j4 -N1 "$f" 2>/dev/null | tr -d ' \n')
  [[ -n "$v" ]] || return 1
  printf '%s' "$v"
}
# security_boot_state: none (the computer starts without UEFI), unsupported (its firmware has no Secure Boot),
# setup (the firmware has forgotten its keys and takes new ones), on or off.
security_boot_state() {
  local sb setup
  [[ -d "$security_efivars" ]] || { echo none; return 0; }
  sb=$(security_efivar SecureBoot) || { echo unsupported; return 0; }
  setup=$(security_efivar SetupMode) || setup=0
  if [[ "$setup" == 1 ]]; then echo setup; elif [[ "$sb" == 1 ]]; then echo on; else echo off; fi
}
# The firmware has a start entry for Windows (its descriptions are UTF-16: the NULs go before comparing).
security_windows() {
  local f d
  for f in "$security_efivars"/Boot[0-9A-F][0-9A-F][0-9A-F][0-9A-F]-8be4df61-93ca-11d2-aa0d-00e098032b8c; do
    [[ -r "$f" ]] || continue
    d=$(LC_ALL=C tr -d '\000' < "$f" 2>/dev/null || true)
    [[ "$d" == *"Windows Boot Manager"* ]] && return 0
  done
  return 1
}
# This computer's own keys, made by sbctl (as root: its folder is root's alone).
security_own_keys() { [[ -f "$security_sbctl/keys/db/db.key" ]]; }
# The boot partition systemd-boot starts from: beside Windows the shared one, else the one each room's kernel
# is on (rooms_esp, lib/rooms.sh). As root.
security_esp() {
  local p
  p=$(bootctl --print-esp-path 2>/dev/null) && [[ -n "$p" ]] && { echo "$p"; return 0; }
  rooms_esp
}
# security_sign_all <esp> <boot>: as root, with this computer's own keys. systemd-boot and fwupd's UEFI program
# are signed beside themselves as .signed and kept in sbctl's list: bootctl copies the signed systemd-boot, and
# sbctl's pacman hook signs every new version, inside a room an update builds too (only paths every room has go
# in the list). The copies on the boot partitions and every room's kernel are signed where they are.
security_sign_all() {
  local esp=$1 boot=$2 f
  for f in "$security_usr_lib"/systemd/boot/efi/systemd-boot*.efi "$security_usr_lib"/fwupd/efi/fwupd*.efi; do
    [[ -f "$f" ]] || continue
    sbctl sign -s -o "$f.signed" "$f" >/dev/null || return 1
  done
  for f in "$esp"/EFI/systemd/systemd-boot*.efi "$esp"/EFI/BOOT/BOOT*.EFI "$boot"/takumi/*/linux; do
    [[ -f "$f" ]] || continue
    sbctl sign "$f" >/dev/null || return 1
  done
}
# security_fwupd_own_keys: as root. With this computer's own keys a firmware update starts fwupd's own signed
# program instead of shim, which only Microsoft's keys vouch for (fwupd.conf's DisableShimForSecureBoot).
security_fwupd_own_keys() {
  local f=$security_fwupd_conf want
  [[ -f "$f" ]] || return 0
  want=$(awk '
    /^\[/ { if (sec && !done) { print "DisableShimForSecureBoot=true"; done = 1 } sec = ($0 == "[uefi_capsule]") }
    sec && /^[[:space:]]*DisableShimForSecureBoot[[:space:]]*=/ { if (!done) print "DisableShimForSecureBoot=true"; done = 1; next }
    { print }
    END { if (!done) { if (!sec) printf "\n[uefi_capsule]\n"; print "DisableShimForSecureBoot=true" } }' "$f")
  [[ "$want" == "$(cat "$f")" ]] && return 0
  security_write "$f" "$want"
}

# --- The login keyring ---
# gnome-keyring keeps apps' passwords in the "login" keyring, locked by your password. pam_gnome_keyring opens it
# with the password you sign in with: its auth line keeps the password, its session line starts the keyring and
# opens it, and when the keyring already runs (the Lock) the auth line opens it at once.
# https://wiki.gnome.org/Projects/GnomeKeyring/Pam
# The login screen's PAM file belongs to greetd and has no folder for extras, so Takumi adds its lines at its end,
# between marks, as for the finger above. The greeter's own account starts no keyring.
security_keyring_files="greetd"
security_keyring_mark='# takumi-keyring'
security_keyring_block() {
  printf '%s\n' "$security_keyring_mark: begin (the login keyring opens with your password; docs/security.md)" \
    'auth       optional                    pam_gnome_keyring.so' \
    'session    [success=1 default=ignore]  pam_succeed_if.so quiet user = greeter' \
    'session    optional                    pam_gnome_keyring.so auto_start' \
    "$security_keyring_mark: end"
}
security_keyring_pam_is_on() { grep -qs "^$security_keyring_mark: begin" "$security_pam_dir/greetd"; }
# security_keyring_pam <on|off>: as root. Adds the lines to the end of greetd's PAM file, or takes them out. A
# file is written only when it changes, in one step; a vendor file in /usr/lib/pam.d gets a copy in /etc/pam.d.
security_keyring_pam() {
  local name f v src want
  for name in $security_keyring_files; do
    f="$security_pam_dir/$name" v="$security_vendor_pam/$name"   # /etc/pam.d/greetd
    if [[ "$1" == on ]]; then
      if [[ -f "$f" ]]; then src=$f; elif [[ -f "$v" ]]; then src=$v; else continue; fi
      want=$(security_pam_without "$src" "$security_keyring_mark") || continue
      want=$(printf '%s\n%s' "$want" "$(security_keyring_block)")
    else
      grep -qs "^$security_keyring_mark: begin" "$f" || continue
      want=$(security_pam_without "$f" "$security_keyring_mark")
      if [[ -f "$v" && "$want" == "$(cat "$v")" ]]; then rm -f "$f"; echo "security: keyring off, $f is the package's own again"; continue; fi
    fi
    if [[ -f "$f" && "$want" == "$(cat "$f")" ]]; then continue; fi
    security_write "$f" "$want" || return 1
    echo "security: the login keyring $1 in $f"
  done
}

# security_keyring_rekey: your password, then the new one, on stdin, one per line. The login keyring's password
# becomes the new one, through gnome-keyring's own D-Bus method for it (ChangeWithMasterPassword, on its
# org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface), on one connection that first opens a plain
# Secret Service session: bash cannot hold a D-Bus connection open, so python3 with GObject does it, reading
# the passwords from stdin. As you, in your session. Exit: 0 changed, 2 no keyring or no python3/GObject here,
# 3 there is no login keyring, 4 the keyring refused (it was locked with another password).
read -r -d '' security_keyring_py <<'PY' || true
import sys
try:
    from gi.repository import Gio, GLib
except Exception:
    sys.exit(2)
old = sys.stdin.readline().rstrip("\n")
new = sys.stdin.readline().rstrip("\n")
root = "/org/freedesktop/secrets"
login = root + "/collection/login"
try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
except Exception:
    sys.exit(2)
def call(path, iface, method, args, rtype):
    return bus.call_sync("org.freedesktop.secrets", path, iface, method, args,
                         GLib.VariantType(rtype), Gio.DBusCallFlags.NONE, 15000, None)
try:
    session = call(root, "org.freedesktop.Secret.Service", "OpenSession",
                   GLib.Variant("(sv)", ("plain", GLib.Variant("s", ""))), "(vo)").unpack()[1]
except Exception:
    sys.exit(2)
try:
    call(login, "org.freedesktop.DBus.Properties", "Get",
         GLib.Variant("(ss)", ("org.freedesktop.Secret.Collection", "Label")), "(v)")
except Exception:
    sys.exit(3)
def secret(p):
    return (session, [], list(p.encode("utf-8")), "text/plain")
try:
    call(root, "org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface", "ChangeWithMasterPassword",
         GLib.Variant("(o(oayays)(oayays))", (login, secret(old), secret(new))), "()")
except Exception:
    sys.exit(4)
PY
security_keyring_rekey() {
  command -v python3 >/dev/null || return 2
  python3 -c "$security_keyring_py" 2>/dev/null
}

# --- Ten tries, then two minutes ---
# pam_faillock reads only /etc/security/faillock.conf, which belongs to the pam package and has no folder for
# extras. Takumi's etc/security/faillock.conf holds the lines it wants; security_faillock sets each of them in
# the real file, in place of the same setting (commented out or not), and keeps everything else. pacman keeps the
# changed file across pam's updates (it is in pam's backup list) and leaves its new version beside it as .pacnew.
# https://man.archlinux.org/man/faillock.conf.5
security_faillock_conf=${TAKUMI_FAILLOCK_CONF:-/etc/security/faillock.conf}
# security_faillock <takumi's file>: as root. Says when it changed something.
security_faillock() {
  local f=$security_faillock_conf want
  [[ -r "$1" ]] || return 1
  if [[ ! -f "$f" ]]; then
    mkdir -p "$(dirname "$f")"; security_write "$f" "$(cat "$1")" || return 1
    echo "security: $f written"; return 0
  fi
  want=$(awk -F'=' '
    NR == FNR { if ($0 ~ /^[[:space:]]*[a-z_]+[[:space:]]*=/) { k = $1; gsub(/[[:space:]]/, "", k); v[k] = $0; order[++n] = k }; next }
    { line = $0; k = line; sub(/^[[:space:]]*#[[:space:]]*/, "", k); split(k, kv, "="); k = kv[1]; gsub(/[[:space:]]/, "", k)
      if ((k in v) && !(k in done) && (line ~ /^[[:space:]]*#?[[:space:]]*[a-z_]+[[:space:]]*=/)) { print v[k]; done[k] = 1; next }
      if ((k in v) && (k in done) && line ~ /^[[:space:]]*[a-z_]+[[:space:]]*=/) next
      print }
    END { for (i = 1; i <= n; i++) if (!(order[i] in done)) print v[order[i]] }' "$1" "$f")
  [[ "$want" == "$(cat "$f")" ]] && return 0
  security_write "$f" "$want" || return 1
  echo "security: ten tries before a two-minute wait, in $f"
}
