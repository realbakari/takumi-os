# Accessibility

Six switches, each a row in the Palette and a command: the screen reader, a
bigger pointer, sticky keys, high contrast, zoom and animations. Typing
"accessibility" lists all six, and `Super+U`, the key Windows opens these settings with, opens the
Core on them. Every part of the Core has an accessible name and role
([shell.md](shell.md)), and a screen reader hears each new notice
([notifications.md](notifications.md)).

| Row | Command | Does |
|---|---|---|
| Screen reader | `takumi switch reader [on\|off]` | Orca speaks what is on the screen |
| Pointer size | `takumi switch pointer [bigger\|normal]` | the pointer at 48 pixels instead of 24, everywhere |
| Sticky keys | `takumi switch sticky [on\|off]` | tap Shift, Ctrl, Alt or Super, then the key |
| High contrast | `takumi switch contrast [on\|off]` | Kuro or Shiro, and back to your theme |
| Zoom | `takumi switch zoom [on\|off\|closer\|farther]` | a magnified strip along the top of the screen |
| Animations | `takumi switch motion [on\|off]` | windows, workspaces and the Core appear and move at once |

Each switches over when run alone, and takes on or off from a script.

## The screen reader

`Super+Ctrl+Enter` turns it on or off, the key Windows uses for its own, and
so does `Super+F5`, the Mac's. Both work at the lock screen. Orca reads apps
and the Core through AT-SPI and speaks through speech-dispatcher with
espeak-ng's voices; when it stops, speech-dispatcher says "Screen reader off".

