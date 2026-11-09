#!/usr/bin/env bash
# Run from the archboot live system inside the VM, with the repo mounted at /share (9p).
# Partitions /dev/vda, pacstraps Arch Linux ARM, installs systemd-boot, creates the `takumi` user,
# and runs the ordinary Takumi installer in the chroot. Prints TAKUMI PROVISION DONE at the end.
# VM only: no LUKS, passwordless sudo, password "takumi". See docs/vm.md.
set -euo pipefail
disk=${TAKUMI_VM_TARGET_DISK:-/dev/vda}
share=${TAKUMI_VM_SHARE:-/share}
user=takumi
echo "== takumi provision: $disk"

[[ -d "$share/install" ]] || { echo "repo not mounted at $share"; exit 1; }
for i in $(seq 1 30); do curl -fsS --max-time 5 https://archlinuxarm.org >/dev/null 2>&1 && break; sleep 2; done

echo "== partition"
sfdisk --wipe always --wipe-partitions always "$disk" <<'PT'
label: gpt
size=1GiB, type=uefi, name=EFI
type=linux, name=takumi
PT
udevadm settle || sleep 2
mkfs.fat -F32 -n EFI "${disk}1" >/dev/null
mkfs.btrfs -f -L takumi "${disk}2" >/dev/null

echo "== subvolumes"
room=$(date -u +%Y%m%d-%H%M%S)
mount "${disk}2" /mnt
btrfs subvolume create /mnt/@rooms >/dev/null
btrfs subvolume create "/mnt/@rooms/$room" >/dev/null
for s in @home @var-log @var-lib-takumi; do btrfs subvolume create "/mnt/$s" >/dev/null; done
umount /mnt
opts=noatime,compress=zstd:1
mount -o "$opts,subvol=/@rooms/$room" "${disk}2" /mnt
mkdir -p /mnt/{boot,efi,home,var/log,var/lib/takumi}
mount -o "$opts,subvol=/@home" "${disk}2" /mnt/home
mount -o "$opts,subvol=/@var-log" "${disk}2" /mnt/var/log
mount -o "$opts,subvol=/@var-lib-takumi" "${disk}2" /mnt/var/lib/takumi
# The boot partition is /efi: each room keeps its kernel in its own /boot (docs/atomic-rooms.md).
mkdir -p /mnt/efi
mount "${disk}1" /mnt/efi

echo "== pacstrap"
pacman -Sy --noconfirm >/dev/null
pacstrap -K /mnt base base-devel linux-aarch64 btrfs-progs dosfstools networkmanager openssh sudo git rsync jq curl archlinuxarm-keyring cage wlr-randr 2>&1 | tail -3
genfstab -U /mnt > /mnt/etc/fstab
uuid=$(blkid -s UUID -o value "${disk}2")

echo "== configure"
arch-chroot /mnt /bin/bash -e <<CH
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen >/dev/null
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo takumi-vm > /etc/hostname
pacman-key --init >/dev/null 2>&1; pacman-key --populate archlinuxarm >/dev/null 2>&1
systemctl enable NetworkManager sshd >/dev/null
useradd -m -G wheel -s /bin/bash $user
echo "$user:takumi" | chpasswd
echo "root:takumi" | chpasswd
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-takumi-vm
chmod 440 /etc/sudoers.d/10-takumi-vm
bootctl --esp-path=/efi install >/dev/null
echo "root=UUID=$uuid rw console=tty0 console=ttyAMA0" > /etc/kernel/cmdline
mkinitcpio -P
mkdir -p /efi/takumi/$room /efi/loader/entries /var/lib/takumi/state
cp /boot/Image /efi/takumi/$room/linux
cp /boot/initramfs-linux.img /efi/takumi/$room/initramfs.img
cat > /efi/loader/entries/takumi-$room.conf <<E
title      Takumi first start
sort-key   takumi
version    $room
linux      /takumi/$room/linux
initrd     /takumi/$room/initramfs.img
options    root=UUID=$uuid rw console=tty0 console=ttyAMA0 rootflags=subvol=/@rooms/$room
E
printf 'default takumi-%s.conf\ntimeout 2\n' "$room" > /efi/loader/loader.conf
echo "status=good" > /var/lib/takumi/state/$room
CH
# Closing the VM's window is pulling the plug, and a host key written just before can come back empty;
# sshd then refuses to start for good. So sshd makes any missing or empty key again before it starts
# ($$ is a plain $ to systemd).
mkdir -p /mnt/etc/systemd/system/sshd.service.d
cat > /mnt/etc/systemd/system/sshd.service.d/takumi-vm.conf <<'UNIT'
[Service]
ExecStartPre=/bin/sh -c 'for k in /etc/ssh/ssh_host_*_key; do [ -s "$$k" ] || rm -f "$$k" "$$k.pub"; done; /usr/bin/ssh-keygen -A'
UNIT

echo "== vm marker"
# VM only: no 3D here, so the login screen and the session draw in software (commands/greeter/main,
# commands/session/start).
mkdir -p /mnt/etc/takumi && echo "qemu without 3D" > /mnt/etc/takumi/vm

echo "== takumi installer"
mkdir -p "/mnt/home/$user/.local/share"
mkdir -p "/mnt/home/$user/.local/share/takumi"
if command -v rsync >/dev/null; then rsync -a --exclude preview --exclude .git "$share/" "/mnt/home/$user/.local/share/takumi/"
else cp -a "$share/." "/mnt/home/$user/.local/share/takumi/"; rm -rf "/mnt/home/$user/.local/share/takumi/preview"; fi
arch-chroot /mnt chown -R "$user:$user" "/home/$user"
arch-chroot /mnt su - "$user" -c 'TAKUMI_IN_CHROOT=1 bash ~/.local/share/takumi/install/run.sh' || { echo "takumi installer failed; see /mnt/home/$user/.local/state/takumi/install.log"; exit 1; }

umount -R /mnt
echo "TAKUMI PROVISION DONE"
