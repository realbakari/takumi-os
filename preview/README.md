# Preview

An interactive mock of the Takumi desktop for design review: the Strip, the
Core (rest, notice, open), the Sky and the Lock in all fifty-five themes and
phases, built from the real `themes/*/theme.toml` palettes and the real
`takumi --manifest` output in `data.json`. It paints the same sky from the
same numbers as `shell/Look/Sky.js`. It is a picture of the design, not
the shell; the shell is in `shell/` and runs on niri (see `docs/vm.md`).
App icons are drawn as strokes here because the browser has no icon theme.

```bash
python3 -m http.server 8765 --directory preview
```

Then open http://127.0.0.1:8765. Regenerate `data.json` after changing a
theme with the snippet in `test/themes`, or by hand with
`commands/theme/render` and `bin/takumi --manifest`.
