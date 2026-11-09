# Drives

USB drives, memory cards and external disks open by themselves when they are
plugged in, the way they do on a Mac or a Windows PC. The Core says which one
came and how much room it has; a press opens it in Files. Everything else is
a row in the Palette: type "drive" (or "usb", "eject", "sd card", or the
drive's name). The same rows check a disk's health, write a disk image to a
stick, and put OneDrive, Google Drive or Dropbox in your home as a folder.

## What you see

Plugging in a stick: the Core says **SanDisk 64 GB · 41 GB free · press to
open**. The name is the brand and the size printed on it, not the 61.5 billion
bytes it really holds. A card in a reader with no brand of its own is "SD card
32 GB". An encrypted drive says **SanDisk 64 GB is locked · type its name in
the Core to unlock it**. One Takumi cannot read says why: "it is formatted for
a Mac (APFS), which Takumi cannot read". A blank one says **Kingston 16 GB has
nothing Takumi can read · type format in the Core to erase it for use**.

| Row | Says | Enter |
|---|---|---|
| SanDisk 64 GB | 41 GB free · Enter opens it | opens it in Files (`takumi drive open`) |
| Photos on WD 2 TB | Not open · Enter opens it | opens it; a drive with parts names each by its label |
| SD card 32 GB | Locked · Enter asks for its password | asks in the Core, as dots, then opens it |
| Kingston 16 GB | Nothing Takumi can read · Enter shows how to erase it for use | the three ways to erase it, below |
| Eject SanDisk 64 GB | Then you can take it out | `takumi drive eject`: "You can take out SanDisk" |
| What fills my disk | 41 GB free on this computer · Disk Usage shows what takes the space | opens Disk Usage, when it is installed |

"format" (or "erase") lists three ways to erase each drive, each asking twice:

| Row | Becomes |
|---|---|
| Format SanDisk 64 GB for Mac, Windows and Linux | exFAT: files of any size, read everywhere |
| Format SanDisk 64 GB for cameras and TVs | FAT32: what older devices read; no file over 4 GB |
| Format SanDisk 64 GB for Linux only | ext4: keeps Linux owners and permissions; the drive is yours |

## Ejecting

Eject closes every part of the drive (what was still being written is written
first), locks its encrypted parts again, then powers the drive off, so its
light goes out, and says "You can take out SanDisk". When an app still has a
file open on it, nothing is powered off and the Core says "Something is still
using SanDisk 64 GB. Close what is open from it, then eject again".

A drive taken out while it was still open gets a word: **SanDisk 64 GB was
taken out while open · eject it first next time, so nothing is lost**. One
closed in Files first, or ejected, gets none.

## Erasing

`takumi drive format` is a conversation that names the drive, its size and
what is on it, then asks twice, the way the setup disc erases a disk:
"Erase SanDisk 64 GB? Everything on it goes: DCIM, Notes.txt and Taxes
2025.pdf. It becomes exFAT, for Mac, Windows and Linux." Enter, then "Press
Enter again to erase SanDisk 64 GB", with five seconds to do it. At a terminal
it wants `erase` typed. Only a USB drive or a memory card, never a disk this
computer runs from. The new drive keeps its old name when it suits the new
filesystem, else takes the brand's ("KINGSTON" for FAT32).

## Writing a disk image

"Write a disk image to a USB stick" (type "usb", "image", "iso" or "flash")
puts an installer or a Raspberry Pi system on a stick or a memory card: a
`.img` or `.iso`, also compressed as `.img.xz`, `.img.zst` or `.img.gz`,
which is opened as it is written. The image is the one you name, or one
copied in Files (the row then reads "Write raspios.img.xz to a USB stick"),
or one picked in Files with right-click › Scripts › Write to a USB stick,
else the newest in Downloads, which the Core asks about.

Only USB drives and memory cards are offered, never a disk this computer runs
from; with several, the Core asks which. Then it says what happens and wants
the drive's name typed, not just Enter: **"Everything on Kingston 16 GB is
erased and raspios.img.xz is written there. Type Kingston to go on"**. A
wrong name is asked again. The password is asked once, in the Core, and the
notes say how far it got ("Writing raspios.img.xz · 1.2 GB of 4.5 GB (27%)").
At the end the drive is flushed and powered off: "raspios.img.xz is on
Kingston 16 GB. You can take it out". An image bigger than the drive is
refused before anything is erased.

## Drive health

"Check drive health" (type "drive health", "ssd" or "smart") asks each disk in
this computer how it is, the way it reports it itself (SMART, and NVMe's health
log), and says it in words: **Samsung SSD 980 1TB · Healthy · 2% worn · 1,200
hours**. A disk that is wearing out says "Wearing out: replace it soon", one
that is failing "Failing: copy what matters off it now". Disks only answer
root, so the password is asked in the Core; the first time it offers to
install smartmontools from Arch. The disks of a virtual machine, and most USB
drives, do not report their health.

## OneDrive, Google Drive and Dropbox

"Add OneDrive", "Add Google Drive" and "Add Dropbox" (type the cloud's name,
or "cloud") make the cloud a folder in your home, `~/OneDrive`, `~/Google
Drive` or `~/Dropbox`, with a place in Files' sidebar. The first time, the
Core offers to install rclone and fuse3 from Arch, then opens the cloud's
sign-in page in your browser: "Sign in to Dropbox in your browser, then allow
rclone". Once added, the folder is there from every login on.

Files come down when you open them and are kept on this computer (up to 10 GB
for each cloud, longest unused going first); what you change or add is sent
back. It needs the internet: offline, the folder may not list. Added clouds
show as rows that open the folder; "Disconnect OneDrive" (type "disconnect")
removes the folder and the sidebar place, then asks whether to sign out and
free what is kept on this computer too. Changes not sent yet are lost when you
do; saying no keeps them, and adding the cloud again sends them. A folder of
your own that already has that name, with files in it, is never covered: the
Core asks you to move them first.

## Commands

```
takumi drive [--json]                          what is plugged in, how full, where it is open
takumi drive open <name>                       open it in Files (a conversation: a locked one asks)
takumi drive eject <name>                      close it and power it off
takumi drive format <name> <exfat|fat32|ext4>  erase it (a conversation that asks twice)
takumi drive write [image] [drive]             write a disk image to a USB stick or card (you type its name)
takumi drive health [disk] [--json]            each disk's health in words
takumi drive cloud add <onedrive|google|dropbox>   the cloud as a folder in your home
takumi drive cloud remove <onedrive|google|dropbox>
takumi drive cloud list [--json]               which clouds are connected, signed in or off
```

A name is the brand ("SanDisk"), the whole name ("SanDisk 64 GB"), a label
("Photos") or a device (`sdb1`, `/dev/sdb`), in any case. Exit status, for
scripts, with the last line saying it in words:

| Exit | `open` | `eject` | `format` |
|---|---|---|---|
| 0 | opened | it can be taken out | erased and ready |
| 3 | a password was needed and none came | | not confirmed: nothing erased |
| 4 | the password was wrong | something still uses it | |
| 5 | no such drive plugged in | the same | the same |
| 6 | | | not a drive this erases |
| 2 | no name given | no name given | no name, or not exfat, fat32 or ext4 |
| 1 | anything else | anything else | anything else |

`write` exits 0 written · 2 the image is not there or not one · 3 not
confirmed, nothing written · 5 no USB drive or memory card (or not that one) ·
6 the image is bigger than the drive · 1 anything else, with what happened in
`~/.local/state/takumi/drive-write.log`. `health` exits 0 every disk is
healthy or says nothing · 4 a disk is wearing out or failing · 3
smartmontools was not installed · 5 no such disk. `cloud` exits 0 done · 2
not a cloud it knows · 3 an answer was needed · 4 the folder already holds
files · 6 signing in did not finish · 1 anything else.

## How it works

udisks2 does the work, as you, with no password for a drive plugged into this
computer (polkit allows that for the person at it). `udisksctl dump` describes
every disk; `lib/drive.sh` reads it in one pass into one line per volume: its
device, label, where it is open, whether it is removable (udisks' `HintAuto`,
which it sets for USB drives and cards and never for the disk inside), the
drive's brand and size. The disk inside the computer never shows, and none of
these commands touch it.

`takumi-drives.service` runs `takumi drive watch`, which follows `udisksctl
monitor`. A drive with a filesystem that appears is mounted with `udisksctl
mount --no-user-interaction` at `/run/media/<you>/<label>`, and the Core says
so with `takumi notice --open`, so a press opens the folder. Drives already
plugged in at login are opened without a word. The watch keeps the list of
what is open in `$XDG_RUNTIME_DIR/takumi-drives-open`, following udisks' own
mount changes, which is how it knows a drive went while still open. When udisks
restarts, the monitor ends and systemd starts the watch again.

Opening an encrypted drive (LUKS, or BitLocker from Windows where udisks can
read it) asks for its password in the Core and hands it to `udisksctl unlock
--key-file` through a pipe, never as an argument; a wrong one is asked again.
Ejecting is `udisksctl unmount` for each open part, `lock` for each unlocked
one, then `power-off` when udisks can. Erasing calls udisks over D-Bus with
`busctl`: `Block.Format` writes a new partition table (MBR for exFAT and FAT32,
which every camera and television reads; GPT for ext4), then
`PartitionTable.CreatePartitionAndFormat` makes one part from 1 MiB to the end
with the new filesystem (`take-ownership` for ext4, so it is yours). polkit
decides whether that needs a password; when it does, the Core asks.

Writing an image closes every part of the drive through udisks (and locks
its encrypted parts), then runs `dd of=/dev/sdX bs=4M iflag=fullblock
oflag=direct conv=fsync status=progress` as root through `sudo`, fed by `xz
-dc`, `zstd -dc` or `gzip -dc` for a compressed image; the notes come from
dd's own progress lines. A drive is offered only when udisks marks every part
of it removable (`HintAuto`, never `HintSystem`) and none is open where the
system lives, and never when `lsblk` finds it under `/`, `/boot`, `/efi` or
`/home`. Right before writing, the drive is looked up again, so a stick
swapped while you typed is not written. The uncompressed size of an `.xz` is
`xz --robot --list`'s, of a `.zst` `zstd -lv`'s; a `.gz` does not say it, so
it is written without the size check. After `sync`, udisks powers the drive
off.

Health is `smartctl -j -a` from [smartmontools](https://www.smartmontools.org/)
(in Arch's `extra` repository), run once as root for every disk `smartctl
--scan` finds, read with jq (`lib/drive.sh`, `drive_health_words`). Failing
means SMART's own verdict failed, an NVMe critical warning or media errors, or
sectors the disk had to move or cannot read (ATA attributes 5, 197, 198).
Worn is NVMe's `percentage_used`, else ATA's "Percentage Used Endurance
Indicator", else an SSD wear attribute (177, 231 or 233); 90% or spare
blocks under the maker's line is "wearing out". Hours are the power-on hours.

A cloud is an [rclone](https://rclone.org/) remote, `takumi-onedrive`,
`takumi-google` or `takumi-dropbox` in `~/.config/rclone/rclone.conf`, made by
signing in the way backups do (`backup_signin` in `lib/backup.sh`: `rclone
config create`, which serves its sign-in page on this computer). Google Drive
gets the whole drive (`scope=drive`); a backup only ever sees its own files.
`takumi-cloud@<cloud>.service`, a user service, runs `takumi drive cloud serve
<cloud>`, which runs [rclone mount](https://rclone.org/commands/rclone_mount/)
with `--vfs-cache-mode full`, its copies in `~/.cache/takumi/cloud/<cloud>`
(`--vfs-cache-max-size 10G`), and tells systemd when the folder is ready.
rclone needs fuse3 for the mount; both are in Arch's `extra` repository. The
sidebar place is a line in `~/.config/gtk-3.0/bookmarks`, which Files reads.

"What fills my disk" is Disk Usage (`baobab`), a map of what takes the space,
shown only when it is installed. Free space is `df` on `/`.

## Not yet

- The notice offers one thing, opening; ejecting is a row in the Palette.
- CDs and DVDs: udisks powers off USB drives and cards, it does not open a
  tray.
- Naming a drive, checking a filesystem for errors, partitions, and a speed test.
- iCloud Drive: rclone has no way in that Apple allows for it.
- A cloud's files kept on this computer even when not opened ("always keep
  on this device"): rclone mount fetches on open.
- A drive in a format udisks does not know (APFS from a Mac) is listed but not
  read.

## Testing

`test/drives` runs on any machine with a fake udisks that keeps its disks in
files and prints `udisksctl dump` and `monitor` in udisks' own layout: the
names people read (brands, sizes on the box, cards without a brand, parts by
their label), the internal disk never listed, opening and unlocking with the
password only on a pipe, ejecting, erasing after two yeses with the exact
D-Bus calls, and the watch: opening at login and when plugged in, the notice
that opens the folder, and the word when a drive is taken out while open. With fake `sudo`, `dd`,
`xz`, `lsblk` and `smartctl`: writing only after the name is typed, never to a
system disk, an image too big, the picked or copied image in the row; health in
words for NVMe and SATA disks, exit 4 for a failing one. With fake rclone,
systemd and fuse: adding a cloud through the browser sign-in, the service and
the sidebar place, a folder of your own never covered, disconnecting with and
without signing out, and that nothing is written outside the home.

In the VM the real stack runs with a disk image as a USB stick: QEMU's monitor
adds one (`drive_add` and `device_add usb-storage`) and takes it away
(`device_del`), which is a drive pulled out. Real cards in a real reader, and
BitLocker drives, need the hardware.
