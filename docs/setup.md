# Setup

The first screen on [the setup disc](iso.md): five questions, then the install,
then the recovery code, then a restart. It runs before anything is installed,
so it explains nothing that needs Takumi to be understood, and nothing in it
asks for a terminal. The same screen is also the **first start** of a computer
set up for someone else, or erased: it asks the owner and gives them the
computer (below).

## What you see

The 匠 tile above a pane of glass on the night sky. Enter goes on and Esc
goes back from anywhere; five dots under the glass say how far you are.

1. **Which language?** The language the apps and the desktop speak, from
   glibc's own list (`takumi language list`, [languages.md](languages.md)),
   by name in English and in its own words. The list starts on a guess from
   the language the computer's firmware speaks (`fr-FR` gives French
   (France)); typing finds a language or a country. A pick turns the next
   two questions to where its people mostly are (`takumi setup facts --for
   FR`: the French keyboard, Paris), unless the person chose them already.
   The setup screen itself stays in English, and says so.
2. **Which keyboard is this?** Before anything is typed that matters. The
   list starts on the language's guess, or the firmware's. Typing finds a
   language or a country; a pick changes the keyboard at once, so the field
   under the list tries it. Enter picks the row the arrows rest on; Enter on
   the chosen one goes on. A keyboard that types no Latin letters (Russian,
   Greek, …) comes second, after US English, with Left Alt + Right Alt
   between them, as on the login screen: a password is typed in Latin
   letters.
3. **Where are you?** A city, for the clock. The list starts on the
   language's or the firmware's country. The time there shows under the
   list, and the sky turns to that time of day. With a network, **Find it
   online** asks ipinfo.io where this network is (`takumi setup zones
   --guess`, the same lookup as `takumi clock auto`, [time.md](time.md)):
   only when pressed, once, and the line under the list says it asks
   ipinfo.io before it does. Nothing else in setup uses the network.
4. **Who is this computer for?** **For me** (first) or **For someone else**.
   For me: your name, then a password, twice. The account and the computer
   are named from your first name (`Ana López` makes `ana` and
   `ana-takumi`), shown under the name. The password needs six characters;
   it also opens the disk when the computer starts. For someone else: only a
   password for now, twice (below).
5. **Where should Takumi go?** Every disk but the setup disc, with its
   size and what is on it now: "Windows is on it", "Empty". The chosen one
   says what erasing it takes away, in red. "Erase and install" turns red and
   waits five seconds for a second press. A disk under 30 GB is listed but
   cannot be chosen. On battery under 20%, it waits for the charger.
   A disk with Windows and at least 30 GB of free space beside it offers
   **Beside Windows** first: Takumi goes into the free space and Windows stays
   as it is. When Windows has no room yet, the page says how to make some
   (Disk Management, Shrink Volume) instead.

Then **Installing Takumi**: what it is doing, in words, and a line that
fills. **Keep your recovery code**: the code in digits and as a code a phone
camera keeps; going on asks for its last six digits, so it was really kept
([encryption.md](encryption.md)). **Takumi is ready**: take the stick out and
restart; or turn the computer off. For someone else there is no recovery
code yet: **Takumi is ready for its owner** says to turn it off and give it
to them with the password for now.

If the install stops: where it stopped, the last lines of its log, and Try
again.

## For someone else

Someone setting a computer up for a parent, a friend or an employee chooses
**For someone else** and types a password for now, twice. The install then
differs in four ways:

- The disk is locked with the password for now, and gets no recovery code:
  the code is its owner's, and nobody else sees it.
- The Takumi installer runs as a passing account, `takumi-setup`, which is
  removed, home and all, once it is done. The computer has no person's
  account and is named `takumi`.
- `/var/lib/takumi/first-start` is written, readable by root alone, holding
  the password for now (on the encrypted disk), and
  `takumi-first-start.service` is turned on.
- The login screen does not open a session by itself.

## The first start

`default/systemd/system/takumi-first-start.service` runs when
`/var/lib/takumi/first-start` exists, before greetd: a session of its own on
the first console, as the `greeter` user, as
[systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html)
describes for `PAMName=` and `TTYPath=`.

