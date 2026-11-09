#!/usr/bin/env bash
# Build Takumi's setup disc: an image that starts the setup screen, written as it is to a USB stick or given
# to a virtual machine as its CD. It carries every package an install needs, so installing needs no
# network. Run as root on Arch Linux (x86_64) or Arch Linux ARM (aarch64); the image is for the architecture
# it is built on. See docs/iso.md.
#
#   sudo install/iso/build.sh [out-dir]    takumi-<version>-<arch>.iso and its .sha256 (default ./out)
#
#   install/iso/build.sh --packages <arch>   what the disc runs and what it installs, without building
#
#   TAKUMI_ISO_WORK=<dir>   scratch space, about 15 GB (default /var/tmp/takumi-iso)
#   TAKUMI_ISO_DEBUG=1      a root shell on the serial console while it runs, for testing in a VM only
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
src=$(cd -- "$here/../.." && pwd)
# The packages a list names for an architecture: a bracketed architecture after a name keeps it to that one.
packages() { sed 's/#.*//' "${@:2}" | awk -v a="[$1]" 'NF == 1 || (NF == 2 && $2 == a) { print $1 }'; }
if [[ "${1:-}" == --packages ]]; then
  a=${2:?usage: build.sh --packages <x86_64|aarch64>}
  echo "live: $(packages "$a" "$here/live.txt" | tr '\n' ' ')"
  echo "target: $( { packages "$a" "$here/target.txt"; packages "$a" "$src/install/packages/base.txt" "$src/install/packages/desktop.txt"; } | sort -u | tr '\n' ' ')"
  exit 0
fi
out=$(realpath -m "${1:-$PWD/out}")
work=${TAKUMI_ISO_WORK:-/var/tmp/takumi-iso}
arch=$(uname -m)
version=$(< "$src/version")
say() { printf '== %s\n' "$*"; }
die() { printf 'build: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root: sudo $0"
case "$arch" in
  x86_64)  efi_src=systemd-bootx64.efi;  efi_name=BOOTX64.EFI;  kimage=vmlinuz-linux; serial=ttyS0 ;;
  aarch64) efi_src=systemd-bootaa64.efi; efi_name=BOOTAA64.EFI; kimage=Image;         serial=ttyAMA0 ;;
  *) die "no image for $arch" ;;
