#!/usr/bin/env bash
# Takumi's encrypted disk: helpers shared by the setup disc (commands/setup/install), commands/disk/recovery,
# commands/disk/tpm and commands/password/main. Sourced, never run; needs root for cryptsetup. See
# docs/encryption.md.
#
# The disk is LUKS2. Key slot 0 holds the owner's password; a recovery code holds two more (as shown, with
# its dashes, and without them), found again through a LUKS2 token of type "takumi-recovery"; the TPM, when
# it opens the disk, holds one more with a token of type "systemd-tpm2". Secrets reach cryptsetup and
# systemd-cryptenroll through pipes, never through a command line.

# 36 digits in six groups of six: every keyboard types digits, and none is mistaken for a letter. 120 bits.
disk_recovery_code() {
  local d="" b
  while (( ${#d} < 36 )); do
    for b in $(od -An -tu1 -N64 /dev/urandom); do
      if (( b < 250 && ${#d} < 36 )); then d+=$(( b % 10 )); fi
    done
  done
  printf '%s-%s-%s-%s-%s-%s' "${d:0:6}" "${d:6:6}" "${d:12:6}" "${d:18:6}" "${d:24:6}" "${d:30:6}"
}

disk_slots() { cryptsetup luksDump --dump-json-metadata "$1" | jq -c '[.keyslots | keys[]]'; }

# disk_add_code <device> <passphrase> <code>: the code opens the disk from now on, with its dashes or
# without. It carries 120 bits, so its slots need no slow key function.
disk_add_code() {
  local dev=$1 pass=$2 code=$3 before after c
  before=$(disk_slots "$dev")
  for c in "$code" "${code//-/}"; do
    cryptsetup luksAddKey --batch-mode --pbkdf pbkdf2 --pbkdf-force-iterations 1000 \
      --key-file=<(printf '%s' "$pass") "$dev" <(printf '%s' "$c")
  done
  after=$(disk_slots "$dev")
  jq -cn --argjson a "$after" --argjson b "$before" --arg when "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{type: "takumi-recovery", keyslots: ($a - $b), made: $when}' | cryptsetup token import --json-file=- "$dev"
}

# The recovery tokens now on a disk, one "token-id slot slot…" line each.
disk_recovery_tokens() {
  cryptsetup luksDump --dump-json-metadata "$1" \
    | jq -r '.tokens | to_entries[] | select(.value.type == "takumi-recovery") | "\(.key) \(.value.keyslots | join(" "))"'
}

# The LUKS partition under the running system: /dev/mapper/<name> → the device cryptsetup opened.
disk_luks_device() {
  local map
  map=$(basename "$(findmnt -no SOURCE / | sed 's/\[.*//')")
  cryptsetup status "$map" 2>/dev/null | awk '$1 == "device:" { print $2 }'
}

# --- The password's slot, the TPM, and how the computer starts (takumi password, takumi disk tpm) ---
# The TAKUMI_* variables point the tests at fake places; sudo clears them.

disk_cmdline=${TAKUMI_KERNEL_CMDLINE:-/etc/kernel/cmdline}
disk_greetd=${TAKUMI_GREETD_CONFIG:-/usr/share/takumi/greetd/config.toml}
disk_passwd=${TAKUMI_PASSWD:-/etc/passwd}
disk_tpm_sys=${TAKUMI_TPM:-/sys/class/tpm}

# disk_write <file> <text>: replaced in one step (a new file beside it, then a rename). As root.
disk_write() {
  local tmp
  tmp="$(dirname "$1")/.$(basename "$1").takumi"
  printf '%s\n' "$2" > "$tmp" || { rm -f "$tmp"; return 1; }
  chmod 644 "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$1"
}

# disk_opens_with <device> <passphrase> [slot]: true when the passphrase opens the disk (in that key slot only).
disk_opens_with() {
  local slot=()
  [[ -n "${3:-}" ]] && slot=(--key-slot "$3")
  printf '%s' "$2" | cryptsetup open --test-passphrase ${slot[@]+"${slot[@]}"} --key-file=- "$1" 2>/dev/null
}

# disk_change_password <device> <old> <new>: key slot 0, the password's, opens with <new> from now on and no
# longer with <old>. It fails, changing nothing, when <old> does not open slot 0. The recovery code's slots and
# any other stay as they are.
disk_change_password() {
  cryptsetup luksChangeKey --batch-mode --key-slot 0 --key-file=<(printf '%s' "$2") "$1" <(printf '%s' "$3")
}

# disk_tpm_chip: 2 (a TPM 2.0, which can open the disk), old (a TPM 1.2) or none.
disk_tpm_chip() {
  local v=""
  [[ -e "$disk_tpm_sys/tpm0" ]] || { echo none; return 0; }
  if [[ -r "$disk_tpm_sys/tpm0/tpm_version_major" ]]; then read -r v < "$disk_tpm_sys/tpm0/tpm_version_major" || true; fi
  if [[ -z "$v" || "$v" == 2 ]]; then echo 2; else echo old; fi
}

# The TPM's tokens on a disk, one "token-id slot slot…" line each (systemd-cryptenroll's own type).
disk_tpm_tokens() {
  cryptsetup luksDump --dump-json-metadata "$1" \
    | jq -r '.tokens | to_entries[] | select(.value.type == "systemd-tpm2") | "\(.key) \(.value.keyslots | join(" "))"'
}

# disk_tpm_enroll <device> <passphrase>: the TPM opens the disk while the computer starts the way it does now,
# Secure Boot in the same state with the same keys (PCR 7). An earlier TPM slot goes once the new one is in;
# the password's slot and the recovery code's stay.
disk_tpm_enroll() {
  systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 --unlock-key-file=<(printf '%s' "$2") "$1" >/dev/null 2>&1
}

# disk_tpm_remove <device> <passphrase>: the TPM no longer opens the disk; its slots and tokens go.
disk_tpm_remove() {
  local dev=$1 pass=$2 id slots s
  while read -r id slots; do
    [[ -n "$id" ]] || continue
    for s in $slots; do
      [[ "$s" == 0 ]] && continue   # never the password's own slot
      cryptsetup luksKillSlot --batch-mode --key-file=<(printf '%s' "$pass") "$dev" "$s"
    done
    cryptsetup token remove --token-id "$id" "$dev"
  done <<< "$(disk_tpm_tokens "$dev")"
}

# disk_opens_by_itself: this room starts with the TPM asked first (its kernel options say so).
disk_opens_by_itself() { grep -qs 'tpm2-device=auto' "$disk_cmdline"; }

# disk_cmdline_tpm <on|off> <uuid>: as root. rd.luks.options=<uuid>=tpm2-device=auto in /etc/kernel/cmdline,
# which every room's boot entry copies, has the initramfs (sd-encrypt) ask the TPM before the password; off
# takes it out. Other options for the disk give way to it: discards and the work queues are kept in the LUKS2
# header itself.
disk_cmdline_tpm() {
  local text want
  text=$(cat "$disk_cmdline")
  want=$(printf '%s\n' "$text" | tr -s ' \t' '\n\n' | awk -v d="rd.luks.options=$2=" 'NF && index($0, d) != 1' | tr '\n' ' ')
  want=${want% }
  [[ "$1" == on ]] && want="$want rd.luks.options=$2=tpm2-device=auto"
  want=${want# }
  [[ "$want" == "$text" ]] || disk_write "$disk_cmdline" "$want"
}

# Whose session the start opens, decided the way install/steps/40-session.sh decides it: the first person's.
disk_owner() { awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ /^\/home\// { print $1; exit }' "$disk_passwd"; }

# disk_autologin <on|off> [user]: as root. On an encrypted disk the login screen opens the session by itself
# once per start, because the disk asked for the password a moment before (greetd's [initial_session]). When
# the TPM opens the disk nobody typed anything, so that goes, and the login screen asks.
disk_autologin() {
  local f=$disk_greetd text want
  [[ -f "$f" ]] || return 0
  text=$(cat "$f")
  want=$(awk '/^\[/ { skip = ($0 == "[initial_session]") } !skip' <<< "$text")
  if [[ "$1" == on && -n "${2:-}" ]]; then
    want+=$'\n\n[initial_session]\ncommand = "takumi session start"\nuser = "'"$2"'"'
  fi
  [[ "$want" == "$text" ]] || disk_write "$f" "$want"
}

# disk_boot_editor_off <loader.conf>: as root. Nobody changes a room's kernel options at the boot menu
# (systemd-boot's editor), which could otherwise start a shell on a disk the TPM opened.
disk_boot_editor_off() {
  local f=$1 text want
  [[ -f "$f" ]] || return 0
  text=$(cat "$f")
  want=$(awk '$1 != "editor"' <<< "$text")
  if [[ -n "$want" ]]; then want+=$'\neditor no'; else want="editor no"; fi
  [[ "$want" == "$text" ]] || disk_write "$f" "$want"
}
