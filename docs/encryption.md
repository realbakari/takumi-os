# Encryption

A computer installed from [the setup disc](iso.md) has an encrypted disk: a
thief who takes the laptop gets nothing. There is no switch for it. It asks
for one password, and you are never locked out.

## What you see

- **When the computer starts**: the 匠 splash with a password field under
  the tile. Type your password; the desktop follows, without a second
  login. After you log out, the login screen asks as usual.
- **A keyboard plugged in later** still types the password: every keyboard
  driver is in the initramfs.
- **The keyboard is the one you chose in setup**, before anything else, so
  the password types at the start as it did when you chose it. A keyboard
  without Latin letters starts in US English, as it did in setup.
- **If you forget your password**: type the recovery code instead, with its
  dashes or without.
- **A new recovery code**: the Palette row "New recovery code" (`takumi disk
  recovery`) asks for your password once, makes a new code and shows it on a
  card, hidden until you press Enter, beside a code a phone camera keeps. The
  old code stops opening the disk.
- **A new password**: the Palette row "Change your password" (`takumi
  password`) changes it for your account and for the disk together, so the
  one password keeps opening both. The recovery code keeps working
  ([security.md](security.md)).
- **Opening by itself**: on a computer with a TPM 2.0 and Secure Boot on,
  the row "Open the disk by itself" (`takumi disk tpm on`) lets the
  computer's security chip open the disk when it starts. The disk opens by
  itself on this computer unless someone changes how it starts; your
  password and recovery code still work. The login screen then asks for your
  password, since nobody typed one at the start.

## The disk

```
/dev/nvme0n1p1   1 GiB, FAT32, /efi         systemd-boot and each room's kernel
/dev/nvme0n1p2   LUKS2, label takumi
  └ /dev/mapper/takumi   Btrfs: @rooms/<room>, @home, @var-log, @var-lib-takumi
```

