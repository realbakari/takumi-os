# Where things live

Takumi is one repository. This page says what each folder holds, where it
ends up on a computer, and what Takumi keeps in a home. There are no
packages yet: the installer's steps copy the files ([install-process.md](install-process.md)).

## The repository

| Folder | Holds | On a computer |
|---|---|---|
| `bin/` | `takumi`, the router, and `tk`, its short name ([commands.md](commands.md)) | `/usr/bin/takumi`, `/usr/bin/tk` |
| `commands/` | every command, `commands/<group>/<name>`, and `groups.tsv` | `/usr/lib/takumi/commands/` |
| `lib/` | bash that commands and the installer read in: rooms, Wi-Fi, Bluetooth, sound, screens, power, the Core's conversations, the disk, the setup disc, updates | `/usr/share/takumi/lib/` |
| `shell/` | the Quickshell desktop: the Core, the Sky, the Lock, the login screen and the setup screens ([shell.md](shell.md)) | `/usr/share/takumi/shell/` |
| `themes/` | one folder per theme: `theme.toml`, `sample.png`, sometimes `skies/` ([phase-themes.md](phase-themes.md)) | `/usr/share/takumi/themes/` |
| `config/` | the settings a home starts with | `/usr/share/takumi/config/`, and copied into each home by its first migration |
| `migrations/` | the changes that set a home up and keep it current ([migrations.md](migrations.md)) | `/usr/share/takumi/migrations/` |
| `default/` | Takumi's own system files (below) | where each belongs |
| `etc/` | settings added to other programs' folders under `/etc` (below) | `/etc/` |
| `install/` | the installer: `fetch.sh`, `run.sh`, `steps/`, `packages/`, the Shelf's apps (`shelf.tsv`), the setup disc's builder (`iso/`) and the VM's provisioner (`vm/`) | the checkout in `~/.local/share/takumi`; the package lists at `/usr/share/takumi/packages/`, read by every update; the Shelf at `/usr/share/takumi/shelf.tsv` |
| `guide/` | the guide for people coming from a Mac or Windows | the checkout; rendered to HTML at `/usr/share/takumi/guide/` for the Palette's Help row |
| `docs/` | how Takumi works, for people changing it | the checkout |
| `preview/` | a picture of the design in a browser | nowhere |
| `test/` | the checks (`./test/run`), and `test/vm`, the desktop in QEMU on a Mac | nowhere |
| `version` | the version | `/usr/share/takumi/version` |

### `default/` and `etc/`

```
default/app-colours/            /usr/share/takumi/app-colours/              templates that colour apps from the theme
default/palette/emoji.tsv       /usr/share/takumi/default/palette/          the Palette's emoji
default/coding-agents/takumi/   /usr/share/takumi/coding-agents/takumi/     the skill Claude Code reads (linked into ~/.claude/skills)
default/keyd/default.conf       /usr/share/takumi/default/keyd/             Harmony's layer, for turning it back on
default/systemd/system/*        /usr/lib/systemd/system/                    a new room's health check and acceptance, the first start of a computer nobody owns yet
default/systemd/user/*          /usr/lib/systemd/user/                      the shell, the phase clock, idle, battery, clipboard, speaker tuning, the microphone light, Thunderbolt docks, cloud folders (takumi-cloud@)
default/wireplumber/            /usr/share/wireplumber/wireplumber.conf.d/  Bluetooth headsets connect and keep their settings
default/pipewire/               /usr/share/pipewire/pipewire-pulse.conf.d/, /usr/share/takumi/default/pipewire/   new devices take the sound; the two qualities
default/audio/tunings/          /usr/share/takumi/default/audio/tunings/    speaker tunings
default/udev/*.rules            /usr/lib/udev/rules.d/                      the microphone key's light, Wi-Fi power saving following the charger
default/hardware/*.toml         /usr/share/takumi/default/hardware/         this computer's fixes, as data (takumi hardware)
default/networkmanager/dispatcher.d/90-takumi-clock   /usr/lib/NetworkManager/dispatcher.d/   the time zone follows a new network, when asked
default/networkmanager/dispatcher.d/80-takumi-wifi-power   /usr/lib/NetworkManager/dispatcher.d/   Wi-Fi power saving off on the charger
default/systemd/system-sleep/takumi-rooms   /usr/lib/systemd/system-sleep/   hibernating wakes the system that hibernated
etc/polkit-1/rules.d/50-takumi-update.rules  /etc/polkit-1/rules.d/      the next room built on the charger, without a password
etc/polkit-1/rules.d/50-takumi-bolt.rules    /etc/polkit-1/rules.d/       allowing a Thunderbolt dock asks for the password
etc/systemd/oomd.conf.d/, etc/systemd/user/app.slice.d/   /etc/systemd/   systemd-oomd stops the app, not the desktop
etc/ufw/applications.d/takumi   /etc/ufw/applications.d/takumi              the apps the firewall knows by name
default/systemd/system/greetd.service.d/   /etc/systemd/system/greetd.service.d/
default/takumi-session          /usr/bin/takumi-session                     what niri starts at login
default/wayland-sessions/       /usr/share/wayland-sessions/takumi.desktop
default/greetd/config.toml      the login screen's greetd settings
default/pam/takumi-lock         /etc/pam.d/takumi-lock
default/pam/takumi-lock-finger  /etc/pam.d/takumi-lock-finger               the Lock's finger, beside its password
default/tmpfiles/takumi.conf    /usr/lib/tmpfiles.d/takumi.conf
default/plymouth/takumi/        /usr/share/plymouth/themes/takumi/          the boot splash

etc/<path>                      /etc/<path>                                 sudoers.d, sysctl.d, pacman.d/hooks, systemd,
                                                                            keyd, mkinitcpio.conf.d, modules-load.d, tmpfiles.d
etc/zram-generator.conf         /etc/systemd/zram-generator.conf
```

