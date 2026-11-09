# Power

Power lives in the Core. Type "power" (or "battery", "lid", "hibernate",
"awake", "lock", "sleep") and the Palette lists the mode, the battery,
staying awake, when the computer locks and sleeps, what closing the lid
does, and hibernation. Shut down, restart, sleep and log out are rows of
their own.

## What you see

- The battery, on a laptop: "Battery 83% · On battery · 2 h 10 min left",
  "Charging", or "Full, plugged in". A battery held at 80% says "Charging
  to 80%", then "Plugged in · kept at 80% so it lasts".
- The modes this computer offers: "Power saver" (longer battery, a little
  slower), "Balanced", "Performance" (fastest, louder and warmer). The one
  in use says so.
- "Stay awake for an hour": no lock and no sleep, for a film or a
  presentation. Then the row reads "Awake until 14:30 · Enter to stop".
- "Lock the screen after 10 min" and "Sleep after 30 min", for the power
  source you are on now. Enter asks for the minutes in place; 0 means never.
- On a laptop, what closing the lid does: "Sleep when the lid closes", the
  first choice, "Keep running when the lid closes", which locks the screen
  while music and downloads go on, and, once hibernation is on, "Hibernate
  when the lid closes".
- "Turn on hibernation · uses 16 GB", on a computer that can hibernate. Once
  it is on: "Hibernate", "Sleep, then hibernate after 2 hours" and "Turn off
  hibernation". Asked about hibernation, a computer that cannot hibernate
  says why.
- "Keep the battery at 80%", on a laptop that can hold its battery below
  full. Then the row reads "Battery kept at 80% · Enter to charge to 100%".

Changing the lid, sleep, hibernation or the charge limit changes the
computer for everyone who uses it, so the Core asks for your password first.

## On battery and on power

A laptop keeps two of everything: a mode and lock and sleep times for when
it runs on battery, and another set for when it is plugged in. Choosing a
mode or minutes changes the set for the source you are on now, and the
notice says which ("Power saver · used on battery from now on"). Plug in or
unplug and the computer switches sets by itself within two minutes.

The first sets are: power saver, lock after 10 minutes and sleep after 30 on
battery; balanced, lock after 20 minutes and never sleep when plugged in. A
minute after the screen locks, the screens turn off. The screen also locks
just before the computer sleeps, however it goes to sleep.

The lid works the same way with one difference: a choice made on battery
holds when plugged in too, unless plugged in has a choice of its own, and a
choice made while plugged in holds only then. With a second screen
connected, closing the lid never sleeps the computer, whatever the choice.

## Hibernation

Sleep keeps your work in memory, which needs a trickle of power: a laptop
asleep in a bag is empty after a day or two. Hibernation keeps the memory on
the disk and turns the computer off. At the next start everything comes back
as it was, behind the locked screen.

"Turn on hibernation" makes a file as big as the memory, 16 GB on a
computer with 16 GB. It needs that much free space and 8 GB more for
updates, and says so in numbers when the disk is too full. On an encrypted
disk the file is encrypted with everything else: the start asks for your
password, then wakes.

"Sleep, then hibernate after 2 hours" applies to every way of sleeping: the
lid, the minutes after no use, and the Sleep row. Once the computer has
slept that long it hibernates. If hibernation ever stops working, that
sleep stays plain sleep.

"Turn off hibernation" gives the space back, and the lid and sleep choices
that used hibernation go back to sleep.

Hibernation is refused, with the reason, on a computer without Takumi's
disk layout, on a system that Secure Boot has locked down, when the start
options turn hibernation off, and when the computer starts with an initramfs
that cannot wake from it.

## Hibernation and updates

An update prepares a new system and sets the next start to try it once
([atomic-rooms.md](atomic-rooms.md)). Waking from hibernation is a start
too, and the new system cannot wake what the old one kept in memory. So just
before the computer hibernates, the next start is pointed at the system in
use whenever it would be another one: the update waiting for a restart, or
the usual system when you started an older one by hand. After waking, what
was set before is put back, and the update is tried at the next restart as
planned.

An update prepared before the current start has had its one try already,
even when it never got far enough to say so, and it is not tried again.
Plain sleep changes nothing: if the battery runs out while the computer is
asleep, the next start is a fresh one, and trying the update then is right.

This is `/usr/lib/systemd/system-sleep/takumi-rooms`, which systemd-sleep
runs as root before and after each sleep. It acts on hibernation, hybrid
sleep, and the hibernating part of suspend-then-hibernate
(`SYSTEMD_SLEEP_ACTION`). Before, it sets systemd-boot's one-shot entry to
the running room (`bootctl set-oneshot`) and keeps what it displaced in
`/run/takumi/hibernating`, which survives hibernation with the rest of
memory. After, it sets the one-shot back to the room an update staged during
this start, or removes it. A staged room counts as waiting when its
`staged=` time in `/var/lib/takumi/state` is later than the start of this
boot.

## The battery

Below 15% the Core says "Battery low · 14% left". Below 5% it says "Plug in
now · the computer sleeps at 3%", and at 3% it sleeps, so nothing is lost.
With hibernation on it hibernates instead, which keeps your work even if the
battery runs out completely. Each warning shows once each time the battery
falls below its level.

"Keep the battery at 80%" stops charging at 80% and, where the laptop can
say so, starts again only below 75%. A battery that sits full on a charger
wears out sooner, so this is for a laptop that is mostly plugged in.

## Commands

```
takumi power profile <power-saver|balanced|performance>
takumi power awake <minutes|stop>
takumi power when <lock|sleep> [minutes] [battery|power]
takumi power lid <sleep|hibernate|nothing> [on-charger]
takumi power hibernate <on|off|now>
takumi power hibernate-after <hours|never>
takumi power charge-limit <80|100>
takumi power off | restart | sleep | logout
```

