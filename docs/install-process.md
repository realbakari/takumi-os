# Install process

Three entry points, one installer: the setup disc for a new computer
([iso.md](iso.md), [setup.md](setup.md)), `install/fetch.sh` on an Arch
install you already have, and the VM's provisioner ([vm.md](vm.md)).

## `install/fetch.sh`

What `curl -fsSL https://www.bakarimustafa.com/takumi/install.sh | bash` fetches. It:

1. refuses to run as root and refuses a non-Arch host
2. installs `git` if missing
3. clones this repo to `~/.local/share/takumi` (or `TAKUMI_REPO`/`TAKUMI_REF`)
4. execs `install/run.sh`

## `install/run.sh`

Runs every `install/steps/NN-*.sh` in order, each inside a logged subshell,
and stops at the first failure with the step name and the log path. Every
step is idempotent: running the installer twice is safe.

| Step | Does |
|---|---|
| `00-preflight.sh` | Arch check, network check (not from the setup disc: `TAKUMI_OFFLINE=1`), free space, `sudo` prompt once |
| `10-packages.sh` | a full `pacman -Syu`, then `--needed` from `install/packages/base.txt` and `install/packages/desktop.txt`; a package a repository lacks is skipped with a warning. `TAKUMI_PACMAN_CONF` names another pacman.conf: the setup disc's own packages |
| `20-system.sh` | copies `etc/` drop-ins (shutting down waits at most 10 s on a service), enables keyd, NetworkManager, bluetooth, timesyncd, zram, and printing and power profiles when their packages are present; turns on systemd-oomd, Wi-Fi power saving following the charger and the Thunderbolt approval rule |
| `25-firewall.sh` | the firewall on: nothing comes in unless you let an app; SSH stays open where sshd is enabled, so a remote computer is not cut off ([firewall.md](firewall.md)) |
| `27-security.sh` | the Lock's finger file beside its password one, and sudo and polkit asking for the password until you turn fingerprints on, the login keyring at the login screen (greetd's PAM file), ten tries before a two-minute wait (faillock.conf) ([security.md](security.md)) |
| `30-boot.sh` | the boot ([boot.md](boot.md)): Takumi's splash (plymouth) in the initramfs, no boot menu, a quiet kernel whose console is the splash's night; on an encrypted disk, the hooks that open it ([encryption.md](encryption.md)); says so and moves on when plymouth is not installed |
| `40-session.sh` | installs the `takumi.desktop` session, the user units and the login screen (greetd with Takumi's greeter, its caches in `/var/cache/takumi/greeter`), unless another login manager is in charge; on an encrypted disk, the first session after it is opened starts without a second password |
| `50-user.sh` | runs the installing user's migrations, the first of which copies the settings Takumi ships ([migrations.md](migrations.md)); every other account gets the same at its first login. Renders the guide (`guide/*.md`) to HTML at `/usr/share/takumi/guide/`, which the Palette's Help row opens ([palette.md](palette.md)) |
| `80-rooms.sh` | rooms on: mounts the top of the Btrfs filesystem, enables the room services, copies this room's kernel to the ESP; or converts an existing Arch root into the first room (untested); otherwise says updates happen in place |
| `90-done.sh` | prints the summary, including whether updates can be undone on this computer |

## Package lists

- `install/packages/base.txt`: the base system. One package per line,
  `#` comments allowed. The setup disc carries every package it names.
- `install/packages/desktop.txt`: the Strip, the shell (Core, Sky, Lock) and the
  apps the guide promises.

`20-system.sh` also copies both lists to `/usr/share/takumi/packages/`. An
update reads them there, so a package added to a list later reaches every
computer with its next update ([atomic-rooms.md](atomic-rooms.md)).

## The setup disc

`install/iso/build.sh` builds it ([iso.md](iso.md)). Its install
(`commands/setup/install`) partitions and encrypts the disk, makes the first
room, pacstraps every package from the disc in one go, and then runs this
same `install/run.sh` inside the new system as the new person, offline
(`TAKUMI_IN_CHROOT=1 TAKUMI_OFFLINE=1 TAKUMI_PACMAN_CONF=…`). For a computer set
up for someone else it runs as a passing account that is removed afterwards,
and the owner's account is made at the first start ([setup.md](setup.md)). The disc was
built with Takumi's own builder rather than archiso: archiso makes x86
images only, and Arch Linux ARM does not carry it.
