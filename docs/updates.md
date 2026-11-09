# Keeping up to date

Takumi looks for updates by itself once a day and says when some are waiting.
Updating is still `takumi update`: a new system beside the one you use, which
is not touched until you restart ([atomic-rooms.md](atomic-rooms.md)). With
"Prepare updates on the charger" on, the new system is built in the background
too, and the update is one restart away.

## What you see

Type "update" in the Palette. The rows come from `commands/palette/time`:

| When | Row | Enter |
|---|---|---|
| updates are waiting | Update Takumi · 42 waiting · Firefox and Linux among them · yours is not touched until you restart | `takumi update` (asks first) |
| none are | Takumi is up to date · Looked at 09:12 · Enter to look again | `takumi update check` |
| it never looked | Update Takumi, and Look for updates | either |
| a new system is ready | Restart to use the update · the one you use now stays one restart away | restart (asks first) |
| preparing is possible here | Prepare updates on the charger · Off · builds the next system while plugged in | turns it on (asks first) |
| it is on | Prepare updates on the charger: on · Ready · restart to use it | turns it off |

Once a day at most, when updates are waiting, the Core says "Updates are ready:
42 · Press to update". It is a message like an app's: do not disturb holds it,
and a press opens the Palette on "update".

"Among them" names what a person knows: Linux, Firefox, Chromium, the graphics
or NVIDIA drivers, device firmware, LibreOffice, the desktop.

## Looking for updates

`takumi-update-check.timer` (a user timer, every hour) runs
`takumi update check --auto`, which looks only when:

- a day (20 hours) has passed since it last looked,
- the computer is online (NetworkManager says connected, and the internet
  answers or it does not check), and
- the connection is not metered, as set or as NetworkManager guesses (a phone's
  hotspot): its `Metered` property is not 1 or 3.

It runs `checkupdates` from pacman-contrib, which syncs a copy of the package
lists in a temporary folder and compares it with what is installed: nothing on
the computer changes, no password is asked, and only the mirrors pacman already
uses are asked. What it finds goes to `~/.local/state/takumi/updates.json`:

```json
{"count": 42, "checked": 1794218400, "important": ["Firefox", "Linux"], "ready": false, "room": "20261101-201512"}
```

`checked` is when it last looked (seconds), `ready` is true while a new system
is staged for the next start, and `room` is the system that was running when it
counted. When the running system is not that one (an update was used, or
undone), the count is stale and set back to 0 until the next look.
`takumi update check --local` works that out without the network, and after an
update made in place it counts what is left against the package lists the last
look fetched (`checkupdates --nosync`).

`takumi update check` by hand is a conversation: "Looking for updates…", then
"42 updates are waiting, Firefox and Linux among them" or "Takumi is up to
date".

## Preparing on the charger

Off until you turn it on. `takumi update prepare on` enables
`takumi-update-prepare.timer` for you (every half hour), which runs
`takumi update prepare --auto`. It builds only when updates are waiting and
were counted against the running system, nothing is staged yet, the computer is
on the charger, online and not metered, the disk has 8 GiB free, and no update
is being prepared already (the lock `takumi update` holds). Then it starts
`takumi-update-build.service`, which runs `takumi update prepare build` as
root: the steps `takumi update` takes (`takumi room snapshot`, `upgrade`,
`stage`). The running system is never touched; a build that fails is thrown
away, and so are half-built rooms an earlier build left behind (a shutdown or
a power cut cut it short). Unplugged halfway, the build is stopped and thrown
away; the next half hour on the charger tries again. A build that fails is
said in words (below, "When an update fails"). When it is done, the
per-user migrations are staged as `takumi update` stages them, the
`~/.config/takumi/on/update-ready` hook runs, and the Core says "Update ready ·
restart to use it". What it did is kept in
`~/.local/state/takumi/update-prepare.log`.

While an update is prepared, by `takumi update` or in the background, the
computer does not go to sleep by itself: both hold a logind inhibitor lock
(`power_hold_awake` in `lib/power.sh`) that ends with them. Closing the lid
still sleeps it.

## When an update fails

It says why in one sentence, and offers the fix where there is one.
`update_why` in `lib/update.sh` reads pacman's own words (pacman runs with
`LC_ALL=C` so they are in English) in `~/.local/state/takumi/update.log`:

| pacman said | The Core says | Then |
|---|---|---|
| `unable to lock database` | Another program is installing software right now. | in place, when no pacman runs: "Unlock it and try again?" removes `/var/lib/pacman/db.lck` |
| `not enough free disk space`, `Partition / too full`, `No space left on device`, or the 8 GiB check | There is not enough space on the disk for the update. | "Free up space now?" runs `takumi update clean` in the same conversation |
| `is unknown trust`, `signature from … is invalid`, `invalid or corrupted package (PGP signature)`, `required key missing from keyring` | The keys that check the downloads are out of date. | "Try again?"; the keys are renewed first |
| `invalid or corrupted package`, `invalid or corrupted database` | A download arrived damaged and was thrown away. | "Try again?" |
| `… exists in filesystem` | The update would overwrite /usr/…, which is already on the disk. | try again in a day or two |
| `breaks dependency`, `unable to satisfy dependency`, `are in conflict` | Some packages in the update do not fit together yet (…). | try again in a day or two |
| `failed retrieving file`, `Could not resolve host`, `failed to synchronize all databases` | The download servers did not answer. | "Try again?" |

