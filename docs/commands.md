# Commands

Everything Takumi can do is a command, and every command is one file:

```
commands/<group>/<name>      takumi <group> <name>
commands/<group>/main        takumi <group>       (the group itself, as in `takumi update`)
commands/groups.tsv          one line per group: its name, a tab, what it is for
```

`takumi` (and its short name `tk`) is `bin/takumi`, the only thing in `bin/`.
It runs `takumi wifi join "Corner Café"` as `commands/wifi/join "Corner Café"`.
The Palette, Quick settings, Intent, the niri binds, the systemd units and the
commands themselves all call `takumi <group> <name>`, so there is one way in.

## ABOUT

A command says what it is in the lines right under its first line, between
`: <<'ABOUT'` and `ABOUT`. Bash reads that block as a note to itself and
skips it, and the router reads it as the command's card:

```bash
#!/usr/bin/env bash
: <<'ABOUT'
summary: Switch to a theme by name and re-render the current phase
usage: <name>
example: takumi theme set ember
risk: 0
ABOUT
set -euo pipefail
```

One `key: value` per line; the value is the rest of the line, quotes and all
(`example: takumi wifi join "Corner Café"`). The group and the name are the
file's place in `commands/`, so they are never written down twice.

| Key | Required | Meaning |
|---|---|---|
| `summary` | yes | one line, shown in help, the Palette and the Intent manifest |
| `risk` | yes | `0`, `1` or `2`; see [intent.md](intent.md) |
| `usage` | no | the arguments, shown in help and used by Intent to check what it fills in |
| `example` | no, repeatable | shown in help, and given to the model as an example |
| `sudo` | no | `yes` when the command asks for root; help says so |
| `hidden` | no | `yes` keeps it out of help, the Palette and the manifest |
| `alias` | no, repeatable | another `group name` that runs this command |
| `title` | no | the Palette row's label in plain words: `title: Shut down` |
| `words` | no | more words the Palette finds it by: `words: shutdown turn off` |
| `glyph` | no | the row's stroke icon, a name from `shell/Look/Icons.js` |
| `interactive` | no | `yes` when it asks questions or needs a password, so the Palette runs it in a terminal |
| `converse` | no | `yes` when it talks through `lib/core.sh`, so the Palette runs it as a conversation in the Core |

A file without an ABOUT block, a `summary` or a `risk` is not a command, and
`./test/run lint` fails.

## How a word becomes a command

```
takumi                       the groups a person can use
takumi <group>               the commands in a group
takumi <group> <name> -h     help, from the ABOUT block
takumi --manifest            every command that is not hidden, as JSON (the Palette, Intent)
takumi --complete [group]    words for shell completion
```

`takumi <group> <name>` looks for `commands/<group>/<name>`; when the second
word is not a command of the group, `commands/<group>/main` runs with it as an
argument (`takumi install docker`). Either way the router reads no other
command's ABOUT block: running a command costs one look in the folder.
Help, the listings, aliases and the manifest read every block. A group or
a name is only ever lowercase letters, digits and hyphens, so a word never
reaches outside `commands/`.

The router looks for commands in `TAKUMI_COMMANDS`, a list of folders joined
by `:` where the first that has a command wins, then in the `commands/` next
to `bin/takumi` (a checkout), then in `/usr/lib/takumi/commands`. The tests put
a folder of fakes first (`TAKUMI_COMMANDS="$t/commands:$repo/commands"`), so a
command that calls `takumi notice` reaches the fake.

## Installed

```
/usr/bin/takumi                 the router
/usr/bin/tk                     a link to it
/usr/lib/takumi/commands/       every command, and groups.tsv
```

Two commands are also named by path, where only a path will do: sudo's
password helper is `/usr/lib/takumi/commands/approve/askpass`
([approvals.md](approvals.md)), and the setup disc lets its live user run
`/usr/lib/takumi/commands/setup/install` as root and nothing else
([setup.md](setup.md)).

## Groups

