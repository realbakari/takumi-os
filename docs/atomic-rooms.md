# Atomic rooms

How Takumi updates and how it undoes. The system you are using is never
changed by an update. An update prepares a new system next to it, the
**room**, and the next start tries it once. If the new room reaches your
desktop it becomes the default. If it does not, the very next start is the
system you had, and the Core tells you what happened in one sentence.

## Layout

One Btrfs filesystem (encrypted on a Takumi install, see the roadmap) with:

```
@rooms/20261108-093000      one subvolume per room, named by when it was made (UTC)
@rooms/20261101-201512      the one before it
@home                       /home, shared by every room
@var-log                    /var/log, shared, so a failed room's journal survives
@var-lib-takumi             /var/lib/takumi, shared: room state and the login screen's theme
```

`/` is whichever room was started. The boot partition (ESP) is mounted at
`/efi`, and each room keeps its own kernel in its own `/boot`. Staging a room
copies that room's kernel and initramfs to `/efi/takumi/<room>/` and writes a
systemd-boot entry for it with that room's own kernel options
(`/etc/kernel/cmdline` inside the room). Going back to a room brings back
that room's kernel too.

Room state lives outside the rooms, in `/var/lib/takumi/state/<room>`
(`status=`, `parent=`, `pinned=`, times, and `reason=` for a failure), so a
new room never inherits it. The states are `building`, `staged`, `good`,
`failed` and `left` (you went back from it on purpose).

## What `takumi update` does

```
takumi update                 one at a time (a lock), needs 8 GiB free
  ├─ takumi room snapshot <new>     copy the running room
  ├─ takumi room upgrade <new>      keyrings first, then pacman -Syu inside the new room (chroot),
  │                                 sharing the package cache, then any package Takumi's lists
  │                                 (/usr/share/takumi/packages) name and the room lacks, then the
  │                                 packages nothing needs any more (below); the running room is
  │                                 not touched
  │                                 → keys out of date: renewed (pacman-key --populate, the keyring
  │                                   packages again) and tried once more
  │                                 → on failure the half-built room is deleted, nothing changed, and
  │                                   the Core says why in one sentence (docs/updates.md)
  ├─ takumi room stage <new>        carry over what changed since (Wi-Fi, Bluetooth pairings, passwords,
  │                                 hostname, time zone, printers), copy the room's kernel to the ESP,
  │                                 write its entry, and make it the one to try at the next start, once
  └─ takumi migrate --stage    per-user migrations run at your first login into it
```

At the next start:

1. systemd-boot tries the new room once (`bootctl set-oneshot`).
2. `takumi-room-health.service` waits for the desktop: the shell (or the
   login screen) writes `/run/takumi/desktop-ready` once it has loaded. If
   nobody logs in, there is nothing to judge and the room is accepted.
3. If the desktop came up, `boot-complete.target` is reached and
   `takumi-room-accept.service` marks the room good, makes it the default
   (`bootctl set-default`), and prunes old rooms.
4. If a session started but the desktop never came up, the room is marked
   failed with a reason and the computer restarts. Because the try was a
   one-shot, the next start is the default: the last good room.
5. If the room cannot even start (kernel panic, a hang before login), the
   next power-on is the default again, for the same reason. You never need
   three failed starts to get your system back.

At the next login, `takumi room report` notices the newest room is not the
one running and says so once, in the Core: "Update undone: the desktop did
not start; you are on Sun 8 Nov 09:30, nothing was lost."

## Going back by choice

```
takumi rollback            the newest good room older than this one; asks first, then restarts
takumi room list           every room: when, state, pinned, kernel; "in use" and "next" marked
takumi room use <room>     start a chosen room from now on (also how you come forward again)
takumi room pin <room>     never delete this one
takumi room prune          delete old rooms (keeps the running one, the default, pinned ones,
                           and the newest three good ones); also runs after every good update,
                           and from "Free up space" (docs/updates.md)
takumi room snapshot       save a restore point (below)
```

Your files are in `@home` and never go back with a room.

`takumi rollback` ("Go back to the previous system") starts a restore point
saved in the running room when there is one (the newest), and otherwise the
newest good room older than it (`rooms_previous` in `lib/rooms.sh`).

## Restore points

"Save a restore point" in the Palette (`takumi room snapshot [name]`) copies
the running room as it is now, before you try something you may want to undo.
It asks for a name ("Before trying Docker"); Enter names it by the date. One
password, then "Restore point saved: Before trying Docker".

```
takumi room snapshot ["name"]        a person: asks for a name in the Core, then the line below as root
takumi room snapshot <room> --point ["name"]   root: @rooms/<room> copied from the running room
```

A restore point is a room like any other, with `point=yes`, `parent=` (the
room it was saved in) and `name=` in its state, and `status=good` from the
start: it is a copy of a room that runs. Its boot entry is written only when
it is chosen (`takumi room use`), so it takes nothing on the boot partition
until then. Everything that names a room names it by its name:
`takumi room list` in a column of its own, the boot menu, rollback's question
("Go back to the system from Mon 9 Nov 10:00 (Before trying Docker)?").
A name keeps at most 48 characters and loses `| & \ /` and control characters.

Pruning counts restore points among the good rooms it keeps (the newest three),
so three updates later one is gone; `takumi room pin` keeps it for good.

## Packages nothing needs any more

`pacman -Qdtq` names packages that were installed for another one since
removed. With rooms, `takumi room upgrade` removes them (`pacman -Rns`) in the
new room after the upgrade, so starting the room before it undoes that; the
running room keeps them, and its space comes back when it is pruned. Without
rooms, "Free up space" removes them in place. Either way a package Takumi's
lists name is never removed, even when pacman counts it as unneeded (one first
installed as a dependency stays a dependency). `pacman -Qdtq` with one `-t`
leaves out packages another one lists as optional.

## Changing the running room directly

`pacman -Syu` in the running room still works and does what Arch users
expect. Takumi's pacman hook says once that `takumi update` would have
prepared a room you can undo, and never aborts. A second hook,
`95-takumi-room-kernel.hook`, copies the running room's new kernel to the ESP
after any kernel or initramfs change, so the room keeps starting with its own
kernel.

## Erasing the computer

An erase (`takumi settings erase`) keeps only the running room: each room's
`/etc` holds the accounts, so an older room would bring back accounts whose
homes are gone ([setup.md](setup.md)).

## Installing

A Takumi install creates `@rooms/<first>` directly (see `install/vm/provision.sh`
for the shape). On an existing Arch with Btrfs and systemd-boot, installer step
`80-rooms.sh` converts the running root into the first room: it snapshots it,
points the room's fstab at its own subvolume, moves the boot partition from
`/boot` to `/efi` inside the room, copies the kernel into the room's `/boot`, and
makes the room the default. **The conversion path has not been tried on real
hardware yet.** Any other setup keeps updating in place, and the installer says
so at the end.

## Status

| Part | State |
|---|---|
| Per-room kernels, entries, state outside rooms | written; tested in the QEMU VM (`test/vm`) |
| One-shot tries, health, accept, report | written; tested in the VM, see `docs/vm.md` |
| Carry-over | written; not yet exercised with real Wi-Fi or Bluetooth |
| Restore points, unneeded packages removed in the new room | written; tested with fakes (`test/recovery`), not yet in the VM |
| Converting an existing Arch install | written; untested |
| Encryption with a recovery code | roadmap |