Takumi changes no file another package owns. It adds its settings where a
program reads a folder of extras (`sysctl.d`, `sudoers.d`, systemd's
`*.conf.d`, pacman's hooks, mkinitcpio's `conf.d`); where a program has no
such folder, an install step you can read sets it and says so.

## A home

```
~/.config/                      the settings from config/
  niri/config.kdl               Takumi's: includes the three below; settings reset puts it back
  niri/takumi/defaults.kdl      Takumi's: input, layout, binds
  niri/takumi/touchpad.kdl      the touchpad as its key or the Core left it
  niri/takumi/input.kdl         the pointer, touchpad and key repeat as the Core left them (takumi keys pointer)
  niri/takumi/motion.kdl        animations off, when you turned them off (takumi switch motion)
  niri/takumi/outputs.kdl       yours: the screens you kept from the Core
  niri/takumi/overrides.kdl     yours: loaded last, wins
  takumi/theme                  the theme you chose
  takumi/phase.toml             the clock the phases follow, or a phase you pinned
  takumi/display.toml           text size and night light
  takumi/power.toml             idle times and power profiles
  takumi/intent.toml            the assistant's engine and model; its keys are in the login keyring
  takumi/themes/<name>/         your themes, shaped like themes/<name>/
  takumi/app-colours/           your app-colour templates; they win over Takumi's
  takumi/on/                    scripts run when something happens: theme-change, update-ready
  takumi/palette/               your own Palette providers, one script each
  takumi/sound.toml             the speaker tuning you chose
  takumi/tunings/               your own speaker tunings
  takumi/capture.toml           what a recording records, as you last chose
  takumi/voice.toml             dictation's model
  takumi/clock.toml             the clock's format and your other cities
  takumi/weather.toml           the weather's place, when it shows in Today
  takumi/backup.toml            where backups go and what they leave out
  takumi/browsers, takumi/prompt   the browsers and the prompt in the theme's colours
  niri/takumi/accessibility.kdl the screen reader at login and the pointer's size
  environment.d/60-takumi-pointer.conf   the pointer's size for apps
  fontconfig/conf.d/60-takumi-fonts.conf the fonts you chose, for every app
  starship.toml                 a link to the prompt in the theme's colours
  pipewire/pipewire.conf.d/60-takumi-quality.conf   studio or balanced sound
  fcitx5/                       the input method's profile, when one is set up
~/.local/share/applications/    Terminal and System monitor by those names (a migration writes them)
~/.config/rclone/rclone.conf    the clouds you signed in to (backups, and OneDrive, Google Drive, Dropbox as folders)
~/.config/gtk-3.0/bookmarks     Files' sidebar; the cloud folders are added here
~/.cache/takumi/cloud/<cloud>   what a cloud folder keeps on this computer
~/.local/share/nautilus/scripts/   Files' right-click scripts: Send to, Send to phone, Make smaller to send, Write to a USB stick
~/.local/share/takumi/voice/    dictation's speech model
~/.claude/skills/takumi         a link to Takumi's skill, when Claude is the assistant

~/.local/state/takumi/          what Takumi works out for you
  look/                         the drawn look: palette.toml, the app files, the sky picture
  migrations/<file>             one marker per migration this home has run
  migrate.log                   what the last login's migrations did
  notices.jsonl                 what apps said, for Earlier and Today
  intent/transcript.jsonl       what Intent asked for and what you approved (never a key)
  intent/install.log            Claude Code's installer, when the assistant installed it
  update.log                    the last update, step by step
  player                        which app the media keys control
  keyboard.log, language.log    what the last keyboard or language change did
  updates.json                  how many updates wait, and whether one is ready
  reminders.tsv                 your reminders, which come back at the next login
  backup/, share/               the last backup, the disk's last sighting; what came in nearby
  contrast                      the theme high contrast replaced

/var/lib/takumi/                what the computer keeps
  rooms/                        the systems you can start ([atomic-rooms.md](atomic-rooms.md))
  greeter/                      the login screen's copy of your look
  charge-limit                  the battery's charge limit, for every room
  update-build.log              what the last update prepared on the charger did
  first-start                   a computer nobody owns yet: the setup screen asks its owner at the next start (root's alone)
  erase                         an erase to finish at the next start
  hardware.json                 the fixes each room has, newest twelve
  audio/tuning                  this computer's speaker tuning, from the hardware data
```

## How a home is set up

Every home is set up by its migrations, the first of which copies the
settings in `config/` that the home lacks. They run at every login before niri
starts, so a new account, an old one and one made by the setup disc all end
up the same. `takumi settings reset` puts Takumi's settings back over yours,
keeping what you chose. See [migrations.md](migrations.md).