| Key slot | Holds |
|---|---|
| 0 | your password (argon2id, cryptsetup's default cost) |
| two more | the recovery code, as shown and without dashes (PBKDF2 at the minimum: the code carries 120 bits, so a slow key function adds nothing but waiting) |
| one more, while the disk opens by itself | a key sealed to the TPM, which gives it back only while Secure Boot is in the same state with the same keys (PCR 7) |

A LUKS2 token of type `takumi-recovery` names the code's slots, so a new code
replaces exactly those and never the password's. The TPM's slot has a token
of type `systemd-tpm2`, systemd-cryptenroll's own. A new password replaces
slot 0 in place and leaves every other slot alone. Discards are allowed and
the kernel's extra work queues are off, both kept in the LUKS2 header, so an
SSD stays fast. Every secret reaches cryptsetup and systemd-cryptenroll
through a pipe, never a command line (`lib/disk.sh`).

## The recovery code

36 digits in six groups of six: `482913-…`. Digits, because every keyboard
types them and none is mistaken for a letter. It is made from the kernel's
random numbers, shown once at the end of setup and once each time you ask for
a new one, and never written to the disk. Setup asks for its last six digits
before going on.

## Changing the password

`takumi password` asks for your password, checks it the way the Lock does,
then for the new one twice. As root, it changes key slot 0 first
(`cryptsetup luksChangeKey --key-slot 0`, the old and new passwords through
pipes), then the account (`chpasswd`, on stdin). If the account refuses, slot
0 is changed back, so the two never drift apart. When the disk still opens
with an earlier password than the account's, it asks whether to change that
too, with the disk's own password; no, and the account alone changes. A disk
that is not encrypted: the account alone.

## A new owner, and erasing

A computer set up for someone else starts with a password for now in key slot
0. At its first start `takumi setup owner apply` replaces that slot with the
owner's password, adds a new recovery code that only the owner sees, and
removes the old ones. `takumi settings erase` moves slot 0 to the password
for the next start and removes the recovery and security-chip slots
([setup.md](setup.md)).

## Opening by itself

`takumi disk tpm on` needs Secure Boot on ([security.md](security.md)):
without it, the chip would see nothing change when someone starts the
computer from a USB stick, and would open the disk for them. It asks for your
password, which lets it add a key slot, and then, as root:

1. The login screen asks for your password from now on: the one-password
   start (greetd's `[initial_session]`) goes, since nobody typed anything.
2. The boot menu's editor goes (`editor no` in `loader.conf`), so nobody
   changes a room's kernel options at the menu.
3. `systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7`
   seals a new key slot to the chip and takes any earlier one away
   ([systemd-cryptenroll](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html)).
4. `rd.luks.options=<uuid>=tpm2-device=auto` goes into `/etc/kernel/cmdline`,
   so the initramfs asks the chip before the password
   ([crypttab](https://www.freedesktop.org/software/systemd/man/latest/crypttab.html),
   [systemd-cryptsetup-generator](https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptsetup-generator.html)).
5. The initramfs is made again, with the chip's libraries, and this room's
   boot entry with it (`takumi room kernel-sync`). Every new room copies the
   option and the login screen's settings from this one.

When Secure Boot's keys change, or a firmware update changes its list of
refused programs, the chip no longer recognises the start and the disk asks
for your password, once. "Open the disk by itself" then seals the key again.
A room made before the chip was asked does not ask it either: going back to
one, the disk asks for the password.

`takumi disk tpm off` takes the chip's slot and the option away and brings
the one-password start back. Without a word, `takumi disk tpm` says which way
the disk opens. Exit codes: 0 done, 1 not possible here or cancelled, 3 the
password did not work.

## How it starts

| Piece | Does |
|---|---|
| `/etc/kernel/cmdline` | `rd.luks.name=<uuid>=takumi root=/dev/mapper/takumi`, and `rd.luks.options=<uuid>=tpm2-device=auto` while the disk opens by itself, copied into every room's boot entry, so going back to a room opens the disk the same way ([atomic-rooms.md](atomic-rooms.md)) |
| `etc/mkinitcpio.conf.d/takumi-encrypt.conf` | `sd-encrypt` after `block`, `sd-vconsole` for the keyboard, and `keyboard` before `autodetect`; installed by `install/steps/30-boot.sh` only when `/` is on LUKS |
| `/etc/vconsole.conf` | `KEYMAP` for the password prompt, `XKB*` for the login screen and niri |
| plymouth | asks for the password in the splash ([boot.md](boot.md)) |
| greetd | `initial_session` runs your session once per start while the disk asks for the password: it was opened with your password a moment ago (`install/steps/40-session.sh`; greetd's runfile keeps it to once per start, so a logout or a restart of greetd shows the login screen). While the disk opens by itself it is not there. |

## Not done

- **The login keyring after the one-password start.** Nothing is typed at
  the login screen, so the login keyring is still locked when the session
  starts. It opens the first time you unlock the Lock with your password;
  before that, an app that keeps a password there asks for it once
  ([security.md](security.md)).
- **The chip trusts more than it checks.** It checks Secure Boot's state and
  keys, which cover systemd-boot and each room's kernel, but not the
  initramfs or the kernel options on the boot partition. Someone with the
  laptop in hand, a USB stick Microsoft signed and the skill to change those
  files could still reach the disk while it opens by itself. Signed unified
  kernel images per room would close that; until then the password at every
  start is the stronger choice.
- **Encrypting an existing install**: only the setup disc makes encrypted
  disks.

## Testing

`test/setup` checks the install's locking and the recovery code against a
fake cryptsetup: the password on stdin only, the code's two slots and its
token, a new code replacing the old one's slots and never slot 0, three wrong
passwords stopping it. `test/security` checks a new password (slot 0 changed
in place, the recovery code's slots kept, the disk put back when the account
refuses) and opening by itself (the sealed slot and its token, the kernel
option, the login screen asking, the boot menu's editor, and off putting all
of it back) against fake cryptsetup and systemd-cryptenroll. `test/iso`
checks the initramfs hooks it adds.
