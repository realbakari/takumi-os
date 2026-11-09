# The setup disc

One file, `takumi-<version>-<arch>.iso`, that starts Takumi's setup on any
computer with UEFI: written as it is to a USB stick, or given to a virtual
machine as its CD. It carries every package an install needs, so installing
needs no network. What the person sees is in [setup.md](setup.md); the disk
it makes is in [encryption.md](encryption.md).

## Building it

On Arch Linux (x86_64) or Arch Linux ARM (aarch64), as root; the image is for
the architecture it is built on:

```bash
sudo pacman -S --needed arch-install-scripts squashfs-tools libisoburn mtools dosfstools jq
sudo install/iso/build.sh out/
```

It takes about 15 GB of scratch space (`TAKUMI_ISO_WORK`, default
`/var/tmp/takumi-iso`) and writes `out/takumi-<version>-<arch>.iso` with a
`.sha256` beside it. `install/iso/build.sh --packages x86_64` lists what the
disc runs and what it installs, without building.

## What is on it

```
takumi/root.sfs          the setup system, read-only (squashfs, zstd)
takumi/repo/             every package of the three lists below, and their
                         dependencies, as a pacman repository (takumi-media)
EFI boot partition       systemd-boot, the kernel, the setup system's initramfs
```

| List | Is |
|---|---|
| `install/iso/live.txt` | what the setup system runs: the kernel, niri, Quickshell, the fonts, the tools that install |
| `install/iso/target.txt` | what the new disk gets before the Takumi installer runs: base, the kernel, firmware, microcode, the keyring |
| `install/packages/base.txt`, `install/packages/desktop.txt` | the rest of Takumi, as on any install |

A bracketed architecture after a name keeps a line to that one
(`linux-firmware [x86_64]`). A package an architecture's repositories do not
carry is left out and named in the build's output.

## How it starts

1. The firmware finds the boot partition: as the CD's El Torito image in a
   CD drive, or as a GPT partition on a USB stick. Both are the same FAT
   image ([xorrisofs(1)](https://www.gnu.org/software/xorriso/man_1_xorrisofs.html):
   `-append_partition`, `-appended_part_as_gpt`, `-e --interval:appended_partition_2`).
2. systemd-boot starts the kernel at once (`timeout 0`), with the quiet
   options of an installed Takumi ([boot.md](boot.md)) and the 匠 splash.
3. The initramfs is one for every computer (no `autodetect`). Its own hook,
   `install/iso/root/usr/lib/initcpio/install/takumi-live`, mounts the disc
   by its ISO 9660 UUID, which is the moment it was built, so a disc made on
   another day is never mistaken for this one; then `takumi/root.sfs` as the
   root, read-only. `systemd.volatile=overlay` puts memory over it
   ([systemd-volatile-root.service(8)](https://www.freedesktop.org/software/systemd/man/latest/systemd-volatile-root.service.html)).
   `systemd.gpt_auto=0` keeps systemd from looking for a root partition on
   the disc.
4. greetd starts `takumi setup start` as the `live` user, which starts niri
   with the setup screen. A computer whose GPU cannot draw (a virtual
   machine without 3D) makes niri stop at once; it starts again with Mesa's
   software driver.

The `live` user may run three things as root without a password, and nothing
else: `takumi setup install`, `systemctl reboot` and `systemctl poweroff`
(`install/iso/root/etc/sudoers.d/takumi-live`). Root has no password.

## Installing from it

`takumi setup install` installs every package from `takumi/repo`, read
through a pacman configuration that names only the disc (`SigLevel = Never`:
the disc itself is what is trusted; each package was checked against the
keyring when the disc was built). It installs the three lists in one
pacstrap, so the Takumi installer that runs after it (`install/run.sh`,
with `TAKUMI_OFFLINE=1`) finds nothing left to fetch. With a network, the new
computer's package lists are fetched at the end, so its first update knows
what is new.

## In a virtual machine

```bash
TAKUMI_VM_DIR=~/takumi-iso-vm TAKUMI_VM_ISO=out/takumi-0.1.0-aarch64.iso TAKUMI_VM_DISK=40G test/vm iso
```

boots the disc with an empty 40 GB disk, in a window ([vm.md](vm.md)).
`TAKUMI_ISO_DEBUG=1` at build time adds a root shell on the serial console
while it runs; never for a disc anyone else uses.

## Not proven here

- An x86_64 disc: this tree was built and installed on aarch64 (Arch Linux
  ARM in QEMU). The x86_64 lists and boot file names are checked by
  `test/iso`, not by a build.
- A real USB stick on real firmware.
- Secure Boot: the disc's systemd-boot is not signed.

## Testing

`test/iso` checks, without building: what each architecture runs and
carries, the live hook's mounts, the live system's own files, the kernel
options, and the boot partition's place on the disc.
