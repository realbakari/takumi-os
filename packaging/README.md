# Takumi OS Arch Packaging

`packaging/PKGBUILD` builds four split pacman packages directly from this repository:

- `takumi-base` — `takumi`/`tk` router, `commands/`, `lib/`, `config/`, `migrations/`, app-colour templates, systemd units and polkit rules
- `takumi-shell` — Quickshell desktop (`Sky`, `Core`, isolated `Lock`, `Greeter`, `Setup`)
- `takumi-themes` — all 55 contrast-checked 4-phase themes and native sky artwork
- `takumi-hardware` — declarative `default/hardware/*.toml` profiles and PipeWire speaker tunings

## Building locally on Arch

```bash
cd packaging
TAKUMI_SRC="$(cd .. && pwd)" makepkg -f
```

Takumi never blocks raw `pacman -Syu`: `takumi update` builds an Atomic Room beside your running system, while standard Arch package tooling remains fully supported.
