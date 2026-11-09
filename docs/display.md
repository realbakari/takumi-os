# Displays

Screens, text size and the night light live in the Core. Type "display"
(or "screen", "bigger", "text", "resolution", "refresh", "night light",
"brightness") and the Palette lists what you can change.

## What you see

- "Make everything bigger (125%)" and "Make everything smaller (100%)": the
  whole screen, windows and the Core together. The steps are 100, 125, 150,
  175, 200, 250 and 300%; the top ones are for a laptop's sharp panel and for
  4K screens.
- "Smoother motion: 165 Hz", when the screen can draw faster than it does
  now, and "Back to its full resolution (2560 × 1600)" when it is not showing
  its own size. Type "resolution" or "refresh" for every size and rate it can
  show.
- "Turn the screen": a quarter turn, for a monitor stood on its side.
- With a second screen: "DELL U2720Q on the right", "on the left",
  "DELL U2720Q above" and "below": where it stands on your desk, so the
  pointer crosses at the right edge. Above and below line up the left edges.
- With a monitor plugged into a laptop: "Use only the external screen" turns
  the laptop's own screen off, for a laptop on a stand with its lid open;
  "Use the laptop screen again" turns it back on. Unplugging the monitor
  turns the laptop screen on by itself, with a notice, so you are never left
  with no screen.
- "Text bigger (15)" and "Text smaller (11)": just the text, in the Core and
  in your apps. The sizes are 11, 13, 15, 17 and 20; 13 is where you start.
- "Night light on", "Night light off", and "Night light from 17:30 to 05:30",
  which follows the same clock as the sky.
- "Brightness 25%" to "100%", on a computer with a built-in screen or an
  external monitor that takes brightness over DDC/CI (most do), and "A
  little brighter" and "A little dimmer", one point at a time. The
  brightness keys work on external monitors too; with Alt they step one
  point instead of five.

With two screens each row says which screen it is about.

## A change that goes back by itself

A screen that comes out wrong can leave you unable to read the button that
puts it right. So every change to a screen's size, resolution, refresh rate,
turn or place, and turning the laptop screen off or on, shows at once, and the Core asks "Keep this? · Goes back in 10 s", counting down.
Enter keeps it. Esc, or doing nothing, puts the screen back the way it was.

Text size and the night light change at once with a notice, because you can
always read your way back.

## Commands

```
takumi display scale <bigger|smaller|percent> [screen]
takumi display mode <native|smoother|WxH|WxH@Hz> [screen]
takumi display rotate [screen]
takumi display arrange <right|left|above|below> [screen]
takumi display builtin <off|on|status>
takumi display text <bigger|smaller|11|13|15|17|20>
takumi display nightlight <on|off|schedule>
takumi display brightness <0-100|up|down> [--fine]
takumi switch nightlight
```

`scale`, `mode`, `rotate`, `arrange` and `builtin` exit 0 when you keep the
change, 3 when it went back, and 1 when niri would not make it (or, for `mode`,
when the screen cannot show that size). `builtin off` exits 4 when no other
screen is on, and `builtin` 5 on a computer without a built-in screen;
`builtin status` prints `on`, `off` or `none`.

## How it works

niri reports the screens (`niri msg --json outputs`) and changes them for
the moment (`niri msg output <name> scale|transform|position`). A change you
keep is written, for every screen that is on, to
`~/.config/niri/takumi/outputs.kdl`, which the niri config includes, so niri
starts the same way next time. Nothing else writes that file, and
`takumi settings reset` keeps it.