On, Orca starts at once and at every login after: niri starts it from
`~/.config/niri/takumi/accessibility.kdl`. Apps are told a screen reader is on
(`org.gnome.desktop.a11y.applications screen-reader-enabled`). niri itself
shows its parts to Orca and lets Orca take its keys, in a session started by
`niri-session`, which is how Takumi starts it, on a computer with a GPU
([niri's notes](https://niri-wm.github.io/niri/Accessibility.html)).

## A bigger pointer

`takumi switch pointer bigger` sets one size everywhere: niri's own pointer
(the `cursor` line in `accessibility.kdl`, which also gives `XCURSOR_SIZE` to
what niri starts), GTK apps (`org.gnome.desktop.interface cursor-size`), and
everything started with the next login (`XCURSOR_SIZE` in
`~/.config/environment.d/60-takumi-pointer.conf`; services started now get it
from `systemctl --user set-environment`). Apps that let niri draw their
pointer change at once; the few that draw their own change when they next
open. `normal` takes all of it back.

## Sticky keys

Tap a modifier, let go, then press the key: Shift, then A, types a capital A;
Super, then C, copies. Tap it twice and it stays down until you tap it again.
Holding works as always.

keyd does it, the daemon that already makes Super the Command key
([harmony-keys.md](harmony-keys.md)). niri has no such setting, while keyd
sits below every app, the login screen and the lock, and its
[oneshot and toggle actions](https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc)
are exactly this. The switch writes a marked block into
`/etc/keyd/default.conf`: each modifier becomes `oneshot`, a second tap
`toggle`s it, and Super keeps Harmony's layer. Off removes the block and gives
Harmony's file back as it was. With Harmony off, the file holds sticky keys
alone and going off removes it.

That file is the system's, so the Core asks for your password. A sudoers rule
can let this one command's root part run without it:

```
%wheel ALL=(root) NOPASSWD: /usr/lib/takumi/commands/switch/sticky --system on, /usr/lib/takumi/commands/switch/sticky --system off
```

The root part takes only `on` or `off`, reads nothing of yours, writes only
that file and asks keyd to read it again.

## High contrast

`takumi switch contrast` moves to Kuro (white on black) after a dark theme or
Shiro (black on white) after a light one, and apps built on GTK 4 and
libadwaita take their own high-contrast look
(`org.gnome.desktop.a11y.interface high-contrast`). The theme you had waits in
`~/.local/state/takumi/contrast` and comes back when you turn it off, or Ion
when that theme is gone. Choosing another theme while it is on ends it.

## Zoom

`takumi switch zoom`, or **Zoom** in the Palette, docks a strip along the top
of the screen, a third of its height, showing the screen below it larger: two
times to start. It follows the window you are in: its middle comes into view
when you go to another window. niri says where a floating window is but not a
tiled one, so for those the shell works it out from the window's column in
the strip (the widths, the gap, and niri bringing the focused column to the
middle when the columns do not fit); a strip you scrolled by hand can put it
a little off, and the arrows below move it. The keys:

| Keys | Does |
|---|---|
| `Super+Alt+=` | closer: 1.5, 2, 3, 4, 6, 8 times; on when off |
| `Super+Alt+-` | farther; off past 1.5 |
| `Super+Alt+0` | off |
| `Super+Alt+arrows` | moves what it shows, a quarter at a time |

niri has no zoom of its own (its
[accessibility notes](https://github.com/YaLTeR/niri/wiki/Accessibility)
point to separate tools), so the shell draws one, `shell/Core/Zoom.qml`: a
layer surface showing the screen's own picture live through Quickshell's
`ScreencopyView` (niri's wlr-screencopy), the pointer drawn in it. It is docked
rather than over the whole screen for three reasons. A surface that shows the
screen over the screen shows itself, smaller and smaller; the strip shows only
the screen below it. niri tells no program where the pointer is, so a
full-screen zoom could not keep what you point at under the pointer, and
clicks would land somewhere other than where you see them; the strip takes no
input at all and reserves its band like a panel, so windows move down under
it and are clicked where they are. It follows keyboard focus instead of the
pointer for the same reason. The shell answers `qs -c takumi ipc call zoom
toggle | start | hide | closer | farther | pan <left|right|up|down> | state`,
each with "on <level>" or "off".

## Animations

`takumi switch motion`, or **Animations** in the Palette, turns motion off
in both places it lives: niri's (windows opening and closing, workspaces and
columns sliding), through `~/.config/niri/takumi/motion.kdl` holding
`animations { off; }`, which `defaults.kdl` includes after its own animations,
and the shell's, through `reduce_motion = true` in `~/.config/takumi/shell.toml`
([shell.md](shell.md), "Motion"). On again removes the file and writes
`reduce_motion = false`; your other settings in `shell.toml` stay.

## The file niri reads

```
~/.config/niri/takumi/accessibility.kdl
  cursor { xcursor-size 48; }     takumi switch pointer bigger
  spawn-at-startup "orca"         takumi switch reader on
```

Takumi's `defaults.kdl` includes it with `include optional=true` (niri 26.04),
so a home without it is fine. Each command rewrites only its own line, and
`overrides.kdl`, read last, still wins.

## Exit codes

| Command | 0 | 2 | 3 | 4 |
|---|---|---|---|---|
| `takumi switch reader` | done | a word other than on or off | Orca is not installed | |
| `takumi switch pointer` | done | a word other than bigger or normal | | |
| `takumi switch sticky` | done | a word other than on or off | no password | keyd is not installed |
| `takumi switch contrast` | done | a word other than on or off | | |
| `takumi switch zoom` | done | a word other than on, off, closer or farther | the shell is not running | |
| `takumi switch motion` | done | a word other than on or off | | |

## Not yet

- Zoom over the whole screen, following the pointer: it needs niri's own zoom
  (proposed for niri, not in it yet).
- Slow keys and bounce keys.
- The rows do not say whether a switch is on; they turn it over.
- Turning Harmony on or off (`takumi keys harmony`) replaces keyd's file and
  turns sticky keys off with it; turn them on again after.
- Sticky keys and Alt and Super swapped (`takumi keys harmony swap`) are not
  made to work together: with both on, the left Alt, which is then the Command
  key, is not sticky.
- In the VM, niri runs on its own without a GPU, so Orca speaks for apps but
  niri announces nothing and cannot hand Orca its keys there.

## Testing

`test/a11y` runs anywhere, against fakes of Orca, speech-dispatcher,
gsettings, systemd, sudo and keyd that record their arguments: each switch on
and off and back, the lines in `accessibility.kdl`, sticky keys on Harmony's
real file (on twice is the same, off gives it back byte for byte, with and
without a password, with Harmony off), high contrast after dark and light
themes, the Palette's rows under "accessibility", the keys in
`defaults.kdl`, zoom against a fake shell (each call, the level, no shell),
the strip's settings that keep it from taking input or showing itself, and
animations off and on in both files.