esac
missing=()
for t in pacstrap arch-chroot mksquashfs xorriso mkfs.fat mmd mcopy repo-add jq; do command -v "$t" >/dev/null || missing+=("$t"); done
(( ${#missing[@]} == 0 )) || die "missing ${missing[*]}: pacman -S arch-install-scripts squashfs-tools libisoburn mtools dosfstools jq"

# A run that stopped half way can leave pacstrap's or arch-chroot's mounts in the work space: never delete
# through one.
while read -r m; do [[ -n "$m" ]] && { umount -R "$m" 2>/dev/null || umount -l "$m"; }; done \
  < <(findmnt -rno TARGET | awk -v w="$work/" 'index($0 "/", w) == 1' | sort -r)
[[ -z "$(findmnt -rno TARGET | awk -v w="$work/" 'index($0 "/", w) == 1')" ]] || die "something is still mounted under $work"
rm -rf "$work"
root=$work/root disc=$work/disc boot=$work/boot
mkdir -p "$root" "$disc/takumi/repo" "$boot" "$work/db" "$out"

# The disc's ISO 9660 UUID is the moment it was made (YYYY-MM-DD-hh-mm-ss-cc); the live system finds its
# disc by it.
stamp=$(date -u +%Y%m%d%H%M%S)00
uuid=${stamp:0:4}-${stamp:4:2}-${stamp:6:2}-${stamp:8:2}-${stamp:10:2}-${stamp:12:2}-${stamp:14:2}
label=TAKUMI_$(printf '%s' "$version" | tr -c 'A-Za-z0-9' _ | tr a-z A-Z)

say "the setup system ($arch)"
# shellcheck disable=SC2046
pacstrap -c -G "$root" $(packages "$arch" "$here/live.txt") >"$work/pacstrap.log" 2>&1 \
  || { tail -n 20 "$work/pacstrap.log" >&2; die "pacstrap failed; see $work/pacstrap.log"; }
# Owned by root, whoever the build's checkout belongs to: sudo refuses a sudoers.d that is not root's, and
# /etc must never be the live user's.
rsync -a --no-owner --no-group "$here/root/" "$root/"
chmod 440 "$root/etc/sudoers.d/takumi-live"
mkdir -p "$root/etc/takumi"
echo "$uuid" > "$root/etc/takumi/live-media"
printf 'version=%s\narch=%s\nbuilt=%s\n' "$version" "$arch" "$uuid" > "$root/etc/takumi/live"
echo takumi-setup > "$root/etc/hostname"
echo LANG=en_US.UTF-8 > "$root/etc/locale.conf"
# Every first-start setting is set, so systemd never stops to ask on the console behind the splash.
ln -sf /usr/share/zoneinfo/UTC "$root/etc/localtime"
echo KEYMAP=us > "$root/etc/vconsole.conf"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "$root/etc/locale.gen"
# The new computer's first update needs a mirror; pacstrap copies this list to it.
if ! grep -q '^Server' "$root/etc/pacman.d/mirrorlist"; then
  case "$arch" in
    x86_64)  echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' ;;
    aarch64) echo 'Server = http://mirror.archlinuxarm.org/$arch/$repo' ;;
  esac >> "$root/etc/pacman.d/mirrorlist"
fi

# Takumi itself: the tree the installer copies to the new computer, and what the setup screen draws with.
t=$root/usr/share/takumi
mkdir -p "$t/lib"
rsync -a --no-owner --no-group --exclude .git --exclude /preview --exclude /out "$src/" "$t/source/"
rsync -a --no-owner --no-group "$src/shell/" "$t/shell/"
rsync -a --no-owner --no-group "$src/themes/" "$t/themes/"
install -m644 "$src"/lib/*.sh "$t/lib/"
install -m755 "$src/bin/takumi" "$root/usr/bin/takumi"
ln -sf takumi "$root/usr/bin/tk"
install -d "$root/usr/lib/takumi"
rsync -a --no-owner --no-group "$src/commands/" "$root/usr/lib/takumi/commands/"
cp "$src/version" "$t/version"
for phase in dawn day dusk night; do
  HOME=/nonexistent TAKUMI_RENDER_OUT="$t/setup/$phase" TAKUMI_RENDER_PALETTE_ONLY=1 \
    "$src/commands/theme/render" "$(< "$src/config/takumi/theme")" "$phase" >/dev/null
done
install -d "$root/usr/share/plymouth/themes/takumi"
install -m644 "$src"/default/plymouth/takumi/* "$root/usr/share/plymouth/themes/takumi/"
printf '[Daemon]\nTheme=takumi\nShowDelay=0\nDeviceTimeout=8\n' > "$root/etc/plymouth/plymouthd.conf"

arch-chroot "$root" /bin/bash -e >"$work/chroot.log" 2>&1 <<'CH' || { tail -n 20 "$work/chroot.log" >&2; die "setting up the setup system failed"; }
locale-gen
useradd -m -G video,input -s /bin/bash -c "Takumi setup" live
passwd -l live
passwd -l root
systemctl enable greetd NetworkManager systemd-timesyncd
CH
kver=""
for d in "$root"/usr/lib/modules/*/; do [[ -f "$d/modules.dep" ]] && kver=$(basename "$d"); done
[[ -n "$kver" ]] || die "the setup system has no kernel"
arch-chroot "$root" mkinitcpio -k "$kver" -g /boot/takumi-live.img >>"$work/chroot.log" 2>&1 \
  || { tail -n 20 "$work/chroot.log" >&2; die "the initramfs did not build"; }

say "the packages an install needs"
# Plus what Takumi's hardware fixes install (default/hardware), so the computer the disc meets is set up
# offline; 32-bit libraries stay off the disc.
hw=$("$src/commands/hardware/detect" --all --data "$src/default/hardware" 2>/dev/null \
  | jq -r --arg a "$arch" '.matches[] | select((.match.arch // [$a]) | index($a)) | .apply.packages // [] | .[] | select(startswith("lib32-") | not)' 2>/dev/null || true)
want=$( { packages "$arch" "$here/target.txt"; packages "$arch" "$src/install/packages/base.txt" "$src/install/packages/desktop.txt"; printf '%s\n' $hw; } | sed '/^$/d' | sort -u)
pacman --dbpath "$work/db" -Sy >/dev/null
carried=() skipped=()
for p in $want; do
  if pacman --dbpath "$work/db" -Si "$p" >/dev/null 2>&1; then carried+=("$p"); else skipped+=("$p"); fi
done
(( ${#skipped[@]} == 0 )) || echo "   not in the $arch repositories, left out: ${skipped[*]}"
# What this computer's own cache already holds is copied rather than fetched again.
while read -r f; do
  if [[ -f "/var/cache/pacman/pkg/$f" ]]; then
    cp "/var/cache/pacman/pkg/$f" "$disc/takumi/repo/"
    if [[ -f "/var/cache/pacman/pkg/$f.sig" ]]; then cp "/var/cache/pacman/pkg/$f.sig" "$disc/takumi/repo/"; fi
  fi
done < <(pacman --dbpath "$work/db" -Sp --print-format '%f' "${carried[@]}")
pacman --dbpath "$work/db" --cachedir "$disc/takumi/repo" -Sw --noconfirm "${carried[@]}" >"$work/repo.log" 2>&1 \
  || { tail -n 20 "$work/repo.log" >&2; die "downloading packages failed; see $work/repo.log"; }
shopt -s nullglob
pkgs=("$disc"/takumi/repo/*.pkg.tar.zst "$disc"/takumi/repo/*.pkg.tar.xz)
shopt -u nullglob
repo-add -q "$disc/takumi/repo/takumi-media.db.tar.zst" "${pkgs[@]}"
# What the setup installs, in one go: the three lists, as far as this architecture carries them.
printf '%s\n' "${carried[@]}" > "$t/setup/packages"

say "the boot partition"
opts="quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto vt.global_cursor_default=0"
opts+=" plymouth.ignore-serial-consoles vt.default_red=11 vt.default_grn=15 vt.default_blu=20 systemd.tty.term.console=dumb"
opts+=" systemd.volatile=overlay systemd.gpt_auto=0 rd.systemd.gpt_auto=0 systemd.firstboot=no"
[[ "${TAKUMI_ISO_DEBUG:-}" == 1 ]] && opts+=" console=tty0 console=$serial systemd.debug_shell=$serial"
cp "$root/usr/lib/systemd/boot/efi/$efi_src" "$boot/$efi_name"
cp "$root/boot/$kimage" "$boot/linux"
cp "$root/boot/takumi-live.img" "$boot/initramfs.img"
printf 'timeout 0\ndefault takumi.conf\n' > "$boot/loader.conf"
printf 'title    Takumi setup\nsort-key takumi\nlinux    /takumi/linux\ninitrd   /takumi/initramfs.img\noptions  %s\n' "$opts" > "$boot/takumi.conf"
esp=$work/esp.img
kib=$(( $(du -sk "$boot" | cut -f1) * 11 / 10 + 4096 ))
mkfs.fat -C -n TAKUMI_EFI "$esp" "$kib" >/dev/null
mmd -i "$esp" ::/EFI ::/EFI/BOOT ::/loader ::/loader/entries ::/takumi
mcopy -i "$esp" "$boot/$efi_name" ::/EFI/BOOT/
mcopy -i "$esp" "$boot/loader.conf" ::/loader/
mcopy -i "$esp" "$boot/takumi.conf" ::/loader/entries/
mcopy -i "$esp" "$boot/linux" "$boot/initramfs.img" ::/takumi/

say "the system image"
# The setup system's own kernel must read its image: Arch's x86_64 kernel reads zstd; Arch Linux ARM's reads xz
# but not zstd ("Filesystem uses zstd compression. This is not supported").
case "$arch" in x86_64) comp=(-comp zstd -Xcompression-level 15) ;; *) comp=(-comp xz) ;; esac
mksquashfs "$root" "$disc/takumi/root.sfs" -noappend -no-progress "${comp[@]}" -b 1M \
  -wildcards -e 'boot/*' 'var/cache/pacman/pkg/*' 'var/lib/pacman/sync/*' >"$work/squashfs.log" 2>&1 \
  || { tail -n 20 "$work/squashfs.log" >&2; die "mksquashfs failed"; }

say "the disc"
iso=$out/takumi-$version-$arch.iso
rm -f "$iso" "$iso.sha256"
# An El Torito boot image for a CD drive, and the same boot partition in the GPT for a USB stick
# (xorrisofs(1): -append_partition, -appended_part_as_gpt, -e --interval:appended_partition_2).
xorriso -no_rc -as mkisofs -iso-level 3 -rational-rock -volid "$label" \
  -appid "Takumi OS $version setup" -publisher "Takumi OS" --modification-date="$stamp" \
  -partition_offset 16 -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$esp" -appended_part_as_gpt \
  -e --interval:appended_partition_2:all:: -no-emul-boot \
  -o "$iso" "$disc" >"$work/xorriso.log" 2>&1 || { tail -n 20 "$work/xorriso.log" >&2; die "xorriso failed"; }
( cd "$out" && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256" )
[[ "${TAKUMI_ISO_KEEP:-}" == 1 ]] || rm -rf "$root" "$disc" "$boot" "$esp"
say "$iso, $(du -h "$iso" | cut -f1), disc $uuid"