`off`, `restart` and `logout` ask every open window to close first, as its own
close button does (`power_close_apps` in `lib/power.sh`), and wait up to 8
seconds. An app with unsaved work answers in its own window ("Save changes?"):
then nothing goes off. That window comes to the front, the Core says "Text
Editor still open · Save or close it, then shut down again", and the command
exits 3. Run it again once you have answered.

`takumi power when` without minutes asks for them, in the Core or at a
terminal. `lid` without `on-charger` sets the choice for battery, which
plugged in follows unless it has its own. `lid`, `hibernate on` and `off`,
`hibernate-after` and `charge-limit` are conversations: in the Core they ask
for the password there, at a terminal sudo asks. For scripts, their exit
status says what happened and their last line says it in words:

| Exit | Means |
|---|---|
| 0 | done, or it already was so |
| 1 | not possible on this computer, or a step failed; turning hibernation on puts back what it had changed |
| 2 | the arguments were wrong |
| 3 | the password was not given; nothing changed (`off`, `restart`, `logout`: an app stayed open) |
| 4 | `hibernate on`: not enough free space |
| 5 | hibernation is off (`lid hibernate`, `hibernate-after`, `hibernate now`), or the laptop cannot hold its battery below full (`charge-limit`) |

## How it works

The modes are power-profiles-daemon's (`powerprofilesctl`). The battery is
read from `/sys/class/power_supply`. Your choices live in
`~/.config/takumi/power.toml`, written whole. `takumi-idle.service` runs
`swayidle` with the lock, screens-off and sleep times for the current power
source; it is restarted whenever the source or the minutes change. It also
puts the keyboard light back after waking ([laptop-keys.md](laptop-keys.md))
and locks the screen when logind asks. `takumi-battery.timer` runs
`takumi power battery` every two minutes for the warnings and the switch
between sets. Staying awake is one background job: it stops the idle watcher
and holds a sleep inhibitor (`systemd-inhibit`) for the time, then puts the
watcher back.

What closing the lid does is Takumi's logind drop-in,
`/etc/systemd/logind.conf.d/takumi-lid.conf`, written whole:
`HandleLidSwitch` for battery, `HandleLidSwitchExternalPower` when plugged in
has a choice of its own, and `SleepOperation`. "Sleep" is logind's `sleep`
action, which does what `SleepOperation` says: `suspend`, or
`suspend-then-hibernate suspend` when sleep turns into hibernation, so it
falls back to suspend when hibernation cannot happen. "Keep running" is
`lock`. logind reads the file again when sent `SIGHUP`
([logind.conf](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html)).
The hours before hibernating are `HibernateDelaySec` in
`/etc/systemd/sleep.conf.d/takumi.conf`
([systemd-sleep.conf](https://www.freedesktop.org/software/systemd/man/latest/systemd-sleep.conf.html)).
Once `takumi-lid.conf` exists, the idle watcher and the Sleep row ask for
`systemctl sleep`, the same sleep as the lid's; before that, `systemctl
suspend`.

Hibernation's file is `/swap/swapfile`, made by `btrfs filesystem
mkswapfile` in a Btrfs subvolume of its own, `@swap`, beside `@rooms` and
`@home` ([Btrfs: swapfile](https://btrfs.readthedocs.io/en/latest/Swapfile.html)).
It cannot live in a room: a subvolume that holds a swapfile in use cannot be
snapshotted, and every update snapshots the room. `/etc/fstab` mounts the
subvolume at `/swap` and turns the file on at every start, both with
`nofail`, so a missing file never stops a start. zram stays first for
everyday swapping. `resume=UUID=` (the Btrfs volume) and `resume_offset=`
(from `btrfs inspect-internal map-swapfile -r`) go into
`/etc/kernel/cmdline`, which every room's boot entry copies, and `takumi room
kernel-sync` rewrites the running room's entry at once. The systemd
initramfs wakes from the file by itself, after it has opened an encrypted
disk. Turning hibernation on runs as root in one step, through `core_sudo`,
and puts back everything it changed when any part fails.

The charge limit is the kernel's `charge_control_end_threshold`, and
`charge_control_start_threshold` where the battery has one
([sysfs-class-power](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-power)).
The choice is kept in `/var/lib/takumi/charge-limit`, which every room
shares, with each start threshold as it was so 100% puts it back.
`takumi-charge-limit.service` sets the limit again at each start and after
waking, because some laptops forget it; `takumi power charge-limit` turns
the service on, and without the file it does nothing.

## Not yet

- Systems kept from before hibernation was turned on start without it, and
  turning it off in one system leaves the others' start options as they
  were; they start normally either way.
- A charge limit other than 80%, and showing it in Quick settings.
- Hiding sleep on a computer whose sleep is broken.

## Testing

`test/power` runs on any machine with a fake battery, fake power profiles,
a fake systemd and a fake computer's `/etc`, `/proc` and `/sys` under one
folder, with fake disk tools and a fake sudo: the battery line, a mode kept
per power source, minutes as a conversation, the `swayidle` command for each
source, each warning once, the switch when plugged in or out, staying
awake, the lid on battery and plugged in, hibernation turned on and off with
every file it touches, refused with each reason and put back when a step
fails, sleep then hibernate, the charge limit set, kept and undone, and
the sleep hook: the next start pointed at the system in use before
hibernating with an update waiting, the update put back after waking, and
an update that already had its try left alone. The VM has no battery:
`TAKUMI_POWER_SUPPLY` points the commands at a folder that pretends to be
one.
