# Security

Signing in and starting safely live in the Core, like everything else. Type
"security" (or "password", "fingerprint", "secure boot", "tpm") and the
Palette lists what this computer can do. A row shows only where it can work:
the finger with a fingerprint reader, Secure Boot on a computer that has it,
the disk's security chip with an encrypted disk and a TPM.

## What you see

| Row | Shows when | Enter |
|---|---|---|
| Change your password | always | asks for your password, then a new one twice |
| Unlock with your finger · "Touch the sensor instead of typing your password" | a fingerprint reader is there | takes a finger |
| Unlock with your finger · "On · 1 finger · Enter adds another" | your finger is known | takes another finger |
| Stop unlocking with your finger | your finger is known | removes your fingerprints |
| Secure Boot is on | Secure Boot is on | says so |
| Turn on Secure Boot · "The firmware is ready for this computer's own keys" | the firmware waits for keys | makes the keys and signs Takumi |
| Turn on Secure Boot · "Off · Enter shows how" | Secure Boot is off | says how, offers the firmware's settings |
| Open the disk by itself / The disk opens by itself | an encrypted disk and a TPM 2.0 | [encryption.md](encryption.md) |

Every row but "Secure Boot is on" asks in place first, and each runs as a
conversation in the Core: questions in the field, what it is doing under
the row.

## Your password

One password does everything: the disk when the computer starts, the login
screen, the Lock, the login keyring, and the approvals the system asks for.
"Change your password" keeps it that way. It asks for your password, then a
new one twice, and changes it for your account, the disk and the login
keyring in one go. The recovery code keeps working.

- A wrong password shakes the field and is asked again, three times.
- The new one needs six characters or more, like the one setup asked for,
  and has to differ from the old one. Typed twice differently, both are
  asked again.
- When the disk still opens with an earlier password (one changed before
  this command existed), it says so and asks whether to change that too,
  with the disk's own password.
- On a disk that is not encrypted, it changes the account alone.
- When the login keyring was locked with another password (one set before
  Takumi opened it with yours), it keeps that one, and the Core says "The
  login keyring still opens with its earlier password".

## The login keyring

