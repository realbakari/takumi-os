# Design language

What Takumi looks like, and why. [shell.md](shell.md) has the numbers.

## Content is the interface

A screenshot of Takumi is mostly your work: code, a page, a terminal. The
shell is one capsule at the bottom of the screen. Every pixel the shell takes
is a pixel your work does not get, so the shell earns each one.

## One theme recolours everything

A theme is not a wallpaper and an accent. It is the terminal, the editor's
syntax, the system monitor's graphs, the bundled apps' bespoke squircle icons
and file manager's folders, GTK chrome and controls, Firefox tabs and address
bar, the focus ring and the sky, all from one `theme.toml`, all changing
together. When something does not follow the theme, that is a bug.

## The sky belongs to the theme

Takumi's seventeen native themes ship cohesive 16:9 artwork tailored to their
palettes (`themes/<name>/skies/default.jpg`). Themes without custom
images get a distinct procedural landscape painted from the theme's name, full
palette and the clock: a disc that rises, crosses and sets over theme-seeded
horizons, and a crescent among stars at night. Every theme is visually
distinct at rest and in the picker without requiring an external wallpaper daemon.

## One object

On top of your windows there is exactly one thing, the Core. It rests as
status, widens to tell you something, and grows into the Palette when you
ask, into Quick settings from its status marks and into Today from its clock. No menu bar, no dock, no popups, no notification stack. Everything the
shell says, it says from the same place, in the same shape.

## One mark

The emblem is 匠 (takumi, the artisan) in the surface colour on a tile of the
accent, one shape at every size (`shell/Parts/Emblem.qml`). It appears at the
moments that matter: in the Core, in the field, on the lock screen, on the
login screen as the boot splash's tile rises onto it, and at the end of an
install.

## Hierarchy through type

Inter for the interface, JetBrains Mono for data and code. Hierarchy comes
from size and case, not colour: one large number where a number matters (the
time on the lock screen), uppercase tracked micro labels for kinds and dates,
dimmed values beside bright ones. Numbers are tabular so nothing jitters.

## One material

Every surface the shell draws is the same optical material, respecting a strict
boundary between floating controls and work content:

- **Work windows stay solid and legible** (never smeared with stacked glass
  blur), lifted off the Sky with soft elevation shadows (`softness 30`) and a
  directional gradient focus catch instead of a harsh flat neon outline.
  Every window, focused or not, also carries a one-pixel hairline of the
  foreground, so it still has an edge on a dark sky where a shadow cannot show.
  Inside a GTK window there are three depths: the header is a band of the
  surface, 46 px tall like the Core; the sidebar sits halfway and ends in a
  hairline; the page is the background, the deepest.
- **The Core is adaptive optical glass** over niri's background blur (`0.72` at
  rest / `0.84` open on dark themes, automatically rising to `0.80` / `0.90` on
  light themes so light skies never cause contrast whiteout, tunable via
  `glass_tint = "adaptive" | "tinted" | "clear"` in `shell.toml`). Without a
  GPU it falls back cleanly to `0.94` / `0.985` so window edges never show
  through.
- **Dual-stroke solar rim & concentric geometry:** Each surface carries a dark
  outer ambient-occlusion contour paired with an inner glass hairline whose
  upper specular catch shifts smoothly with the Sky's phase azimuth (left at
  dawn, overhead at day, right at dusk), plus a faint lower refraction bounce.
  Nested controls scale concentrically (`coreOpenRadius 24` → `fieldRadius 14`,
  `tileRadius 14`, `rowRadius 12`, Strip windows `14` at `10` px gap). Sliders
  and switches stay quiet at rest and activate localized bevel refraction while
  hovered or dragged.
- **Restraint:** Fine sub-perceptual grain, an optical smoke gradient behind
  open surfaces, and no gradients on individual controls. The accent is spent
  in a few places only: the focused window's directional catch, the selected
  row's rail, a switch that is on, today in the month, the disc in the sky.

## Motion that explains

Things move only to show where they came from: the Palette grows out of the
capsule you were already looking at, results arrive from the field, the
capsule slides away when a window takes the whole strip. Exits are faster
than entrances. Every duration goes to zero with `reduce_motion`.

## What we avoid

- Glow blobs, gradient app tiles, rainbow accents, glassmorphism stacks.
- Placeholder art. Shipped native themes carry bespoke visual identity; procedural skies are generated per theme from its palette and name.
- Icons from a patched font. Strokes, or the app's own icon.
- Anything on screen that is not either your work or the one object.
