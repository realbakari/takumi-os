# Testing

`./test/run` runs every suite and is what CI will run; `./test/run router themes`
runs only the suites named. It needs bash, and optionally `shellcheck` and
`kdl` tooling; missing optional tools are reported, not failed.

| Script | Checks |
|---|---|
| `test/lint` | `bash -n` on every script, shellcheck when present; `bin/` holds only the router, every command in `commands/` is executable with an ABOUT block that has a summary and a risk tier, every group has its line in `commands/groups.tsv`, and every `takumi <group> <name>` a script, unit, bind or the shell runs exists |
| `test/router` | `takumi --manifest` parses as JSON, every command has `risk`, every command file actually routes, a dir named first in `TAKUMI_COMMANDS` wins, and no word runs a path |
| `test/themes` | every `themes/*/theme.toml` has the full palette, every colour is `#rrggbb`, phases only override known keys |
| `test/templates` | every `{{token}}` (and `{{token:bare}}`) in `default/app-colours/` is a palette key, and every theme renders a foot file that foot reads (`[colors-dark]`, `RRGGBB`) |
| `test/qml` | every style token, theme role, icon and component the QML uses exists, and every glyph a row or a command names; `qmllint` (found in PATH or where Qt keeps it) fails it on any QML syntax error |
| `test/boot` | the splash's files are all there, and the login screen's copy of the splash (its colours, the tile's and the line's size and place) and the console's night match the theme and the images it was drawn from |
| `test/wifi` | Wi-Fi against a fake `nmcli`: odd network names, the rows the Core shows, every exit code of `takumi wifi join`, that no password reaches any command's arguments, and the Palette's word matching ([wifi.md](wifi.md)) |
| `test/approvals` | `takumi approve askpass` against a fake shell: the answer comes back for sudo, Esc refuses, the why reaches the Core, the FIFO is private and removed ([approvals.md](approvals.md)) |
| `test/bluetooth` | Bluetooth against a fake `bluetoothctl`: rows in order with the battery, names find devices, forgetting asks, pairing asks whether the code matches ([bluetooth.md](bluetooth.md)) |
| `test/earlier` | the earlier rows against a written history: newest first, only when asked, today's in the empty Palette |
| `test/doctor` | `takumi doctor` against a fake computer: the one sentence, Wi-Fi switched back on, what needs you in words ([doctor.md](doctor.md)) |
| `test/intent` | the assistant against fake `claude`, `curl` and `secret-tool`: the plan's shape on every engine, risk 0 running and risk 1 and 2 asked once, the MCP server's handshake and tools, and no key in any command's arguments or log ([intent.md](intent.md)) |
| `test/iso` | the setup disc without building it: what each architecture carries, the live initramfs hook, the live system's own files, the boot partition's place ([iso.md](iso.md)) |
| `test/setup` | the setup disc's commands against fake tools: guesses, keyboards, places, disks, a whole encrypted install, the answers it refuses before erasing, and a new recovery code, the language and the network's place, an install for someone else, the first start (owner prepare, apply) and erasing ([setup.md](setup.md), [encryption.md](encryption.md)) |
| `test/palette` | finding your way: the empty Palette's Settings and Help rows, the settings by topic, and the guide rendered to HTML at install ([palette.md](palette.md)) |
| `test/firmware` | firmware against a fake fwupd: only on the charger, never during an update, one question naming every device ([firmware.md](firmware.md)) |
| `test/sound` | sound against fake PipeWire, playerctl and systemd: outputs and inputs, the microphone, which player the media keys control, the two qualities, speaker tunings ([sound.md](sound.md)) |
| `test/power` | power against a fake laptop: hibernation set up and undone, the lid, the charge limit, the keyboard light, the touchpad, the microphone light ([power.md](power.md), [laptop-keys.md](laptop-keys.md)) |
| `test/security` | sign-in against fake sudo, cryptsetup, fprintd and sbctl: changing the password for the account and the disk together, fingerprints, Secure Boot, the security chip, the login keyring following the password, ten tries (faillock.conf) ([security.md](security.md)) |
| `test/system` | the system's defaults against a fake iw, boltd and sysfs: oomd and the apps' slice, open files, Wi-Fi power saving on the charger, Thunderbolt docks allowed in the Core, the polkit rule ([tuning.md](tuning.md), [wifi.md](wifi.md), [hardware.md](hardware.md)) |
| `test/capture` | capture against fake recorders, sound, camera, niri and satty: what a recording asks, the sound mixed for both, the camera bubble, marking up ([capture.md](capture.md)) |
| `test/voice` | dictation against a fake recorder, model and keyboard: setting it up, listening, typing what was said ([dictation.md](dictation.md)) |
| `test/keys` | keyboards against a fake localed, sudo, niri and fcitx5: adding and removing layouts, the password's keyboard everywhere, input methods, the pointer, touchpad and key repeat, the top row, Alt and Super swapped, force quit and closing every window ([harmony-keys.md](harmony-keys.md)) |
| `test/language` | the language against fake glibc, localed, sudo and pacman: names in their own words, formats apart, the apps' language packs ([languages.md](languages.md)) |
| `test/hardware` | hardware as data against fake computers: what each finds, the fixes a room gets and loses, missing firmware ([hardware.md](hardware.md)) |
| `test/time` | the clock, reminders, timers and the weather against fake timedated, systemd, curl and NetworkManager ([time.md](time.md)) |
| `test/updates` | how many updates wait and preparing one on the charger, against fake checkupdates, NetworkManager and systemd ([updates.md](updates.md)) |
| `test/recovery` | freeing up space, restore points, update failures said in words, one app's settings back, against fake pacman, sudo, df, gio and rooms ([updates.md](updates.md), [atomic-rooms.md](atomic-rooms.md)) |
| `test/notices` | the notice queue, crash notices and the window keys, the queue's keys, links in a message, the marks for dictation, timers and remote help, CoreState's own functions run against fake notifications ([notifications.md](notifications.md)) |
| `test/a11y` | the screen reader, pointer size, sticky keys, high contrast, zoom and animations against fake Orca, gsettings, sudo, keyd and the shell ([accessibility.md](accessibility.md)) |
| `test/apps` | default apps, web apps, removing apps, Windows programs and games against fakes ([apps.md](apps.md)) |
| `test/dev` | languages through mise, containers, Git and GitHub, coding agents against fakes ([development.md](development.md)) |
| `test/backup` | backups against fake restic, rclone, udisks2 and a fake keyring: the key card, the hour, a disk away ([backup.md](backup.md)) |
| `test/share` | sending nearby and the phone against fake LocalSend and KDE Connect, and making photos and videos smaller ([sharing.md](sharing.md)) |
| `test/firewall` | the firewall against a fake ufw: allowing an app, the note it keeps, the profiles, remote help opening and closing it ([firewall.md](firewall.md)) |
| `test/vpn` | VPN files, connecting and Tailscale against fake nmcli and tailscale ([vpn.md](vpn.md)) |
| `test/printer` | printers and scanners against fake CUPS and SANE: setting up without a driver, the states in words ([printing.md](printing.md)) |
| `test/drives` | USB drives against a fake udisks: open, eject, erase asked twice, writing a disk image only after its name is typed, disk health in words, clouds as folders ([drives.md](drives.md)) |
| `test/look` | a theme from a picture readable in every phase, fonts, the browsers and the prompt ([look.md](look.md)) |
| `test/vm` | not a check: boots the real desktop in QEMU, see [vm.md](vm.md) |

Tests run on any machine, including this one, because none of them need
Arch, niri or Quickshell: they check the contract between files, not the
runtime. Runtime behaviour is checked by hand in the VM ([vm.md](vm.md)):
boot, log in, the Palette, rooms, and Wi-Fi on simulated radios
(`test/vm wifi`).