Apps keep their passwords (Wi-Fi of work networks, mail accounts, the
assistant's keys) in the login keyring, gnome-keyring's "login" collection,
locked by your password. It opens with the password you sign in with, so no
app asks for it:

- **At the login screen**, the password you type opens it as the session
  starts.
- **After a start that opened the disk** (the one-password start,
  [encryption.md](encryption.md)) nothing was typed at the login screen, so
  the keyring is still locked: the first time you unlock the Lock with your
  password, it opens too. Before that, an app that needs it asks once.
- **At the Lock**, the right password opens it whenever it is locked.
- A finger opens the Lock but not the keyring: it carries no password.

## Ten tries

Ten wrong passwords in a row, at the login screen, the Lock, sudo or an
approval, and the account waits two minutes before it takes another; the
count starts again after a right one. The Lock says "Locked for 2 minutes"
(the minutes pam_faillock says are left) instead of "Try again". The tenth
wrong try itself still says "Try again"; the one after it says how long.

## Your finger

"Unlock with your finger" takes a finger in the Core. The row says "Touch
the sensor · 3 of 8" as each touch lands, asks for a longer touch or a
centred finger when the reader wants one, and closes with "Your finger
unlocks this computer now". A reader you swipe says "Swipe your finger
across the sensor". Nothing is saved if nobody touches it for thirty
seconds. Enter on the row again adds another finger. The first time, the
Core asks for your password once, to let the finger answer approvals too.

Where a finger answers:

- **The Lock.** The finger mark sits under the field (see "The Lock" below).
  Typing a password still works at once; the finger never makes it wait.
- **Approvals apps ask for** (a disk, the network, the printer, firmware).
  The Core's approval asks for a finger first, for ten seconds, then for the
  password.
- **sudo in a terminal**, the same way.

Where it does not: the login screen after the computer starts (the password
also opens the session's keyring there), Takumi's own commands in the Core
(they ask for your password in the Core, as before), and anywhere while the
lid is closed, since the lid covers the sensor. Three wrong fingers in a row
and the password is asked.

"Stop unlocking with your finger" removes your fingerprints. When nobody on
this computer has one any more, the approvals stop asking for a finger.

### The Lock

While fingerprint unlock is on and the lid is open, the Lock shows a finger
mark under the field, dim, with "Touch the sensor or type your password" in
the field. A touch that matches unlocks at once. A finger that does not
match shakes the mark and outlines it red, and the line under the field says
"Not recognised"; after three, the mark goes out and the field says "Type
your password" until the next lock. The mark is not there with the lid
closed, before the reader answers after a wake, or when no finger is known.

## Secure Boot

With Secure Boot on, the firmware starts only what this computer's own keys
signed: systemd-boot, then the kernel of the room it starts. Something that
changed them on the boot partition, or a program that tries to start before
Takumi, does not start.

- **On**: the row says so, and every new room's kernel is signed as the room
  is made.
- **Off, with the maker's keys**: Takumi cannot add keys until the firmware
  forgets its own. The row says how: in the firmware's settings, under
  Secure Boot, choose "Reset to Setup Mode" or "Clear All Keys", keep Secure
  Boot on, then come back. It offers to restart straight into those
  settings.
- **Ready for keys** (setup mode): one question, then Takumi makes this
  computer's own keys, signs systemd-boot, fwupd's firmware program and
  every room's kernel with them, and puts the keys in the firmware with
  Microsoft's beside them. Microsoft's stay because Windows, graphics cards
  and other add-in cards carry programs only Microsoft signed. With Windows
  on the computer the row says first that BitLocker, if Windows uses it,
  asks for its recovery key once.

The keys are made on this computer and never leave it. If a computer still
refuses to start afterwards, its firmware's "Restore Factory Keys" puts the
maker's keys back.

## Commands

The Core runs these; they work at a terminal too.

```
takumi password                              change your password, for the account and the disk
takumi security fingerprint [on|off|--check] add a finger, remove your fingerprints; no word: the state
takumi security secure-boot                  Secure Boot's state, and setting it up
takumi disk tpm <on|off>                     the disk opens by itself, or asks; no word: the state
```

`takumi disk tpm` is in [encryption.md](encryption.md).

| Exit | `takumi password` | `takumi security fingerprint` |
|---|---|---|
| 0 | changed | done |
| 1 | cancelled, or not possible here | not possible here (no reader, no fprintd) |
| 3 | your password did not work three times | nobody touched the sensor |
| 4 | the disk's password did not work three times | the reader could not take that finger |

The login keyring's change never changes the exit code: when it keeps its
earlier password, the Core says so and the command still ends 0.

`takumi security fingerprint --check` is the Lock's question: 0 when your
finger can unlock it now. `takumi security secure-boot` ends 0 when it is
done or nothing was needed, 1 when it is not possible here or you said no.

## How it works

**Passwords never travel as arguments.** The Core writes them to the
command's stdin. Your password is checked as the Lock checks it, by
pam_unix's own helper (`unix_chkpwd`), which reads it on stdin. The command
then runs itself as root through `sudo -S`, which reads the same password
from the first line and hands the rest on; `setsid` takes the terminal away
first, so sudo never waits for a finger there. As root it checks the
password again, changes key slot 0 with `cryptsetup luksChangeKey` (both
passwords through pipes), then the account with `chpasswd` on stdin. If the
account refuses, slot 0 is changed back. The recovery code's slots are never
touched ([encryption.md](encryption.md)).

**The login keyring follows the password.** After the account changed, the
command, still as you, hands both passwords on stdin to
`security_keyring_rekey` (`lib/security.sh`), which calls gnome-keyring's
own method for it, `ChangeWithMasterPassword` on
`org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface`, with the
"login" collection and both passwords as Secret Service secrets of a plain
session it opened first. The session belongs to one D-Bus connection, which
bash cannot hold, so a few lines of python3 with GObject (`python-gobject`)
make the calls; the passwords never reach an argument. pam_gnome_keyring's
own password step would do the same, but only inside `passwd` run in your
session; Takumi changes the account with `chpasswd` as root.

**The keyring at sign-in.** The Lock's own file, `/etc/pam.d/takumi-lock`,
is `auth include login` and then `auth optional pam_gnome_keyring.so`, which
opens the keyring when it is running and locked
([pam_gnome_keyring](https://wiki.gnome.org/Projects/GnomeKeyring/Pam)).
greetd's file, `/etc/pam.d/greetd`, belongs to greetd and has no folder for
extras, so `install/steps/27-security.sh` adds Takumi's lines at its end,
between marks, and leaves the rest as it is:

```
# takumi-keyring: begin (the login keyring opens with your password; docs/security.md)
auth       optional                    pam_gnome_keyring.so
session    [success=1 default=ignore]  pam_succeed_if.so quiet user = greeter
session    optional                    pam_gnome_keyring.so auto_start
# takumi-keyring: end
```

The auth line keeps the password you typed; the session line starts the
keyring and opens it with that password. The greeter's own account (the
login screen itself) skips it. A file written whole, in one step, only when
it changes; a greetd that keeps its file in `/usr/lib/pam.d` gets a copy in
`/etc/pam.d` with the lines.

**Ten tries** are pam_faillock's, which Arch's `system-auth` already runs
for every sign-in. It reads only `/etc/security/faillock.conf`, which belongs
to the pam package and has no folder for extras, so
`install/steps/27-security.sh` sets the two lines of Takumi's
`etc/security/faillock.conf` in it, `deny = 10` and `unlock_time = 120`, in
place of the same settings (commented or not), keeping every other line
([faillock.conf(5)](https://man.archlinux.org/man/faillock.conf.5)). The
file is in pam's backup list, so pacman keeps it across pam's updates and
leaves a new version beside it as `.pacnew`. The Lock reads pam_faillock's
own words, "(2 minutes left to unlock)", from the PAM conversation; in a
language other than English they do not match, and it says "Try again".

**A computer installed before these.** Takumi's system files reach a
computer through its installer, which is safe to run again: running
`~/.local/share/takumi/install/run.sh` after an update of the checkout sets
up the keyring lines, faillock and the Lock's file. An update of the rooms
alone does not change them.

**A finger for sudo and polkit.** Their PAM files belong to their packages
and have no folder for extras, so `takumi security fingerprint` puts four
lines of Takumi's in front of their `auth include system-auth`, in
`/etc/pam.d/sudo` and `/etc/pam.d/polkit-1`:

```
# takumi-fingerprint: begin (takumi security fingerprint; docs/security.md)
auth       [success=ignore default=1]  pam_exec.so quiet /usr/lib/takumi/commands/security/finger-ready
auth       sufficient                  pam_fprintd.so timeout=10
# takumi-fingerprint: end
```

`finger-ready` says no for sudo without a terminal, which is a Takumi
command in the Core whose password comes from the Core, and for a closed
lid. Then
[pam_fprintd](https://manpages.debian.org/testing/libpam-fprintd/pam_fprintd.8.en.html)
waits ten seconds for a finger before the password. `off` takes the lines
out, and a file is written whole, in one step, only when it changes.
`install/steps/27-security.sh` keeps the lines in their current form when
they are there, and installs the Lock's own file.

**The Lock checks a finger beside the password**, never before it. Its
password check is `/etc/pam.d/takumi-lock` and stays as it was; while
fingerprint unlock is on, the Lock runs `/etc/pam.d/takumi-lock-finger`
(`pam_fprintd.so max-tries=3 timeout=-1`) at the same time, so whichever
answers first unlocks.

**Fingers** come from fprintd: `fprintd-list` says whether there is a reader
and which fingers are known, `fprintd-enroll` takes one (the next free
label: right index, then left index, then the thumbs), `fprintd-delete`
removes yours. The count of touches and the kind of reader are the reader's
own `num-enroll-stages` and `scan-type`, read over D-Bus with `busctl` while
it is taking the finger. Fingerprints live in `/var/lib/fprint`, which every
new room carries over.

**Secure Boot** is read from the firmware's own variables (`SecureBoot`,
`SetupMode`) and set up with
[sbctl](https://github.com/Foxboron/sbctl): `sbctl create-keys`, then
`sbctl sign`, then `sbctl enroll-keys --microsoft --ignore-immutable` last,
so nothing unsigned is left when the keys go in. systemd-boot and fwupd's
UEFI program are signed beside themselves as `.signed` files and kept in
sbctl's list: `bootctl` copies the signed systemd-boot
([bootctl](https://www.freedesktop.org/software/systemd/man/latest/bootctl.html)),
and sbctl's own pacman hook signs each new version, inside a room an update
builds too. The copies on the boot partitions and each room's kernel are
signed where they are, and each new room's kernel as `rooms_write_entry`
copies it (`lib/rooms.sh`). With this computer's own keys, fwupd starts its
own signed program for a firmware update instead of shim
(`DisableShimForSecureBoot=true` in `/etc/fwupd/fwupd.conf`).

The code: `lib/security.sh`, `commands/password/main`,
`commands/security/*`, `commands/palette/security`, `default/pam/` and
`install/steps/27-security.sh`.

## Not done

- **The initramfs is not signed.** Secure Boot checks systemd-boot and each
  room's kernel; the initramfs and the kernel options beside them on the
  boot partition are not checked. Signed unified kernel images, one file per
  room, would close that.
- **A room made before Secure Boot was set up** has no keys inside it. Going
  back to it works, but a kernel installed in place inside it (`pacman -Syu`
  there) is not signed, and the firmware refuses it.
- **Security keys (FIDO2)** for approvals, and a finger at the login screen.
- **An account without administrator rights** cannot change its password
  from the Core yet.
- The login screen does not say "Locked for 2 minutes"; it says the password
  did not work.
- A keyring locked with another password before Takumi opened it with yours
  keeps that password: Takumi has no row to change it to yours.

## Testing

`test/security` runs on any machine with fake sudo, `unix_chkpwd`,
`chpasswd`, cryptsetup, systemd-cryptenroll, fprintd, busctl and sbctl, and
fake firmware variables and a fake python3 for the keyring: every
conversation's lines in the Core, every exit code, the key slots and the
login keyring before and after, the PAM files with and without Takumi's
lines (the rest of each file unchanged), faillock.conf from pam's own text, the order sbctl signs and
enrolls in, and that no password reaches any command's arguments.

The VM has no fingerprint reader, no TPM and firmware without Secure Boot,
so there it checks what each command says when the hardware is missing, and
changing the password, which needs no hardware. A reader, a TPM and Secure
Boot need a real computer.
