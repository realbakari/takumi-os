# The Strip

Takumi's desktop runs on [niri](https://github.com/YaLTeR/niri), a scrolling
Wayland compositor written in Rust. We call its layout the Strip.

## The model

- Each monitor shows a **strip**: an endless horizontal row of columns.
- A column holds one window, or several stacked vertically.
- New windows open to the right of the focused one at a default width
  (half the screen). Nothing else moves. Nothing overlaps.
- You scroll the strip with `Super+Left/Right`, a three-finger swipe, or
  `Super+scroll`. The focused column is always fully on screen.
- Workspaces are strips stacked vertically. `Super+Up/Down` on the edge of a
  column moves between them. `Super+1..9` jumps.
- `Super+O` opens the Overview: every workspace, every column, zoomed out.
- The Core, the status capsule, floats at the bottom centre, shows the strip
  as a minimap, and slides away when a column fills the strip. See
  [shell.md](shell.md).

What you never do: choose a split direction, resize a neighbour by accident,
or lose a window behind another.

## Column widths

`Super+R` cycles a column through a third, a half, two thirds. `Super+M`
maximizes it to the full strip width. `Super+Shift+M` goes truly fullscreen.
`Super+Ctrl+C` centres the column and shows its neighbours as peeks.

## Configuration

niri reads `~/.config/niri/config.kdl`. Takumi ships it as three includes:

```
config.kdl                 the seed; includes the two below and nothing else
takumi/defaults.kdl        Takumi's input, layout, animations, rules and binds
takumi/overrides.kdl       yours. Empty on a fresh install. Never overwritten.
```

`takumi settings reset` replaces `config.kdl` and `takumi/defaults.kdl` and
leaves `overrides.kdl` alone. A later block in KDL wins, and `overrides.kdl`
is included last, so any bind or rule you repeat there is yours.

Input in `defaults.kdl`: keys repeat after 280 ms, 40 a second, with Num Lock
on; a touchpad taps to click, scrolls the way the content moves (as on a Mac
or a Windows laptop), ignores the palm while you type, presses with two
fingers for the right button and three for the middle (`clickfinger`), and
scrolls at half libinput's speed; a mouse moves without acceleration. The
keyboard layout is not set there: niri takes the system's from systemd-localed
(`localectl set-x11-keymap`, which the installer sets), and the login screen
reads the same from `/etc/vconsole.conf`, putting US English first when the
layout cannot type Latin letters (Left Alt + Right Alt switches).

Theme colours (focus ring, borders, shadow) are not in either file. They come
from `~/.local/state/takumi/look/niri-theme.kdl`, rendered by the theme
system, and included from `defaults.kdl`. See
[phase-themes.md](phase-themes.md).

## Why a scrolling compositor

Tiling compositors are powerful and ask you to learn a layout language first.
Takumi wanted a desktop whose model a Mac user understands in one sentence,
and "windows sit on a strip you scroll" is that sentence. niri also ships a
built-in overview, is written in Rust, has a stable KDL config with
`include`, and exposes a JSON IPC (`niri msg --json`) the shell and the
Palette use for window search and focus.

## Bindings cheat sheet

Full list in `config/niri/takumi/defaults.kdl`; this is the shape.

| Keys | Does |
|---|---|
| `Super+Space` | The Core opens into the Palette |
| `Super+I` | The Core opens into Quick settings |
| `Super+Return` | Terminal |
| `Super+Alt+Escape` | Force quit an app ([harmony-keys.md](harmony-keys.md)) |
| `Super+Alt+=` / `-` / `0` | Zoom in, out, off ([accessibility.md](accessibility.md)) |
| `Super+Q` | Close window |
| `Super+Left/Right` | Focus column left/right |
| `Super+Up/Down` | Focus window in column, then workspace |
| `Super+Shift+Arrows` | Move column / window |
| `Super+R` | Cycle column width |
| `Super+M` | Maximize column |
| `Super+O` | Overview |
| `Super+1..9` | Workspace |
| `Super+Tab` | Previous window (any workspace) |
| `Super+Shift+S` | Screenshot a region |
| `Super+L` | Lock |

Note that `Super+C`, `V`, `X`, `Z`, `A`, `S`, `F`, `W`, `T`, `N` are
deliberately *not* compositor bindings. Harmony owns them. See
[harmony-keys.md](harmony-keys.md).
