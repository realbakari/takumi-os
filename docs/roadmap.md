# Roadmap

| Version | Goal | State |
|---|---|---|
| 0.1 | Design and skeleton | done |
| 0.2 | Installs on Arch and runs the desktop | done in the VM (Arch Linux ARM): installer, login screen, session, shell |
| 0.3 | Rooms | done in the VM: update, accept on a good start, automatic return from a failed room with a login report, rollback, prune |
| 0.4 | Phases and themes | done: the painted Sky, crossfades, the login screen wears your theme, a night light on the phase clock, fifty-five themes previewed live in the Palette |
| 0.5 | Intent | written for Claude (through Claude Code or an Anthropic API key) and OpenAI, acting only through `takumi` commands, with the plan shown before Enter and every risky step asked in the Core ([intent.md](intent.md)); tested against fake engines, not yet with a real account |
| 0.6 | Setup disc | done in the VM: Takumi's own disc builder, keyboard, place, name and password, erase or install beside Windows, encryption with a recovery code, one password from boot to desktop ([iso.md](iso.md), [setup.md](setup.md)) |
| 0.7 | Real hardware | x86_64 laptops first; hardware quirks as data applied inside the room being built |
| 0.8 | Everyday settings in the Core | done in the VM: Wi-Fi (joining, sharing, sign-in pages), approvals, sound, displays, power, and Takumi's own boot; the rest in "Next" |
| 1.0 | Someone else's daily driver | thirty days without a terminal for ordinary use |

## Next, in order

These come from studying what a person new to Linux meets in the first week.
Each one is a Palette scope or a `takumi` command with a risk tier, never a
separate settings app.

1. **Wi-Fi in the Core**: done in the VM, on simulated radios with WPA2,
   WPA3, open and hidden networks and a fake sign-in page
   ([wifi.md](wifi.md)). Still to do: a real laptop's Wi-Fi card, and work or
   school networks (WPA-Enterprise, eduroam) with a username, a password and
   a certificate check in the Core.
2. **Approvals in the Core**: done in the VM. A Quickshell polkit agent and a
   `SUDO_ASKPASS` helper put a password request in the Core, in the Lock's
   field ([approvals.md](approvals.md), checked by `test/approvals`). Update,
   rollback and installing optional software are conversations in the Core
   now; no everyday row opens a terminal.
3. **Bluetooth**: done against a fake BlueZ ([bluetooth.md](bluetooth.md)):
   what is connected, paired and nearby, connecting and pairing in the Core
   with the code shown like a phone ("Does your phone show 482913?"),
   searching only while the rows are open. Still to do: a real adapter.
4. **Sound**: done in the VM ([sound.md](sound.md)): where sound goes, moving
   what is playing with it; per-app volume; a mark in the Core whenever an app
   records the microphone or the camera.
5. **Displays**: done in the VM ([display.md](display.md)): "make everything
   bigger", turning and arrangement in words, every change undone by itself
   after ten seconds unless you keep it, each monitor remembered by what it is
   rather than the port it is in, and resolution and refresh rate.
6. **Power**: done in the VM ([power.md](power.md)): power profiles,
   low-battery notices, idle lock and sleep times in one file, "stay awake for
   an hour".
7. **Notices you missed**: done. "earlier" lists what apps said, newest first; today's last three show in the empty Palette and in Today; a one-time code in a message gets a Copy button.
8. **Encryption, never locked out**: done in the VM
   ([encryption.md](encryption.md)): the disk is encrypted with your password
   and a 36-digit recovery code shown once as a card; one password from boot to
   desktop; a new code at any time (`takumi disk recovery`), which retires the
   old one.
9. **takumi doctor**: done ([doctor.md](doctor.md)): Wi-Fi, sound, space,
   updates, services, the clock and the battery's health; it fixes what is
   safe and says the rest in one sentence.
10. **Firmware**: done against a fake fwupd ([firmware.md](firmware.md)): on
    the charger only, never together with an update, one question naming
    every device.

Done along the way: **the boot** ([boot.md](boot.md)), the 匠 splash with a
running light, no menu, a quiet kernel, the login screen arriving out of the
splash, and a shutdown that never waits long on one service.
