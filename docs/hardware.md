# This computer

What is in this computer, whether each part works, and what Takumi set up for
it. Takumi's hardware support is data: one small file per fix in
`default/hardware/`, matched against the computer, set up inside the room an
update builds, and shown to you in plain words. A fix that turns out wrong is
undone by going back a room, and a new fix reaches every computer that needs
it with the next update.

## What you see

Type "computer", "hardware" or "drivers", or a part: "graphics", "nvidia",
"camera", "fingerprint", "touchpad", "wifi card". The Palette lists the parts:

```
This computer: Lenovo ThinkPad X1 Carbon Gen 11 · 13th Gen Intel Core i7-1365U · 32 GB memory · 9 fixes in use
Graphics: Intel Iris Xe Graphics · works, with video decoding
Graphics: NVIDIA GeForce RTX 4070 Max-Q / Mobile · NVIDIA's own driver · rests when no app uses it
Wi-Fi: Intel Wi-Fi 6E AX211 · works
Bluetooth: Intel AX211 Bluetooth · works
Camera: Intel IPU6 · works on some models
Sound: Realtek ALC287 · works
Fingerprint reader: Goodix · works
Touchpad: Synaptics · on its precise connection
Processor: 13th Gen Intel Core i7-1365U · kept cool by thermald
```

