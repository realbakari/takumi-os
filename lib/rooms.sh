#!/usr/bin/env bash
# Takumi rooms: helpers shared by the takumi-room-* commands. Sourced, never run. See docs/atomic-rooms.md.
#
# A room is a bootable Btrfs subvolume, @rooms/<YYYYMMDD-HHMMSS>. Each room keeps its own kernel in its own
# /boot; staging copies it to the boot partition (ESP) under /takumi/<room>/ beside a boot entry, so going
# back to a room brings back that room's kernel too. Room state lives outside the rooms, in
# /var/lib/takumi/state/<room>, so a snapshot never inherits it.

TAKUMI_TOP=${TAKUMI_TOP:-/var/lib/takumi/.btrfs-top}
TAKUMI_STATE=${TAKUMI_STATE:-/var/lib/takumi/state}

rooms_current() { findmnt -no OPTIONS / | sed -n 's/.*subvol=\/@rooms\/\([^,]*\).*/\1/p'; }
rooms_rootdev() { findmnt -no SOURCE / | sed 's/\[.*//'; }
# / is on an encrypted disk (the setup disc's installs: docs/encryption.md).
rooms_encrypted() { [[ "$(lsblk -ndo TYPE "$(rooms_rootdev)" 2>/dev/null)" == crypt ]]; }
# systemd-detect-virt needs root to look at /proc/1/root; as a user it fails, which would read as "no".
rooms_in_chroot() { if [[ $EUID -eq 0 ]]; then systemd-detect-virt --chroot --quiet; else sudo systemd-detect-virt --chroot --quiet; fi; }

# Where the boot partition is mounted. /efi on Takumi installs; /boot on a system converted before the move.
rooms_esp() {
  local m
  for m in /efi /boot /boot/efi; do
    [[ "$(findmnt -no FSTYPE "$m" 2>/dev/null)" == vfat ]] && { echo "$m"; return 0; }
  done
  return 1
}

rooms_mount_top() {
  mountpoint -q "$TAKUMI_TOP" && return 0
  mkdir -p "$TAKUMI_TOP"
  mount -o subvolid=5,noatime "$(rooms_rootdev)" "$TAKUMI_TOP"
}
rooms_path() { echo "$TAKUMI_TOP/@rooms/$1"; }
rooms_names() { [[ -d "$TAKUMI_TOP/@rooms" ]] || return 0; find "$TAKUMI_TOP/@rooms" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }

state_get() { local f="$TAKUMI_STATE/$1"; [[ -f "$f" ]] || return 0; sed -n "s/^$2=//p" "$f" | tail -n 1; }
state_set() {
  mkdir -p "$TAKUMI_STATE"
  local f="$TAKUMI_STATE/$1"; touch "$f"
  if grep -q "^$2=" "$f"; then sed -i "s|^$2=.*|$2=$3|" "$f"; else printf '%s=%s\n' "$2" "$3" >> "$f"; fi
}

# The default boot entry's room, from systemd-boot. No pipe into head: under pipefail a cut-off producer fails.
rooms_default() {
  local ids
  ids=$(bootctl list --json=short 2>/dev/null | jq -r '.[] | select(.isDefault == true) | .id' 2>/dev/null) || true
  awk 'match($0, /^takumi-[0-9]{8}-[0-9]{6}/) { print substr($0, 8, 15); exit }' <<< "$ids"
}

# "20261108-093000" → "Sun 8 Nov 09:30"; a restore point says so, by its name when it has one:
# "Mon 9 Nov 10:00 (Before trying Docker)", "Mon 9 Nov 10:00 (restore point)".
rooms_label() {
  local n=$1 when name
  when=$(date -d "${n:0:4}-${n:4:2}-${n:6:2} ${n:9:2}:${n:11:2} UTC" '+%a %-d %b %H:%M' 2>/dev/null || echo "$n")
  if [[ "$(state_get "$n" point)" == yes ]]; then
    name=$(state_get "$n" name)
    echo "$when (${name:-restore point})"
  else
    echo "$when"
  fi
}

# A restore point's name as state keeps it: one line, no character state_set's sed or a boot entry would
# misread, at most 48 characters.
rooms_point_name() { printf '%s' "$*" | tr -d '|&\\/\000-\037' | sed -e 's/^ *//' -e 's/ *$//' | awk '{ print substr($0, 1, 48); exit }'; }

# The room "Go back to the previous system" starts: a restore point saved in the running room, or else the
# newest good room older than it (one you went back from counts as good). Nothing when there is none.
rooms_previous() {
  local cur n st
  cur=$(rooms_current)
  for n in $(rooms_names | sort -r); do
    [[ "$n" != "$cur" ]] || continue
    st=$(state_get "$n" status)
    [[ "$st" == good || "$st" == left ]] || continue
    if [[ "$(state_get "$n" point)" == yes ]]; then
      [[ "$(state_get "$n" parent)" == "$cur" ]] && { echo "$n"; return 0; }
    elif [[ "$n" < "$cur" ]]; then
      echo "$n"; return 0
    fi
  done
  return 0
}

