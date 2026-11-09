# Boot

From the power button to the login screen, and from Shut Down to off.

## What you see

1. The computer's own logo, from its firmware.
2. No menu: systemd-boot starts the default room at once. Hold Space while
   the computer starts to choose another room
   ([systemd-boot's keys](https://www.freedesktop.org/software/systemd/man/latest/systemd-boot.html#Key%20bindings)).
3. The splash: the 匠 tile on the night, with a light that runs along a
   line under it while the computer starts. An encrypted disk asks for its
   password in a field under the tile. Firmware that installs while the
   computer restarts shows "Putting the update in place" and how far it is.
4. The login screen arrives. The first one since the computer started opens
   on the splash's picture; the line goes out, the tile rises onto its place
   above the clock as the sky comes up behind it, and the time, the date and
   the field follow. After a logout the login screen only fades in.
5. Shutting down and restarting show the splash, and never wait long on a
   service that will not stop.

Press Esc during the splash to see the messages behind it.

## How it works

| Piece | Where |
|---|---|
| Install step | `install/steps/30-boot.sh`, safe to run again |
| The splash | `default/plymouth/takumi/`, plymouth's two-step module, installed to `/usr/share/plymouth/themes/takumi` |
| Its images | drawn by `install/plymouth/render.qml` the way the shell draws the emblem |
| Initramfs | `etc/mkinitcpio.conf.d/takumi-plymouth.conf` puts plymouth right after `systemd` (or `udev`) |
| No menu | `timeout 0` in `<esp>/loader/loader.conf` |
| Quiet start | options in `/etc/kernel/cmdline`, copied into each room's boot entry |
| The arrival | `commands/greeter/main` and `shell/Parts/Arrival.qml` |
| Shutting down | `etc/systemd/system.conf.d/10-takumi.conf`, `etc/systemd/user.conf.d/10-takumi.conf`, `etc/systemd/system/user@.service.d/10-takumi.conf` |
| No graphics driver | `commands/session/start` (below) |

**When the graphics driver cannot draw.** On a real computer niri then keeps
running with no screen at all. Six seconds into the session, `takumi session
start` asks niri for its screens; with none, it ends that start and starts niri
again with Mesa's software driver (`kms_swrast`), without animations, and the
Core says once "Graphics are running without their driver". The failure is
kept in `~/.local/state/takumi/drawing-failed` with the kernel and Mesa
versions, so later logins draw on the CPU at once, and the first login after
an update that changes either tries the driver again.

The kernel options, each for one reason:

| Option | Why |
|---|---|
| `quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto` | the splash instead of messages; errors still reach the log |
| `vt.global_cursor_default=0` | no blinking cursor on the text console |
| `plymouth.ignore-serial-consoles` | a serial console, when there is one, keeps its text and the screen keeps the splash |
| `vt.default_red=11 vt.default_grn=15 vt.default_blu=20` | the text console's black is the splash's night, `#0b0f14` |
| `systemd.tty.term.console=dumb` | the console is a plain terminal to systemd ([kernel-command-line(7)](https://www.freedesktop.org/software/systemd/man/latest/kernel-command-line.html)): it is sent no escape codes and asked nothing, so no step of the start waits on an answer the splash is holding |
| `zswap.enabled=0` | swap is zram, compressed memory; zswap in front of it would compress every page twice ([tuning.md](tuning.md)) |

### Between the splash and the login screen

Plymouth quits once the system is up, and greetd puts the text console
back into text mode before it starts the login screen (it does so for every
session it starts). So for a moment the console is what shows, and then cage
draws its first, empty frame. Plymouth's `quit --retain-splash` cannot keep
the picture up over that, because the console repaints the screen as soon as
plymouth lets go of it. So the moment is made short and quiet instead:

- the console's black is the splash's night, so it reads as the same dark;
- nothing is printed there: the login screen's messages go to the journal
  (`journalctl -t takumi-greeter`), and it goes straight to logind instead of
  trying seatd first;
- the login screen's first picture is the splash's, drawn at the size and
  place plymouth draws it, twice as large on a screen at least 1200 pixels
  tall and denser than 192 dpi, as plymouth does;
- the sky is painted behind that picture, not before the first frame, and the
  rise waits for it (two seconds at most);
- the login screen's compiled QML and shaders are kept in
  `/var/cache/takumi/greeter` (the greeter user's home is `/`), so a boot
  does not compile the login screen again.

In the VM, from the splash's last frame to the login screen's first: 1.35 s,
of which cage's empty frame is 0.75 s. It was 5.4 s, with two lines of text on
the console.

### Shutting down

A service that has not stopped 10 seconds after it was asked is ended, in
the system and in your own session, instead of systemd's minute and a half.
The manager of your own services gets 15 seconds, not two minutes. A unit
that sets its own `TimeoutStopSec=` keeps it.

## Changing it

- Redraw the splash's images after changing the emblem: in a Takumi session,
  `OUT=/tmp/takumi-plymouth qs -p install/plymouth/render.qml`, then copy
  the folder into `default/plymouth/takumi/` and run the install step again.
  `test/boot` checks that the login screen's copy of the splash still matches.
- Plymouth not installed: the step says so, and the computer starts with text.

## Not provable here

- A real graphics driver failing: `test/boot` proves the switch to drawing on
  the CPU against a fake niri with no screens, not on real hardware.
- A real computer's firmware logo and its own screen density (the VM's screen
  is 1280 by 832 and never draws the splash twice as large).
- Kernels that hand the console over late (`CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER`):
  there the console may never be drawn, and the moment is plain black.
- The password field for an encrypted disk: encryption is not built yet
  ([roadmap.md](roadmap.md)).
- `systemd.tty.term.console=dumb` guards against a wait that needs the splash
  on the same console as systemd; the VM's console is its serial port.

## Testing

`test/boot` runs anywhere: the splash's files are all there, its colours and
geometry match what the login screen draws, and the kernel options keep the
console's night. In the VM, `test/vm shot` during a restart shows each stage.
