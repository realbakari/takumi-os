# Vision

Takumi OS exists for one person: someone who has used a Mac or Windows for
years, is tired of it, and wants a desktop that is faster, quieter, more honest
and more modern than either, without having to become a Linux hobbyist first.

Takumi asks what a desktop designed in 2026 should look like if it did not
have to resemble 2006. The answer is seven pillars. Every file in this repo
serves one of them.

## 1. Atomic rooms

A running system is a **room**: a bootable Btrfs subvolume. An update never
edits the room you are in. It copies the room, upgrades the copy, and asks the
bootloader to try the copy once at the next start. If the copy does not reach
the login screen, the computer goes back to the room that worked and says so.
If it boots and you dislike it, `takumi rollback` returns in one reboot.

`pacman -Syu` in the current room is allowed and does exactly what Arch users
expect: it just is not what `takumi update` does. See [atomic-rooms.md](atomic-rooms.md).

## 2. The Strip

Windows live on an endless horizontal strip, one column after another, on
[niri](https://github.com/YaLTeR/niri). Nothing overlaps. Opening a window
does not shrink the one you were reading. You scroll the strip like a page,
and a workspace is just a strip of its own stacked vertically.

The mental model is a desk you slide along, not a grid you partition. Someone
who has never heard the word "tiling" is productive in a minute. See
[the-strip.md](the-strip.md).

## 3. The Core

On top of your windows there is one object, the Core: a capsule of status at
the bottom of the screen. When something happens it widens to say so. Press
`Super+Space` and it grows into the Palette. Type anything: an app, a window
title, a setting ("bluetooth"), a `takumi` command, or a sentence. One list,
ranked, rising from the field. There is no menu bar, dock, launcher, settings
app or notification stack. Everything the OS can do is a row in the Palette,
and every row is backed by a `takumi` command you can read. See
[shell.md](shell.md) and [palette.md](palette.md).

## 4. Harmony

`Super` is the Command key. `Super+C` copies in the browser, the editor and
the terminal. `Super+V` pastes everywhere. `Super+Z`, `A`, `S`, `F`, `W`,
`T`, `N` mean what they meant on your Mac. This is done once, at the keyboard
layer with keyd, so it holds in every app, including the ones that never heard
of us. See [harmony-keys.md](harmony-keys.md).

## 5. Phase themes

A theme is a palette plus four phases. At dawn the accent warms and the
contrast softens, at night the backgrounds sink and the blues drop. The shift
is slow and automatic, and the shell paints the background from it: a disc
that rises, crosses and sets over a shore of monoliths, and a crescent at
night. Fifty-five themes ship, light and dark: Takumi's own, led by **ion**
(electric, the default), and the community palettes people already love, each
given its phases and shown live as you move through them. See
[phase-themes.md](phase-themes.md).

## 6. Intent

The assistant runs on Claude (through Claude Code, with your Claude
account, or an Anthropic key) or on OpenAI, and nothing is sent anywhere
until you choose one. The model never runs a shell. It acts only through
`takumi` commands from the router's manifest, with the risk tier each command
declares: tier 0 runs, anything above it is asked once in the Core before it
runs. Claude Code and other agents reach the same commands through
`takumi mcp serve`, under the same rule. The transcript of what the model asked
for and what you approved is a file you own. See [intent.md](intent.md).

## 7. Craft

The CLI is the API. `takumi <group> <command>` runs
`commands/<group>/<command>`, every command declares its own help, examples,
risk tier and whether it needs root in a few plain lines at its top, and the
Palette and Intent are built from those same lines. If you can see it in the UI you can script it. See
[commands.md](commands.md).

## Non-goals

- Not a general-purpose distro. One compositor, one shell, one terminal, one
  way to update. Choice lives in the apps, not the plumbing.
- Not a rolling experiment. Takumi tracks Arch stable packages and pins the
  handful (niri, quickshell, keyd) whose breaking changes would break us.
- Not a Mac clone. Harmony borrows the key cluster because it is good, not the
  dock, the menu bar, or the window chrome.
- Not cloud-first. Nothing phones home. The assistant talks to the service
  you chose for it, and only when you ask it something.

## Name

匠 (takumi) is the Japanese word for a master craftsman: someone whose tools
are extensions of their hands and whose work looks effortless because every
rough edge was removed before you saw it. That is the bar.
