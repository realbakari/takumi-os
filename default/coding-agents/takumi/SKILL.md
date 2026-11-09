---
name: takumi
description: Change this Takumi OS computer the way it expects, through takumi commands: settings, Wi-Fi, Bluetooth, sound, displays, themes, apps, updates, rooms and rollback. Use when the person asks to change, fix, install or set up something on this machine itself, not in a project's code.
---

# Working on a Takumi OS computer

This computer runs Takumi OS. Every everyday change has a `takumi` command, and those commands are
how the Palette, the assistant and scripts change the system too. Use them instead of editing system
files or calling the tools underneath (nmcli, bluetoothctl, pacman, systemctl).

## Find the command

- `takumi --manifest` prints every command as JSON: group, name, summary, usage, risk, sudo.
- `takumi --help` lists the groups; `takumi <group> <name> --help` shows one command.
- `takumi <group>` runs the group's main command, for example `takumi update` or `takumi doctor`.

## Ask before changing

Each command carries a risk. 0 is safe to run (it reads, or changes something undone at once). 1
changes a setting or installs something. 2 replaces the system or deletes. Before running a risk 1 or 2
command, tell the person what it will do and wait for a yes.

## Rules

- Do not run sudo for something a takumi command does. Commands that need root ask for the password
  in the Core, where the person sees what it is for.
- Do not edit /etc, /usr or ~/.config/takumi by hand. `takumi settings reset` puts settings back.
- The system lives in rooms (Btrfs snapshots). `takumi room list` shows them; `takumi rollback` goes
  back to the room before the last update or change.
- Keys and window rules the person adds go in ~/.config/niri/takumi/overrides.kdl; the other files in
  that folder belong to Takumi and are replaced on update.
- Themes are data (`theme.toml`, never code): `takumi theme list`, `takumi theme set <name>`.
- Another agent or tool can get the same commands as tools from Takumi's MCP server:
  `takumi mcp serve` over stdio. Risk 0 runs; risk 1 and 2 are asked in the Core.
- Say in plain words what you changed, the way the command itself does.
