#!/usr/bin/env bash
set -euo pipefail
# Rooms: the update and undo model (docs/atomic-rooms.md). The last real step, so the first room already
# holds everything the earlier steps installed. Needs Btrfs and systemd-boot; anything else keeps updating
# in place, and says so.
. "$TAKUMI_PATH/lib/rooms.sh"
in_chroot=no; rooms_in_chroot && in_chroot=yes

if [[ "$(findmnt -no FSTYPE /)" != btrfs ]] || ! sudo bootctl is-installed >/dev/null 2>&1; then
  echo "rooms: off (root is $(findmnt -no FSTYPE /), systemd-boot $(sudo bootctl is-installed 2>/dev/null || echo no))"
  echo "rooms: updates on this computer happen in place and cannot be undone"
  exit 0
fi

mount_top() {
  sudo mkdir -p "$TAKUMI_TOP"
  mountpoint -q "$TAKUMI_TOP" || sudo mount -o subvolid=5,noatime "$(rooms_rootdev)" "$TAKUMI_TOP"
}
fstab_top() {   # $1: the fstab to edit
  grep -qs " $TAKUMI_TOP " "$1" && return 0
  echo "UUID=$(sudo blkid -s UUID -o value "$(rooms_rootdev)") $TAKUMI_TOP btrfs subvolid=5,noatime 0 0" | sudo tee -a "$1" >/dev/null
}
enable_units() {   # $1: optional --root
  # reenable: drop links an older [Install] section left behind, then link as the units say now.
  sudo systemctl ${1:+--root="$1"} reenable takumi-room-health.service takumi-room-accept.service >/dev/null 2>&1 || true
}

cur=$(rooms_current)
if [[ -n "$cur" ]]; then
  mount_top; fstab_top /etc/fstab
  [[ -s /etc/kernel/cmdline || "$in_chroot" == yes ]] || \
    awk '{for (i = 1; i <= NF; i++) if ($i !~ /^(BOOT_IMAGE|initrd|rootflags)=/) printf "%s ", $i; print ""}' /proc/cmdline | sudo tee /etc/kernel/cmdline >/dev/null
  [[ -n "$(state_get "$cur" status)" ]] || { sudo env TAKUMI_STATE="$TAKUMI_STATE" bash -c ". '$TAKUMI_PATH/lib/rooms.sh'; state_set '$cur' status good"; }
  enable_units
  if [[ "$in_chroot" == no ]]; then
    sudo takumi room kernel-sync
    sudo bootctl set-default "takumi-$cur.conf" >/dev/null 2>&1 || echo "rooms: could not set the default entry; loader.conf decides"
  fi
  echo "rooms: on; this system is room $cur"
  exit 0
fi

# Convert: the running root becomes the first room. Untested on real hardware; see docs/atomic-rooms.md.
subvol=$(findmnt -no OPTIONS / | sed -n 's/.*subvol=\([^,]*\).*/\1/p')
mount_top
first=$(date -u +%Y%m%d-%H%M%S)
new="$TAKUMI_TOP/@rooms/$first"
sudo mkdir -p "$TAKUMI_TOP/@rooms"
sudo btrfs subvolume snapshot "$TAKUMI_TOP/${subvol#/}" "$new" >/dev/null
# Inside the new room: / is the room, and the boot partition moves from /boot to /efi so the room keeps its
# own kernel in its own /boot.
sudo sed -i "s|subvol=${subvol}\([,[:space:]]\)|subvol=/@rooms/$first\1|" "$new/etc/fstab"
if [[ "$(rooms_esp)" == /boot ]]; then
  for f in /boot/vmlinuz-linux /boot/Image /boot/initramfs-linux.img /boot/intel-ucode.img /boot/amd-ucode.img; do
    [[ -f "$f" ]] && sudo cp -a "$f" "$new/boot/"
  done
  sudo sed -i 's|^\(\S\+\s\+\)/boot\(\s\+vfat\)|\1/efi\2|' "$new/etc/fstab"
  sudo mkdir -p "$new/efi"
fi
fstab_top "$new/etc/fstab"
awk '{for (i = 1; i <= NF; i++) if ($i !~ /^(BOOT_IMAGE|initrd|rootflags)=/) printf "%s ", $i; print ""}' /proc/cmdline | sudo tee "$new/etc/kernel/cmdline" >/dev/null
enable_units "$new"
sudo env TAKUMI_TOP="$TAKUMI_TOP" bash -c ". '$TAKUMI_PATH/lib/rooms.sh'; rooms_write_entry '$first' ''; state_set '$first' status good"
sudo bootctl set-default "takumi-$first.conf" >/dev/null
echo "rooms: the first room ($first) is ready; restart to enter it"