A monitor is kept under its make, model and serial (`output "Dell Inc. DELL
U2720Q 7XK2P93"`), which niri matches as well as a port
([niri: outputs](https://github.com/YaLTeR/niri/wiki/Configuration:-Outputs)),
so its scale and place follow it to any port or dock, and the next monitor
on that port does not inherit them. The built-in screen, a monitor that does
not say what it is, and two monitors that say the same are kept under their
port. What was kept for a monitor that is not plugged in stays in the file,
word for word, until it is back. niri turns the built-in screen off by itself
when the lid closes.

The laptop screen off by hand is `niri msg output eDP-1 off` (the built-in
screen is the output named `eDP`, `LVDS` or `DSI`), refused unless another
screen is on, and never written to `outputs.kdl`: a computer started without
the monitor must not start with no screen. Kept off, a guard (`takumi display
builtin --guard`, its pid and the port in `$XDG_RUNTIME_DIR/builtin-off`)
looks every two seconds: when the last other screen is gone it turns the
laptop screen on and says so, and when a config reload turned it back on
(niri forgets `niri msg output` changes then) it turns it off again. Logging
out ends the guard, so the next session starts with the laptop screen on.
"Use the laptop screen again" is not offered while the lid is closed.

Above and below place the second screen with its left edge on the first's
(`position x=<first x> y=<first y minus its height>`), as niri's logical
coordinates, after scale.

Fine brightness steps are `brightnessctl set 1%+` and `ddcutil setvcp 10 +
1`, against five for the plain keys.

A resolution or refresh rate is niri's `mode`, from the modes the screen
reports (`niri msg --json outputs`); it is written to `outputs.kdl` only when
it is not the screen's own, so a better mode a new cable brings is taken.

External monitors' brightness goes over DDC/CI with `ddcutil` (the `i2c-dev`
module, loaded by `etc/modules-load.d/takumi-ddc.conf`). It takes a moment
per monitor, so the monitors found are kept for ten minutes in
`$XDG_RUNTIME_DIR/ddc`, the Palette never waits for them, and a held
brightness key never piles changes up. With a built-in screen the monitors
follow it; without one, the notice shows the monitor's own value.

Text size is the Core's `font_size` in `~/.config/takumi/shell.toml`, which
the shell watches, and the apps' `text-scaling-factor` in GNOME's settings,
which GTK and most apps follow. The night light is one `wlsunset`, known by
its pid file in `$XDG_RUNTIME_DIR`; "on" keeps it warm all day. Your choice
of text size and night light is kept in `~/.config/takumi/display.toml`, and
the night light comes back at login.

## Not yet

- Arranging screens by dragging them: the rows put the second screen beside,
  above or below the first, not at any place in between, and a third screen
  is placed with `takumi display arrange <side> <screen>`.
- Keeping the laptop screen off from one login to the next.

## Testing

`test/display` runs on any machine with a fake niri that keeps the screens'
state: the keep-or-go-back conversation answered yes, no and with silence,
what is written for next time, text size, the night light, arranging above
and below, the laptop screen off and the guard that brings it back, and fine
brightness steps. In the VM,
niri runs nested with one output, `winit`, whose scale can change; see
[vm.md](vm.md).

## Mirroring

For a talk, a class or a film on the television, the other screen can show
exactly what the built-in screen shows. With two screens on, the Palette has
"Show this screen on the projector" (type "projector", "mirror" or
"present"); Enter starts it, and the Core says "Mirroring the built-in screen ·
it shows on DELL U2720Q too". The same row then reads "Stop showing this
screen on the projector". Unplugging the projector ends it by itself, with a
notice.

```
takumi display mirror <on|off|toggle|status>
```

`status` prints `on <source> <targets…>` or `off`. Without a built-in screen
(a desktop with two monitors), the first screen is the one shown.

niri gives every screen its own space and does not mirror one onto another, so
[wl-mirror](https://github.com/Ferdi265/wl-mirror) draws a live copy of the
built-in screen, full screen on each other screen (`wl-mirror
--fullscreen-output DP-1 eDP-1`), with the pointer. A window rule in
`config/niri/takumi/defaults.kdl` keeps the copy square and from taking the
keyboard, so the keys stay with the slides you present. One background job
holds the copies; its marker, `$XDG_RUNTIME_DIR/mirror`, holds its pid and the
screens. Every two seconds it checks that the copies and the screens are still
there: a screen unplugged or a copy closed ends mirroring, so a copy never
lands on the screen it copies. The other screen keeps its own resolution; the
copy is scaled to fit it.

`test/display` checks mirroring against the fake niri and a fake wl-mirror: the
row with two screens and none with one, the command line, the status, off
closing the copies, and a screen unplugged ending it. In the VM, QEMU's
virtio GPU with `max_outputs=2` gives niri a second screen.