| Group | For |
|---|---|
| `update`, `rollback`, `room` | updates into a new room (how many wait, prepared on the charger: [updates.md](updates.md)), going back, the rooms themselves, carrying today's changes into a prepared room, restore points, freeing up space: [atomic-rooms.md](atomic-rooms.md), [updates.md](updates.md) |
| `theme`, `phase` | themes and the time of day, a theme from a picture, the browsers and the prompt in its colours: [phase-themes.md](phase-themes.md), [look.md](look.md) |
| `font`, `about` | the interface and code fonts, more from Arch; this computer's model, memory, disk and graphics: [look.md](look.md) |
| `hardware` | what is in this computer, what works, and the fixes it needs, as data, and Thunderbolt docks waiting for permission: [hardware.md](hardware.md) |
| `clock`, `remind`, `timer`, `weather` | the time zone and other cities, reminders, timers and the weather in Today: [time.md](time.md) |
| `firewall`, `vpn` | the firewall and which apps others may reach; VPNs and Tailscale: [firewall.md](firewall.md), [vpn.md](vpn.md) |
| `printer`, `scan`, `drive` | printers, scanning into Documents, USB drives and cards, writing disk images, disk health, OneDrive, Google Drive and Dropbox as folders: [printing.md](printing.md), [drives.md](drives.md) |
| `backup`, `phone`, `share` | hourly encrypted backups, your phone through KDE Connect, sending nearby through LocalSend, making photos and videos smaller to send: [backup.md](backup.md), [sharing.md](sharing.md) |
| `dev`, `agent` | languages, containers, Git and GitHub; coding agents in a terminal: [development.md](development.md) |
| `switch` | Bluetooth, Wi-Fi, night light, do not disturb, the touchpad, the screen reader, pointer size, sticky keys, high contrast, zoom, animations ([accessibility.md](accessibility.md)); `state` (hidden) is what Quick settings shows |
| `wifi` | list, join, forget, share, sign in: [wifi.md](wifi.md) |
| `bluetooth` | connect, disconnect, pair, forget (hidden: reached through the Palette's rows): [bluetooth.md](bluetooth.md) |
| `audio` | output, input, volume, an app's volume, the microphone, which player the media keys control, quality, speaker tuning: [sound.md](sound.md) |
| `display` | brightness, size, turn, arrange (beside, above, below), the laptop screen off, mode, night light, text size: [display.md](display.md) |
| `power` | shut down, restart, sleep, hibernate, the lid, the battery's charge limit, log out, profiles, idle times, staying awake: [power.md](power.md), [laptop-keys.md](laptop-keys.md) |
| `screen` | screenshot, mark up, recording with sound, microphone and camera, colour, text, codes, remote help: [capture.md](capture.md) |
| `voice` | dictation on this computer: [dictation.md](dictation.md) |
| `clipboard` | the history's keep, paste, type and clear: [palette.md](palette.md) |
| `palette` | the Palette's providers: [palette.md](palette.md) |
| `app` | apps: get from Flathub (the Shelf), remove, the default for each kind, web apps, Windows programs, apps that open at login, force quit or restart an app, close all windows: [apps.md](apps.md), [harmony-keys.md](harmony-keys.md) |
| `install` | optional software: Windows in a box, Steam and games ([gaming.md](gaming.md)), coding agents |
| `keys` | Harmony on or off, keyboard layouts and input methods, the keyboard light, the pointer, touchpad and key repeat, the top row, Alt and Super swapped: [harmony-keys.md](harmony-keys.md), [laptop-keys.md](laptop-keys.md) |
| `language` | the language apps speak, and how dates and numbers are written: [languages.md](languages.md) |
| `password` | your password, for logging in, the Lock and the encrypted disk at once: [security.md](security.md) |
| `security` | unlocking with your finger, Secure Boot with this computer's own keys; `finger-ready` (hidden) guards the finger for sudo: [security.md](security.md) |
| `intent` | the assistant on Claude or OpenAI: [intent.md](intent.md) |
| `doctor` | check the computer and fix what is safe, restart Wi-Fi, Bluetooth, sound or the desktop, test the internet's speed: [doctor.md](doctor.md) |
| `firmware` | firmware through fwupd: [firmware.md](firmware.md) |
| `settings` | `reset`: Takumi's settings back, all or one app's, keeping what you chose; `erase`: erase this computer and start like new ([setup.md](setup.md)) |
| `migrate` | bring this home up to date: [migrations.md](migrations.md) |
| `lock`, `debug`, `version` | lock the screen, collect a report, why an app quit ([notifications.md](notifications.md)), print the version |
| `disk` | a new recovery code for the encrypted disk, opening it with the security chip: [encryption.md](encryption.md), [security.md](security.md) |
| `approve`, `greeter`, `mcp`, `notice`, `session`, `setup`, `vm` | hidden: the password helper, the login screen, Takumi's commands as MCP tools for Claude Code ([intent.md](intent.md)), notices in the Core, the session, the setup disc ([setup.md](setup.md)), the VM's screen |

## A new command

1. Pick the group (or a new one, with its line in `commands/groups.tsv`).
2. Write `commands/<group>/<name>`: the ABOUT block, then `set -euo pipefail`.
   Call other commands as `takumi <group> <name>`; find Takumi's files under
   `/usr/share/takumi`, then beside the checkout (`"$here/../../themes"`).
3. `chmod +x` it and run `./test/run lint router`.
