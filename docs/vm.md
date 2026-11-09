# Running the real desktop in a VM

The Strip and the shell (the Core, the Sky, the Lock) need Arch, niri and Quickshell. On a Mac
or any Linux box, `test/vm` boots them in QEMU at native speed (Apple
hypervisor on Apple Silicon, KVM on Linux) using the aarch64 build of Arch
through Arch Linux ARM, whose `extra` repo carries both niri and Quickshell.

## What runs where

QEMU on a Mac has no 3D acceleration, so everything is drawn in software. The
session is niri on the VM's screen, as on real hardware, with Mesa's software
driver (see "The screen on a Mac" below); the login screen runs in cage with
wlroots' software renderer. Everything Takumi draws is the real thing: niri,
its IPC, the Quickshell shell, the login screen, the lock. The VM is marked
with `/etc/takumi/vm`; `takumi greeter` and `takumi session start` read that
mark. On real hardware none of this applies.

In the VM niri's modifier is Alt, not Super, because the Mac keeps
Command+Space for Spotlight: Alt+Space opens the Core, Alt+L locks.

## First run

```bash
brew install qemu            # macOS; Arch: pacman -S qemu-full edk2-aarch64
test/vm iso
```

`test/vm iso` fetches the latest archboot aarch64 installer ISO, creates a
24 GiB disk under `~/.local/share/takumi-vm/`, and boots the installer in a
window with the repo shared into the guest as a 9p mount. Inside the live
system:

```bash
mount -t 9p -o trans=virtio,version=9p2000.L takumi /mnt
bash /mnt/install/vm/provision.sh
```

The provisioner partitions the virtual disk (a 1 GiB boot partition at
`/efi`, Btrfs with the first room and the shared subvolumes), pacstraps Arch
Linux ARM, sets up systemd-boot with the first room's own kernel, creates the
`takumi` user, and runs the ordinary Takumi installer. `test/vm run` then boots
into the login screen.

## Knobs

| Variable | Default | |
|---|---|---|
| `TAKUMI_VM_DIR` | `~/.local/share/takumi-vm` | disk, firmware vars, ISO, serial log |
| `TAKUMI_VM_MEM` | 3072 | MiB |
| `TAKUMI_VM_CPUS` | 4 | |
| `TAKUMI_VM_DISK` | 24G | |
| `TAKUMI_VM_ISO` | `$TAKUMI_VM_DIR/archboot-aarch64.iso` | |

`test/vm serial` boots headless on the terminal's serial console. SSH is
forwarded to `localhost:2222`. Everything below works against a running VM:

| Command | Does |
|---|---|
| `test/vm install` | unattended: boot the installer headless, provision, run the Takumi installer, power off |
| `test/vm run` | boot the installed disk full screen, on a macOS desktop of its own: swipe sideways with three fingers (or Control and an arrow key) to go between it and your other windows; `TAKUMI_VM_WINDOW=1` opens a window instead |
| `test/vm run --headless` | boot the installed disk without a window |
| `test/vm ssh [cmd]` | a shell or a command as the takumi user (VM-only password from the provisioner) |
| `test/vm shot <file.png>` | save what the screen shows |
| `test/vm key <keys>` / `type <text>` | press keys (QEMU names, `alt-spc`) / type text |
| `test/vm sync` | push this working tree in and reinstall the shell, commands and config; restarts the login screen if nobody is logged in, because Quickshell reloads changed QML in place and that strands a login half done |
| `test/vm wifi` | five real Wi-Fi networks on simulated radios, with internet: Takumi Home (WPA2), Corner Café (open), Attic: 5G (WPA3), Studio (hidden) and Campus (work or school sign-in, WPA-Enterprise); passwords are in `install/vm/wifi-rig.sh` |
| `test/vm wifi portal` / `no-portal` | every network seems to want a sign-in page, or not |
| `test/vm restart` | end the desktop session; the login screen comes back, with any new greeter files |
| `test/vm rescue <cmd>...` | boot the installer with the disk attached, run commands, power off |
| `test/vm stop` | power off |

Use `test/vm stop` rather than closing the window: closing it, or quitting
QEMU, is pulling the plug, and files written in the last half minute can
come back empty. The one that bit was an SSH host key, which stopped `sshd`
for good, so `test/vm ssh` and `sync` were refused. The provisioner gives
`sshd` a step that makes any missing or empty key again before it starts
(`/etc/systemd/system/sshd.service.d/takumi-vm.conf`); `test/vm rescue` is
the way in when something else is lost.

## The screen on a Mac

QEMU gives the VM its window in the Mac's pixels, which on a Retina screen is
twice its size in points, and the VM follows the window: make it full screen
(Control-Command-F, or the green button) or resize it, and the VM's screen
takes the new size.

**The session.** Mesa's driver for QEMU's GPU cannot allocate screen buffers
without 3D, so `takumi session start` gives niri Mesa's software driver that
can (`MESA_LOADER_DRIVER_OVERRIDE=kms_swrast`, niri's alone; niri's
`environment` block unsets it for what niri starts). niri then drives the
screen itself, as on real hardware: it scales a dense screen by its density
(a Retina Mac's at twice the scale, every pixel sharp, the size the Mac's own
apps are), follows the window's size, takes Takumi's display commands like a
real screen, and redraws only what changed, the pointer included. Without the
software driver niri stops with "no allocator available for device".

**The login screen** runs in cage, which draws a dense screen at twice the
scale through `takumi vm display` (judging density from the size in
millimetres QEMU passes along, and keeping it so as the window changes) and
keeps a hardware pointer, which QEMU draws on the Mac.

**Software drawing.** Every frame is drawn on the CPU, so in the VM niri runs
without animations (through a config written at login that includes yours)
and the shell drops what moves for long or glows: twinkling stars, breathing
lights, shadows (`Style.softwareDrawing`).

QEMU opens its window small (its placeholder screen's size) and does not
always go full screen when asked from the command line, so make it full screen
by hand when it opens small.

## What is different on aarch64

The kernel package is `linux-aarch64` and the kernel image is `/boot/Image`
(x86_64: `/boot/vmlinuz-linux`); `lib/rooms.sh` handles both.
`install/packages/base.txt` carries no kernel: the installer runs on a
system that already boots, and the provisioner chooses the kernel.
