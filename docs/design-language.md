# Design language

What Takumi looks like, and why. [shell.md](shell.md) has the numbers.

## Content is the interface

A screenshot of Takumi is mostly your work: code, a page, a terminal. The
shell is one capsule at the bottom of the screen. Every pixel the shell takes
is a pixel your work does not get, so the shell earns each one.

## One theme recolours everything

A theme is not a wallpaper and an accent. It is the terminal, the editor's
syntax, the system monitor's graphs, the file manager's folders, GTK, the
focus ring and the sky, all from one `theme.toml`, all changing together.
When something does not follow the theme, that is a bug.

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

Every surface the shell draws is the same material: the theme's surface at
0.94 (0.985 once the Core opens over windows, so their edges never show
through), a hairline rim brightest along the top, a faint sheen down from the
top, and a deep soft shadow. While the Core is open, asking or saying
something, a soft light in the accent surrounds it. No blur, no gradients on
controls. The accent is spent in a few places only: the focused window's
ring, the selected row's rail, a switch that is on, today in the month, the
disc in the sky.

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