A cause Takumi does not know keeps the old sentence: "The update could not be
prepared. Nothing changed; your system is as it was." Trying again uses the same
new room: what fails there (a download, the keys) stops before anything is
installed. Keys are renewed by `takumi room upgrade` by itself, once
(`pacman-key --populate`, then the keyring packages again), before it gives up.
A room being built never keeps a pacman lock: the copy of one is removed.

Preparing on the charger keeps what the build did in
`/var/lib/takumi/update-build.log`; a build that fails is said in
`update-prepare.log` in the same words, and in the Core once a day for each
cause ("Update not prepared · There is not enough space on the disk for the
update. Free up space, then update again").

## Free up space

"Free up space" in the Palette (`takumi update clean`) is a conversation in the
Core. It says what can go, asks once, asks for the password once, and ends with
how much came back: "4.2 GB freed".

- Old downloaded packages: `paccache -rk2` keeps the two newest versions of each
  package in `/var/cache/pacman/pkg`, and `paccache -ruk0` drops every version
  of a package no longer installed. paccache comes with pacman-contrib (Arch's
  `extra` repository), which Takumi's lists name; it is installed then if it is
  missing.
- Older systems: `takumi room prune --auto`, which keeps the running room, the
  default, pinned ones, anything staged or being built, and the newest three
  good ones ([atomic-rooms.md](atomic-rooms.md)). Btrfs gives their space back
  in the background, so it waits for that (`btrfs subvolume sync /`, at most five
  minutes) before counting.
- Packages nothing uses (`pacman -Qdtq`, never one Takumi's lists name): with
  rooms they leave with the next update, inside the new room, where going back
  undoes it; without rooms they are removed here (`pacman -Rns`).
- The system's logs: `journalctl --vacuum-size=200M`.
- The Trash, after asking a second time, since what is in it cannot be brought
  back: `gio trash --empty`.

The part that needs root is one call, `takumi update clean --system
[--orphans]`, through the password asked in the Core. It does not run while an
update is being prepared; `takumi update` offers it when it runs out of space
and passes its lock on. With rooms, old downloads still shared with an older
room come back only when that room is deleted, which is why the rooms go first.

## Commands

```
takumi update check [--auto|--local]    look now; --auto as the timer does; --local without the network
takumi update prepare on|off|status     prepare updates on the charger
takumi update clean                     free up space
```

| Exit | `update check` | `update prepare` | `update clean` |
|---|---|---|---|
| 0 | looked (or, with `--auto`, had no reason to) | done | done |
| 1 | no pacman-contrib, or no answer from the mirrors | it cannot here (no rooms, no build unit), or the build failed | declined, no password, an update being prepared, or `--system` not as root |
| 2 | usage | usage | |

## Not yet

- **The build unit and its permission are not in this tree.**
  `takumi-update-build.service` (a system unit that runs
  `/usr/bin/takumi update prepare build`) and a polkit rule that lets the person
  at the computer start and stop that one unit without a password
  (`etc/polkit-1/rules.d/50-takumi-update.rules`) are missing. Until they are,
  "Prepare updates on the charger" shows no row and
  `takumi update prepare on` says "This computer cannot prepare updates by
  itself yet".
- **Changes made after a system was prepared do not reach it.** Staging copies
  Wi-Fi networks, Bluetooth pairings, passwords, the time zone and printers
  into the new system when it is staged, as `takumi update` does. A network
  joined or a password changed between then and the restart is not carried.
  Copying them again at shutdown would close this for both.
- **`takumi update` does not know a system is already prepared**: run by hand,
  it builds another.
- **No mark in the resting Core** while updates wait; `updates.json` holds what
  one would show.
- **The daily look starts only once the session starts its timer**
  (`takumi-update-check.timer`).

## Testing

`test/updates` runs on any machine with fake checkupdates, NetworkManager,
systemd, flock and notify-send: the count and the names a person knows, no
answer from the mirrors, once a day and never offline or metered, one message a
day at most and the Palette opened by a press, what is ready, a count gone stale
after a restart and what is left after an update made in place, every update row, and preparing: only on the charger,
not metered, with room on the disk, not twice, a failed build, stopped when
unplugged, on and off, and building refused to anyone but root.

`test/recovery` covers failures said in words (each cause from pacman's own
words, the fix offered, trying again in the same room, a lock nobody holds),
"Free up space" (one password, unneeded packages left to the next update with
rooms, the Trash asked about, how much came back) and restore points.

The code: `commands/update/check`, `commands/update/prepare`,
`commands/update/clean`, `lib/update.sh`, the update part of `lib/clock.sh` and
`commands/palette/time`, and
`default/systemd/user/takumi-update-{check,prepare}.{service,timer}`.