1. As root, `takumi setup owner prepare` finishes an erase if one is marked
   (below), then writes `/etc/sudoers.d/takumi-first-start`, which lets
   `greeter` run `takumi setup owner apply`, `systemctl reboot` and
   `systemctl poweroff` without a password, and nothing else.
2. As `greeter`, `takumi setup start --owner` draws the skies from Takumi's
   default theme, starts on the keyboard the computer was set up with (the
   disk's password prompt typed with it a moment ago), and shows the setup
   screen in first-start mode (`TAKUMI_SETUP_MODE=owner`).
3. The owner answers four of the five questions: the language, the keyboard
   and the place start on what the computer was set up with; then **Whose
   computer is this?**: their name and their password, twice.
4. **Set up** runs `takumi setup owner apply` as root, with the answers on
   one line and the password on the next of its input: the account (in
   `wheel`), the computer's name, `/etc/vconsole.conf`, the time zone, the
   language (`/etc/locale.gen`, `locale-gen`, `/etc/locale.conf`); with a
   new keyboard, the initramfs again so the disk's prompt types with it; then
   key slot 0 changes from the password for now to theirs, a new recovery
   code goes on the disk and the old ones come off, and the login screen
   opens their first session by itself. Last, the mark and the sudo rule go.
5. **Keep your recovery code**, as after an install, then **Welcome**:
   **Start** ends niri, the service ends, and greetd opens their desktop.

If `apply` stops, the account it made goes again; the disk keeps whichever
password it took last, and the mark says which, so **Try again** starts
over. A screen that stops comes back, three times at most; a computer turned
off in the middle starts here again.

## Erasing

`takumi settings erase` (**Erase this computer** in the Palette) is a
conversation in the Core: a yes, the word `erase` typed out, your password,
and on an encrypted disk a password for the next start, twice. Then, as root:

- **Now:** key slot 0 changes from your password to the one for the next
  start; the security chip's key and the recovery code come off the disk, and
  the kernel options stop asking the chip; the login screen stops opening a
  session by itself; the next start is this room, not an update prepared for
  later; `/var/lib/takumi/first-start` (with the password for the
  next start) and `/var/lib/takumi/erase` are written; the first start is
  turned on; the computer restarts in six seconds.
- **At the next start**, before anyone logs in, `takumi setup owner prepare`
  removes every person's account (UID 1000 to 59999) with its home, mail and
  cron table; saved networks (`/etc/NetworkManager/system-connections`);
  Bluetooth pairings (`/var/lib/bluetooth/<adapter>/<device>`); fingerprints
  (`/var/lib/fprint`) and the finger's PAM lines; the login screen's copy of
  the look; the journal and the setup log; and every room but the running
  one, which becomes the default. The name goes back to `takumi`. Then the
  first start asks who the computer is for.

Accounts are removed at the start, not while you are logged in: the session
running the conversation, and every app in it, would otherwise be using the
homes being deleted.

**Rooms.** Each room has its own `/etc`, so its own accounts, passwords,
saved networks and fingerprints; `/home` is shared by every room
([atomic-rooms.md](atomic-rooms.md)). Erasing only the running room would
leave the old accounts in the older rooms, and `takumi rollback` would bring
them back, with homes that are gone. So an erase keeps the running room
alone; there is nothing to go back to afterwards, and the first update after
it starts the history again.

**What it does not erase.** The apps and Takumi itself, printers, the
computer's hardware settings (`/var/lib/takumi/charge-limit`,
`hardware.json`), and the disk's own key. Files are deleted, not
overwritten: the disk is not encrypted again, so what was deleted stays on it
under the same key, out of reach of the new owner's password but not
destroyed. To be sure nothing can be recovered, install again from the setup
disc, which makes a new key.

## How it works

