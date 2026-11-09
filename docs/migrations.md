# Migrations

A migration is a bash file in `migrations/` named by a UTC timestamp:

```
migrations/20261108103000-niri-overrides-file.sh
```

It runs once per home, as the person whose home it is, from `takumi migrate`.
Completion is a marker file, `~/.local/state/takumi/migrations/<filename>`.

## A home is built by its migrations

The first migration, `20261108000000-set-up-home.sh`, is dated before every
other, so a new home runs it first. It copies each setting Takumi ships
(`config/`, installed at `/usr/share/takumi/config`) that the home lacks, never
one it has, draws the first look and starts the phase timer. The migrations
after it change what earlier versions shipped. There is no separate first-run
step and nothing in `/etc/skel`: an account made before Takumi was installed,
after it, or by the setup disc ends up the same. `takumi settings reset` is
the one way to put Takumi's settings back over yours: niri's, Takumi's own, the
terminal's and the shell's at once, or one app's with
`takumi settings reset <app>`, where `<app>` is a folder in `config/` (`gtk` is
`gtk-3.0` and `gtk-4.0` together). Typing "reset" in the Palette shows a row for
each ("Reset Terminal settings", from `commands/palette/settings`), a
conversation in the Core. Yours go aside as `~/.config/<app>.bak-<time>`, and
what you chose stays: niri's overrides and screens, the phase clock, text size
and night light.

## Rules

- Idempotent. A migration may be interrupted and re-run.
- As the user. Privileged work calls a `takumi` command that uses `sudo`.
- Narrow. One change, named by the filename.
- Never destructive to a file the user may have edited; copy it aside with a
  `.bak-<timestamp>` suffix first.
- A migration that fails leaves no marker and is retried at the next login.

## When they run

- At every login, before niri starts: `takumi session start` runs
  `takumi migrate`, writing what it did to `~/.local/state/takumi/migrate.log`,
  so a new account's first frame is already Takumi's.
- The installer's `50-user.sh` runs them for the person installing.
- `takumi update` runs them after an update in place, and with rooms stages
  the pending list before the restart.
- `takumi migrate --pending` lists what would run, exit 0 if anything.

## Template

```bash
#!/usr/bin/env bash
# Migration: <one line on what and why>
set -euo pipefail

target="$HOME/.config/niri/takumi/overrides.kdl"
[[ -f "$target" ]] && exit 0
mkdir -p "$(dirname "$target")"
printf '// Your niri overrides. Loaded last, wins.\n' > "$target"
```