Enter on a part opens a card that says it in sentences: what the fix does,
what does not work ("Apps that open the camera directly see no camera. A USB
camera works everywhere."), and what is only in the AUR, which Takumi never
installs by itself.

A part says one of:

| It says | Means |
|---|---|
| works, or what its fix does | the part has its driver, and Takumi's fix for it is in this system |
| NVIDIA's own driver, open nouveau driver | which driver the graphics run on |
| set up at the next update | Takumi has a fix for it that this system lacks |
| set up; in use after a restart | the fix is in this system; the part still runs on the old driver until the computer restarts |
| works on some models, not supported yet | the plain truth for parts Linux does not fully drive (cameras, a Mac's T2) |
| no driver | no driver is in use, and Takumi knows no fix for it yet |

When anything waits, one more row sits nearest the field: "Set up what this
computer needs · NVIDIA graphics, Laptop sound · Enter updates Takumi, in a new
system". Enter asks first, then runs `takumi update` as a conversation.

"wifi" alone lists networks, not the chip; the computer's version, disk and
kernel are in "About this computer" (`takumi about`).

## How a fix gets set up

`takumi hardware apply` sets up the fixes that match this computer inside a
system root, and records what it did:

| When | Root | Packages from |
|---|---|---|
| The setup disc installs (`commands/setup/install`, after the disc's packages are reachable in the new system, before the Takumi installer) | the new disk | the disc; a fix whose package the disc lacks waits for the first update |
| Every update (`commands/room/upgrade`, last) | the room being built | the room's repositories, just synced |
| By hand: `sudo takumi hardware apply` | the system in use, changed as pacman changes it | its repositories |

Neither hook stops what it is part of: a fix that fails is said in the log, and
`takumi doctor` names it. In order, for each root:

1. **Packages.** A fix is set up whole or not at all: if one of its packages is
   not in the root's repositories, none of it is set up, and it says which.
   Only its 32-bit libraries (`lib32-…`) may be left out, when the root's own
   `pacman.conf` has no `[multilib]`, so an update never meets a package no
   repository carries. One `pacman -S --needed` installs the rest, through
   `arch-chroot` for any root but `/`. AUR packages are only named.
2. **Files Takumi owns**, written whole from the fixes in use, each fix named in
   a comment, removed when no fix needs them:
   `/etc/modprobe.d/takumi-hardware.conf`,
   `/etc/udev/rules.d/90-takumi-hardware.rules`, and
   `/etc/mkinitcpio.conf.d/takumi-hardware.conf` for drivers needed early (at
   the disk's password, for the splash), each marked `?` so a kernel without
   one still builds ([mkinitcpio.conf(5)](https://man.archlinux.org/man/mkinitcpio.conf.5)).
3. **Kernel options** in the root's `/etc/kernel/cmdline`, which each room's
   boot entry reads ([atomic-rooms.md](atomic-rooms.md)). Options a fix added
   before and no fix wants now are taken out; options anyone else put there
   are never touched.
4. **Services** turned on for the fixes in use, and off again when the fix
   that turned one on no longer applies.
5. **The initramfs**, made again when its options or early drivers changed,
   and whenever there are early drivers: an update may have brought new
   versions of them. On the system in use, `takumi room kernel-sync` then
   gives its boot entry the change.
6. **The record**, `/var/lib/takumi/hardware.json`.

A room being built is a copy of the one in use, so it starts from that room's
record: what an older fix added is still known, and is taken back when the fix
no longer applies.

## The fixes

`default/hardware/<name>.toml`, installed to
`/usr/share/takumi/default/hardware/`. The setup disc reads its own copy of
the tree. One fix per file:

```toml
# What it is and why, and the vendor's documentation it follows.
title = "NVIDIA graphics"            # how rows, the record and the doctor name it
part = "graphics"                    # the row it belongs to
says = "NVIDIA's own driver"         # what the row says once it is in place
driver = "nvidia"                    # the driver the device should then use

[match]
pci = ["10de:1e??", "10de:1f??", "10de:2???", "10de:3???"]
pci_class = ["03??"]
arch = ["x86_64"]

[apply]
packages = ["nvidia-open", "nvidia-utils", "lib32-nvidia-utils", "libva-nvidia-driver"]
cmdline = ["nvidia_drm.modeset=1", "nvidia_drm.fbdev=1"]
modprobe = ["options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp"]
initramfs_modules = ["nvidia", "nvidia_modeset", "nvidia_uvm", "nvidia_drm"]
services = ["nvidia-suspend.service", "nvidia-hibernate.service", "nvidia-resume.service"]
note = "NVIDIA's own driver, the one NVIDIA recommends for this card. …"
```

Every key of `[match]` must hold; within a key, any one value is enough. A
file with an empty `[match]` never matches, and a key Takumi does not know
makes it match nothing.

| Key | Holds when |
|---|---|
| `pci` | a PCI device's `vendor:device` (or `vendor:device:subvendor:subdevice`) matches a glob: `*`, `?`, `[0-6]` |
| `pci_class` | that same device's class matches (`03??` is any display, `0280` Wi-Fi); alone, any device of the class |
| `usb` | a USB device's `vendor:product` matches |
| `dmi_vendor`, `dmi_product`, `dmi_family`, `dmi_version`, `dmi_board`, `dmi_chassis`… | a regular expression, any case, finds the field in `/sys/class/dmi/id` |
| `cpu_vendor`, `cpu_family`, `cpu_model` | `/proc/cpuinfo` says so (numbers in decimal) |
| `dt_compatible` | an entry of `/proc/device-tree/compatible` matches a glob |
| `kernel_log` | a regular expression finds a line in this start's kernel messages |
| `arch`, `laptop`, `virtual` | the machine (`uname -m`), a portable chassis type, a hypervisor |

Top-level keys: `title`, `part` (graphics, wifi, wired, bluetooth, camera,
sound, fingerprint, touchpad, processor, computer), `works` (yes, partly or
no), `says`, `driver`, and `keep = true` for a fix whose evidence goes away once
it works (a kernel message): once set up in a room it stays while its file
exists. `[apply]` holds `packages` (Arch's own repositories, multilib
included), `aur` (named, never installed), `cmdline`, `modprobe`,
`initramfs_modules`, `udev`, `services` and `note`, one plain sentence or
three for the card.

The first fixes:

| File | For | Sets up |
|---|---|---|
| `nvidia-open` | NVIDIA Turing (GTX 16, RTX 20) and newer | nvidia-open, video decoding, the screen kept across sleep, early KMS |
| `nvidia-laptop`, `nvidia-turing-laptop` | the same chips in a laptop | the chip powers down when unused, NVIDIA's own udev rules; prime-run |
| `nvidia-580` | Maxwell, Pascal, Volta | nouveau's Vulkan; names NVIDIA's 580 driver in the AUR |
| `nvidia-older` | Kepler and older | a note: nouveau only |
| `intel-graphics`, `intel-graphics-older` | Intel graphics | Vulkan, Intel's video decoder; the older decoder before Broadwell |
| `amd-graphics` | AMD Radeon | Vulkan (video decoding is in Mesa already) |
| `intel-thermald`, `intel-lpmd` | Intel laptops; Meteor, Lunar and Panther Lake | thermald; the low power daemon |
| `intel-ipu3-camera`, `intel-ipu6-camera`, `intel-ipu7-camera` | Intel MIPI cameras | libcamera and its PipeWire plugin, and what does not work |
| `laptop-sound` | Intel laptop audio | Sound Open Firmware and ALSA's profiles |
| `fingerprint` | fingerprint readers on USB | fprintd; whether it drives this one, fprintd says |
| `synaptics-intertouch` | touchpads the kernel says can use SMBus | `psmouse synaptics_intertouch=1` (kept) |
| `broadcom-wl` | Broadcom chips only Broadcom's driver runs well | broadcom-wl-dkms and the kernel's headers |
| `marvell-wifi` | Marvell Wi-Fi, as in Surfaces | linux-firmware-marvell, which the default firmware set leaves out |
| `realtek-rtw88-wifi` | RTL8821CE, 8822CE, 8822BE, 8723DE | their deepest power saving off, so they stay connected |
| `realtek-usb-wifi` | Realtek USB adapters that start as a driver disc | usb_modeswitch |
| `wifi-regulatory` | any Wi-Fi | wireless-regdb: the channels allowed where you are |
| `broadcom-bluetooth` | Broadcom Bluetooth | a note; Broadcom's patch firmware is in the AUR |
| `apple-t2`, `apple-facetime-hd`, `apple-silicon` | Macs | notes: what does not work, and why |
| `apple-spi-keyboard`, `surface-keyboard` | 2015 to 2017 MacBooks; Surface Pro 7 and later | the keyboard's drivers early, for the disk's password |
| `apple-nvme-sleep` | Apple's own SSD, 2015 to 2017 | kept out of the sleep state it does not come back from |
| `framework-13-11th-gen`, `framework-13-12th-gen` | Framework Laptop 13 | Framework's own kernel options for those models |
| `framework-13-amd` | Framework Laptop 13 with AMD Ryzen | framework-system (`framework_tool`: charge limit, fans, expansion cards); the headset microphone's detection is the kernel's own quirk |
| `framework-16` | Framework Laptop 16 | framework-system; its keyboard, numpad and macropad modules (`32ac:0012`, `0013`, `0014`, `0018`, `0019`) and LED matrix (`32ac:0020`) yours at the computer (`uaccess`), so keyboard.frame.work sets their lights in a Chromium browser |
| `asus-rog` | ASUS ROG and TUF laptops | asusctl from Arch's extra repository: keyboard lights, fan curves, the charge limit; asusd starts by its own udev rule |
| `dell-xps-sound` | Dell XPS laptops | linux-firmware-cirrus and linux-firmware-ti: the speaker amplifiers' firmware |
| `lenovo-yoga-sound` | Lenovo Yoga laptops (not ThinkPad Yogas) | the same firmware, for the speakers and the bass speakers |
| `surface-pro-11` | Surface Pro 11 (Snapdragon X, by its device tree) | a note: no touchscreen, pen or cameras yet |
| `intel-panther-lake` | Intel Panther Lake graphics (`INTEL_PTL_IDS`) | linux-firmware-intel for the xe driver; the row says when xe takes over after a restart |
| `xbox-controller` | Xbox One, One S, Elite and Series controllers by cable | a note: they pair over Bluetooth too ([gaming.md](gaming.md)) |
| `xbox-wireless-adapter` | Microsoft's Xbox Wireless Adapter | a note: its driver, xone, is only in the AUR |

What these do not fix, said plainly:

- **Speakers.** The amplifiers' firmware is all a data file can give. When
  Linux does not know a laptop's amplifiers yet (its ACPI tables lack what
  the cs35l41 or tas2781 driver reads), the speakers stay silent and
  headphones work, until a kernel with that model's quirk; the doctor names
  amplifier firmware the kernel asked for and did not find, as "The speakers
  are missing firmware".
- **The Dell XPS's haptic touchpad** (XPS 13 Plus, 14, 16) works as a
  touchpad; its click strength has no setting in Linux.
- **The Framework 13's built-in microphone** with AMD has no setting to fix;
  a headset's microphone is found by the kernel's own quirk (since 6.7).
- **Surface Pro 11** runs on Arch Linux ARM with a device tree that is still
  on its way into Linux.

ThinkPads are covered through their parts (IPU6 cameras, audio processors,
Synaptics and Goodix readers, Synaptics touchpads, NVIDIA in a laptop).

## Thunderbolt and USB4 docks

A Thunderbolt or USB4 device reaches the computer's memory directly, so on
a computer whose firmware asks for it, a new one waits until someone allows
it. [bolt](https://gitlab.freedesktop.org/bolt/bolt) (`boltd`) keeps the
list of allowed devices. On most laptops from the last few years the
firmware's IOMMU protection lets boltd allow a device by itself, and nothing
waits.

When one does wait, the Core says "CalDigit TS4 waits for your permission"
and opens on the row **Allow this dock**. Enter asks "Allow CalDigit TS4? A
dock reaches deep into the computer: allow only one you know", and a yes
asks for your password in the Core (polkit) and enrolls the device with
boltd's `auto` policy: it is allowed now and whenever it is plugged in
again, on every room. Typing "dock" or "thunderbolt" finds the row any time;
with nothing waiting it says so.

| Piece | Does |
|---|---|
| `takumi hardware dock` | the conversation: each waiting device by name, `boltctl enroll --policy auto` (or `boltctl authorize` for one boltd knows already) |
| `takumi hardware dock --waiting` | the waiting devices: uid and name, one per line; exit 1 when none |
| `takumi hardware dock --watch` | run by `takumi-docks.service`, which starts only where `/sys/bus/thunderbolt/devices` exists: follows udev's Thunderbolt events and says each waiting device once per login |
| `etc/polkit-1/rules.d/50-takumi-bolt.rules` | allowing a device (`org.freedesktop.bolt.enroll`, `.authorize`) asks an administrator at the computer for the password, kept five minutes; read before bolt's own rules, which would let any of an administrator's programs do it silently |

Devices are read from boltd over D-Bus with `busctl`
(`org.freedesktop.bolt1.Manager.ListDevices`, then each device's `Uid`,
`Name`, `Vendor`, `Type`, `Status`, `Stored`): a peripheral whose status is
`connected` is plugged in and not allowed. Exit codes of `takumi hardware
dock`: 0 done or nothing waits, 1 bolt is missing, 2 usage, 3 you said no or
the approval was refused.

## The record

`/var/lib/takumi/hardware.json` sits beside the rooms, shared by all of them
([atomic-rooms.md](atomic-rooms.md)), and keeps one entry per room, the newest
twelve: when, each fix with its status, packages and what was left out and
why, the kernel options and services it added, and the initramfs. A
computer without rooms keeps one entry, `system`.

| Status | Means |
|---|---|
| `applied` | set up in that room |
| `waiting` | its packages were not on the setup disc; the next update sets it up |
| `failed` | pacman failed; the next update tries again |
| `unavailable` | the root's repositories do not carry its packages |

## The doctor's hardware check

`hw_doctor` in `lib/hardware.sh` is the hardware check for `takumi doctor`
([doctor.md](doctor.md)). It says, one line each:

- fixes this computer needs that this room lacks: "Takumi has fixes for this
  computer that are not in this system yet (NVIDIA graphics): "update" sets
  them up, in a new system";
- firmware the kernel asked for and did not find, read from this start's
  kernel messages ("Direct firmware load for … failed", "firmware: failed to
  load …", Bluetooth's "Patch file not found"): "The Wi-Fi is missing firmware
  (mrvl/pcie8897_uapsta.bin, in linux-firmware-marvell): "update" adds it". A
  newer firmware a driver tried before an older one it then loaded, and a
  board's own variant beside a general one, are not missing. Firmware only in
  the AUR is named as such;
- else one line: Takumi's fixes are in place and no firmware is missing.

## Commands

```
takumi hardware [--json | --card <row>]                   the parts, as lines, as the Palette's rows, or one row's card
takumi hardware detect [--all] [--data <dir>]             hidden: the matching fixes and what they set up, as JSON
sudo takumi hardware apply [--root <dir>] [--data <dir>]  hidden: set them up in a root, and record it
```

`takumi hardware` exits 3 for a card of a part that is gone. `detect` exits 1
without data and 2 on a wrong word. `apply` exits 0 when done (a fix that
waits is not a failure), 1 when a step failed, without data or not as root,
and 2 on a wrong word.

Everything `lib/hardware.sh` reads can be pointed elsewhere: `TAKUMI_HW_LSPCI`
and `TAKUMI_HW_LSUSB` (files of `lspci -vmm -nn -k` and `lsusb` output),
`TAKUMI_HW_SYS` (sysfs; also PCI and USB when `lspci` or `lsusb` is missing),
`TAKUMI_HW_CPUINFO`, `TAKUMI_HW_MEMINFO`, `TAKUMI_HW_DT`, `TAKUMI_HW_ASOUND`,
`TAKUMI_HW_KERNEL_LOG`, `TAKUMI_HW_ARCH`, `TAKUMI_HW_FIRMWARE`,
`TAKUMI_HW_DATA`, `TAKUMI_HW_RECORD` and `TAKUMI_HW_ROOM`.

## Not done yet

- Speaker tunings per laptop: they need filter chains measured on each model;
  a fix can name one once there are some.
- Choosing the NVIDIA chip for one app from the Palette. `prime-run` works
  from a terminal or a game's launch options.
- AMD's oldest GCN cards (Radeon HD 7000 to R9 290) stay on the older radeon
  driver, without Vulkan.
- Tuxedo and Slimbook keyboard lights, most Snapdragon laptops, and Macs
  with a T2: their tools or kernels are not in Arch's repositories.
- ASUS's GPU switching daemon (supergfxctl) and ROG Control Center's window
  are not set up; asus-linux's own guide says the first is not needed with
  NVIDIA's current driver.
- The Core does not say when a Thunderbolt device is refused or unplugged,
  and has no row to forget an allowed one (`boltctl forget` does).
- Signing kernel modules built by DKMS for Secure Boot.
- Saving a fingerprint: fprintd is set up here; enrolling is its own feature.
- Applying to the system in use reuses its package lists as they are; `takumi
  update` is the way that syncs them first.

## Testing

`test/hardware` runs on any machine against fake computers: a ThinkPad with
NVIDIA, a desktop with a GTX 1060, three Macs, a Framework, a Surface, an
Apple Silicon Mac, a virtual machine, an ASUS ROG, a Dell XPS 15, a Yoga and
a ThinkPad X1 Yoga, a Panther Lake ThinkPad, a Framework 13 with AMD and a
Framework 16, a Surface Pro 11, and a desktop with an Xbox controller and
adapter. It reads every fix and checks it
names only keys Takumi knows; checks what matches each computer and why; the
rows, cards and Palette words; `takumi hardware apply` into fake rooms with a
fake pacman, arch-chroot, systemctl and mkinitcpio (packages whole or not at
all, kernel options added once and taken back, files written and removed,
services on and off, the initramfs, the record, the setup disc's offline
packages, pacman failing, multilib); what the doctor hears (speaker amplifiers' firmware too); and that both
hooks are in place. `test/system` checks `takumi hardware dock` against a
fake boltd, boltctl and udevadm.

None of it has run on real hardware yet. In the virtual machine
([vm.md](vm.md)) This computer shows a QEMU machine that needs no fix.