# The kernel image and initramfs inside a room. x86_64 Arch: vmlinuz-linux; Arch Linux ARM: Image.
rooms_kernel() {
  local r=$1 k
  for k in vmlinuz-linux Image vmlinuz-linux-lts; do [[ -f "$r/boot/$k" ]] && { echo "$r/boot/$k"; return 0; }; done
  return 1
}
rooms_initramfs() {
  local r=$1 i
  for i in initramfs-linux.img initramfs-linux-lts.img; do [[ -f "$r/boot/$i" ]] && { echo "$r/boot/$i"; return 0; }; done
  return 1
}

# Kernel options for a room: the room's /etc/kernel/cmdline when it has one, else the running system's,
# minus anything that names a room or an image. Then this room's subvolume.
rooms_cmdline() {
  local r=$1 name=$2 src
  if [[ -s "$r/etc/kernel/cmdline" ]]; then src=$(cat "$r/etc/kernel/cmdline"); else src=$(cat /proc/cmdline); fi
  awk -v room="$name" '{
    for (i = 1; i <= NF; i++) if ($i !~ /^(BOOT_IMAGE|initrd|rootflags)=/) printf "%s ", $i
  } END { printf "rootflags=subvol=/@rooms/%s\n", room }' <<< "$src"
}

# Copy a room's kernel to the ESP and write its entry. $2: boot tries for a new room ("" for none).
rooms_write_entry() {
  local name=$1 tries=${2:-} esp r k i dir u file
  esp=$(rooms_esp) || { echo "rooms: no boot partition found" >&2; return 1; }
  r=$(rooms_path "$name")
  [[ "$name" == "$(rooms_current)" ]] && r=/      # the room this runs in (an install's chroot included)
  k=$(rooms_kernel "$r") || { echo "rooms: room $name has no kernel in /boot" >&2; return 1; }
  i=$(rooms_initramfs "$r") || { echo "rooms: room $name has no initramfs in /boot" >&2; return 1; }
  dir="$esp/takumi/$name"; mkdir -p "$dir" "$esp/loader/entries"
  install -m644 "$k" "$dir/linux"
  # Secure Boot with this computer's own keys (docs/security.md): the firmware starts only a signed kernel.
  if [[ -f /var/lib/sbctl/keys/db/db.key ]] && command -v sbctl >/dev/null; then
    sbctl sign "$dir/linux" >/dev/null || { echo "rooms: room $name's kernel could not be signed for Secure Boot" >&2; return 1; }
  fi
  install -m644 "$i" "$dir/initramfs.img"
  local initrds=""
  for u in intel-ucode.img amd-ucode.img; do
    [[ -f "$r/boot/$u" ]] && { install -m644 "$r/boot/$u" "$dir/$u"; initrds+="initrd     /takumi/$name/$u"$'\n'; }
  done
  rm -f "$esp/loader/entries/takumi-$name.conf" "$esp/loader/entries/takumi-$name+"*.conf
  file="$esp/loader/entries/takumi-$name${tries:++$tries}.conf"
  {
    printf 'title      Takumi \xc2\xb7 %s\n' "$(rooms_label "$name")"
    printf 'sort-key   takumi\nversion    %s\n' "$name"
    printf 'linux      /takumi/%s/linux\n' "$name"
    printf '%s' "$initrds"
    printf 'initrd     /takumi/%s/initramfs.img\n' "$name"
    printf 'options    %s\n' "$(rooms_cmdline "$r" "$name")"
  } > "$file"
}

# Delete a room: nested subvolumes first (deepest first), then the room, its kernel copy, entry and state.
rooms_delete() {
  local name=$1 r esp sub
  r=$(rooms_path "$name")
  if [[ -d "$r" ]]; then
    while read -r sub; do
      [[ -n "$sub" ]] && btrfs subvolume delete "$TAKUMI_TOP/$sub" >/dev/null
    done < <(btrfs subvolume list -o "$r" 2>/dev/null | awk '{print $NF}' | sort -r)
    btrfs subvolume delete "$r" >/dev/null
  fi
  if esp=$(rooms_esp); then rm -rf "${esp:?}/takumi/$name"; rm -f "$esp/loader/entries/takumi-$name.conf" "$esp/loader/entries/takumi-$name+"*.conf; fi
  rm -f "$TAKUMI_STATE/$name"
}

# What a new room inherits from the running one at the last moment: things people change between
# preparing an update and restarting into it.
TAKUMI_CARRY=(
  /etc/NetworkManager/system-connections /var/lib/bluetooth
  /etc/passwd /etc/shadow /etc/group /etc/gshadow
  /etc/hostname /etc/localtime /etc/locale.conf /etc/vconsole.conf
  /var/lib/fprint /etc/cups/printers.conf
  /etc/systemd/logind.conf.d/takumi-lid.conf /etc/systemd/sleep.conf.d/takumi.conf
  /etc/ufw/user.rules /etc/ufw/user6.rules /etc/ufw/ufw.conf /etc/default/ufw /etc/takumi/firewall /var/lib/tailscale
)
rooms_carry() {
  local r p; r=$(rooms_path "$1")
  for p in "${TAKUMI_CARRY[@]}"; do
    [[ -e "$p" ]] || continue
    mkdir -p "$r$(dirname "$p")"
    if [[ -d "$p" ]]; then rsync -a --delete "$p/" "$r$p/"; else cp -a "$p" "$r$p"; fi
  done
}