| Piece | Does |
|---|---|
| `shell/setup.qml`, `shell/Setup/` | the screen: a layer over niri, the Sky, the glass, the pages |
| `takumi setup start [--owner]` | greetd runs it as `live`: niri with the setup screen, or with Mesa's software driver when the GPU cannot draw; `--owner`, the first start |
| `takumi setup facts [--for <country>]` | the guesses and the computer: language, keyboard and place from the firmware's language (at a first start, what the computer was set up with), UEFI, battery and charger, a network, software drawing; `--for`, a country's keyboard and place |
| `takumi language list --json` | every language glibc can make, by name ([languages.md](languages.md)) |
| `takumi setup keyboards` | every layout and variant from xkeyboard-config, by name |
| `takumi setup keyboard <layout> [variant]` | rewrites the screen's niri config; niri reads it again by itself |
| `takumi setup zones [--at <zone> \| --guess]` | every time zone by city and country; or the time in one, and the sky's phase there; or where this network is, from ipinfo.io |
| `takumi setup disks` | the disks, their sizes, what is on them, which can be used |
| `takumi setup install` | the install, as root ([encryption.md](encryption.md) for the disk) |
| `takumi setup owner prepare \| apply` | the first start, as root: an erase's leftovers; the owner's account and password |
| `takumi settings erase` | erasing, as a conversation in the Core |
| `takumi-first-start.service` | the first start, before the login screen, while `/var/lib/takumi/first-start` exists |

The screen sends the install its answers as one JSON line and the password
on the next, on its input; the password is never on a command line. The
answers carry `locale` (the language), and `"owner":"later"` for someone
else. `takumi setup owner apply` is spoken to the same way. The
install answers one line at a time: `step <words>`, `progress <0-100>`,
`recovery <code>`, `done`, or `fail <words>`. Its log is
`/run/takumi-setup/install.log`, and a copy is kept on the new disk at
`/var/log/takumi-setup.log`; neither holds the password or the code.

### The install, in order

1. Erases the disk: GPT, a 1 GiB boot partition (`/efi`), the rest for Takumi.
2. Locks it: LUKS2 with your password, then the recovery code, then opens it
   (discards allowed, so an SSD stays fast).
3. Btrfs inside, with the first room and the shared subvolumes
   ([atomic-rooms.md](atomic-rooms.md)).
4. One pacstrap of every package, from the disc.
5. The keyboard (`/etc/vconsole.conf`, read by the disk's password prompt,
   the login screen and niri), the time zone, the language
   (`/etc/locale.conf`, made by `locale-gen` with English (US) beside it),
   the name, your account (in `wheel`), systemd-boot, the first room as the
   default; root has no password.
6. The Takumi installer, as you, inside the new system, offline.
7. For someone else: the passing account goes, the first start is marked and
   turned on.
8. Package lists, when there is a network.

### Beside Windows

Only the disk's largest free stretch is used; no partition of Windows is
moved, resized or formatted. In it go Takumi's own boot partition (1 GiB,
XBOOTLDR, which holds each room's kernel) and the encrypted partition.
systemd-boot is installed on the boot partition Windows already has, finds
Windows Boot Manager by itself, and shows its menu for three seconds at every
start: Takumi first. A Windows disk encrypted with BitLocker stays encrypted;
Windows asks once for its recovery key afterwards, because what starts it has
changed, and the page says so before anything happens.

## Not done

- Installing beside macOS, or into space Windows still uses (Takumi never
  shrinks a partition: Windows does that itself, safely).
- Wi-Fi during setup: nothing needs it. The new computer joins from the
  Core.
- A screen reader during setup: the pages carry accessible names, but the
  disc starts no screen reader.
- Languages other than English for the words on the screen.
- Input methods (Chinese, Japanese, Korean) on the setup screen: they are
  set up after, with `takumi keys input` ([harmony-keys.md](harmony-keys.md)).
- An erase that destroys deleted files: see "What it does not erase".

## Testing

`test/setup` runs every command against fake tools: the guesses (language,
keyboard, place, a country's, the network's), the keyboards, the places, the
disks (a Windows laptop's, a USB disk, a stick too small, a virtual one), a
whole install that checks the password and the code never reach a command
line or the log, an install for someone else, the answers it must refuse
before it erases anything, the first start's `prepare` after an erase and its
`apply`, and the erase conversation with what it refuses.
