# Tuning

Small settings that make an ordinary laptop feel quicker, each with its reason.
They are installed by `install/steps/20-system.sh` and `30-boot.sh`.

| Setting | File | Why |
|---|---|---|
| Swap is zram, up to 16 GB of compressed memory | `etc/zram-generator.conf` | much faster than swapping to the disk, and nothing private is written to it |
| `vm.swappiness = 180`, `page-cluster = 0`, watermarks | `etc/sysctl.d/90-takumi.conf` | the kernel's own advice for a zram-only system: swap early into fast compressed memory, keep files cached |
| `zswap.enabled=0` | kernel options | zswap in front of zram would compress every page twice |
| I/O scheduler per disk | `etc/udev/rules.d/60-takumi-iosched.rules` | none for NVMe, mq-deadline for SATA SSDs and SD cards, bfq for spinning disks so the desktop stays responsive while something copies |
| File index on the charger | `etc/systemd/system/plocate-updatedb.timer.d/takumi.conf` | the index for file search is rebuilt when plugged in, not on battery |
| `fs.inotify.max_user_watches = 524288` | `etc/sysctl.d/90-takumi.conf` | editors, file sync and build tools watch many files |
| Services stop within 10 s | `etc/systemd/*.conf.d/10-takumi.conf` | shutting down never waits a minute and a half on one service ([boot.md](boot.md)) |
| Open files: 524288 for every service and app | `etc/systemd/system.conf.d/10-takumi.conf`, `etc/systemd/user.conf.d/10-takumi.conf` (`DefaultLimitNOFILE`) | games through Wine and Proton (esync), build tools and file sync open thousands of files at once; systemd's own soft limit is 1024; apps niri starts while it runs outside systemd (a VM, drawing on the CPU) keep the login's 1024 |
| Out-of-memory: the app goes, not the desktop | `etc/systemd/oomd.conf.d/10-takumi.conf`, `etc/systemd/user/app.slice.d/10-takumi.conf` | below |

## When the memory runs out

An app that eats the memory (a runaway browser tab, a build) would fill the
zram swap until the screen freezes, and the kernel's own killer comes late
and picks almost at random. [systemd-oomd](https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.service.html)
acts first: `20-system.sh` turns it on, and your apps' slice (`app.slice` of
your own service manager) asks it to watch them
([ManagedOOMMemoryPressure, ManagedOOMSwap](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html)).
When the memory pressure inside that slice stays above 60% for 20 seconds,
or swap is 90% full, oomd stops the one cgroup inside it that is pressing
hardest, and the desktop stays. oomd writes what it stopped to the journal
(`journalctl -u systemd-oomd`); the Core does not say it yet, since a stopped
app leaves no crash report for the crash watcher.

What is covered depends on where an app runs:

| Started from | Runs in | Stopped alone |
|---|---|---|
| the Palette, and the app tiles | its own `run-<id>.scope` in `app.slice`, made by the Core with `systemd-run --scope` | yes |
| a key niri runs (`spawn`) | its own `app-niri-<app>-<pid>.scope`, made by niri when it runs as a service (`niri-session`); in a VM or when niri draws on the CPU it runs directly and its children stay in the login session | yes, except in those two cases |
| Files, and apps opened over D-Bus (Text Editor, Files) | their own service in `app.slice`, made by D-Bus activation | yes |
| a terminal | the terminal's scope, with the terminal | the terminal and everything in it |
| the shell itself, and what it runs for you (Quickshell `Process`) | `takumi-shell.service` in `session.slice` | never |

niri runs in your login session, outside the slice, and PipeWire in
`session.slice`, and the shell too (`Slice=session.slice` in
`takumi-shell.service`), so none of them is a candidate. Takumi's other user
services are in `app.slice` (where systemd puts a user service that names no
slice); the app holding the memory is the one that presses. Swap is zram, so the swap
limit means compressed memory, not a disk.

