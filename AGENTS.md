# Working in this repo

Takumi OS is one repository that becomes an operating system. Read
`docs/00-vision.md` and `docs/where-things-live.md` before changing anything.

## Rules

- Every command is `commands/<group>/<name>`, run as `takumi <group> <name>`,
  and starts with the ABOUT block described in `docs/commands.md`. No ABOUT
  block, no command. `bin/` holds only the router.
- Scripts are bash, `set -euo pipefail`, and must pass `./test/run` (which runs
  `bash -n` and shellcheck when present).
- Nothing in `commands/` writes outside `$HOME`, `$XDG_RUNTIME_DIR` or
  `/var/lib/takumi` without `sudo`, and every sudo call names the file it
  touches in a comment.
- `config/` is what a home starts with; the first migration copies it in.
  Changing it does not change existing homes: write a migration in `migrations/`.
- Themes are data, never code. A theme folder holds `theme.toml`, an optional
  `sample.png` and an optional `skies/` of pictures. Nothing executable.
- Docs describe the system as it is in this tree. When a doc and the code
  disagree, fix one in the same change.
- Takumi is its own design. Do not copy code, UI, naming or file layouts
  from other distributions; if a pattern is borrowed from an upstream tool's
  documentation, link that tool's docs and nothing else.

## Layout, in one breath

`bin/` the router, `commands/` every command, `lib/` shared bash, `install/` the
installer and package lists, `config/` what a home starts with, `default/`
Takumi's system files, `etc/` settings added to `/etc`, `shell/` the Quickshell
desktop (Sky, Core, Lock), `themes/`, `migrations/`, `guide/` for people,
`docs/` for people changing Takumi, `test/`.
