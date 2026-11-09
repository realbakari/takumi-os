# The look

A theme ([phase-themes.md](phase-themes.md)) is where the look starts. This
page is the rest of it: a theme made from your own picture, your fonts, the
apps that wear the theme beyond GTK and the terminal, and About this
computer.

## A theme from a picture

"Make a theme from a picture…" opens a file chooser in Pictures. Choose a
photo and, a moment later, the Core opens on the new theme's row and shows
it on the shell with the photo as the sky. Enter uses it; Esc keeps yours.
"Make a theme from my background" does the same with the picture on the sky
now, and names the theme after the one it came with ("Ion sky"). When the
sky is painted rather than a picture, it says so and points to the first row.

The theme is yours: `~/.config/takumi/themes/<name>/`, named after the file
(`Beach at dusk.jpg` becomes "Beach at dusk", `beach-at-dusk`). Making it
again from the same file gives "Beach at dusk 2"; a name you give yourself
(`takumi theme from photo.jpg "Summer"`) makes that theme anew. One of
Takumi's own names always gets a number, so your theme never hides it. The
folder holds `theme.toml`, the photo as its sky, `skies/default.jpg` (a PNG
or WebP stays one; turned the way the camera held it, at most 4K, without its
camera details, which in a phone photo include where it was taken), and a
480 by 270 `sample.png` for its row.

### How a picture becomes colours

ImageMagick reduces the picture to its eight main colours at 64 by 64 pixels
(`magick <picture> -resize 64x64 -colors 8 -format %c histogram:info:-`).
From those, Takumi's own rules in `lib/theme.sh`:

- **Light or dark** follows how light the picture is overall: a snowy field
  or a beach at noon gives a light theme, a city at night a dark one.
  `--light` and `--dark` choose for you.
- **The background** takes the hue of the picture's largest area on that
  side, calmed and pushed very dark or very light; the surface is one step
  from it.
- **The accent** is the picture's most vivid colour, preferring one away
  from the background's hue. A black and white photo gets a quiet steel blue.
- **The six named colours** (red, yellow, green, cyan, blue, magenta) keep
  their meaning, each pulled halfway towards a picture colour near it.
- **The phases**: dawn warms the accent from the picture's own reds and
  oranges (peach when it has none) and warms the background a little; dusk
  warms the accent further; night sinks the background, softens the text and
  quiets the accent, blues most.

Then every colour moves lighter or darker, never to another hue, until it
reads: text at 7:1 against the background and the surface, quiet text and
the accent at 3:1, the named colours at 4.5:1, in every phase. A theme is
written only when `takumi theme check` passes it, whose rules are the floor
under those targets: text at 4.5:1 or better, the accent at 3:1 or better
against the background and the surface. Themes made from a picture ask for
glass (below).

## Fonts

Type "fonts" and the Palette lists the interface font and the code font in
use, then every family on this computer that sets English text. Each row's
line is a sample ("Sphinx of black quartz, judge my vow", or `0O 1lI {} []`
for a monospaced family) that the Core draws in that family. Enter on a
family uses it: a proportional one for the interface, a monospaced one for
code and the terminal. Three letters of a family's name find it from
anywhere ("plex", "fira").

Text size is one setting with the display's "Text bigger" and "Text
smaller" rows ([display.md](display.md)); `takumi font size` is the same
setting by number.

| Where | Interface font | Code font | Size |
|---|---|---|---|
| The Core | `font_ui` in `~/.config/takumi/shell.toml` | `font_mono` | `font_size`, 13 as drawn |
| GTK apps | GNOME's `font-name` and `document-font-name` | `monospace-font-name` | 11 points, scaled by `text-scaling-factor` |
| foot | | `font=` in `look/foot-theme.ini` | 11 points at 13, in step |
| Qt apps, browsers, Electron apps | fontconfig's `sans-serif` and `system-ui` | fontconfig's `monospace` | their own |

The fontconfig aliases are `look/fontconfig.conf`, linked as
`~/.config/fontconfig/conf.d/60-takumi-fonts.conf`. GTK apps change at once;
the others as they next start. Takumi starts with Inter and JetBrains Mono.

### Getting more families

Rows for the families below that are not here yet read "Get IBM Plex", with
the package and its repository. Enter asks for your password in the Core and
pacman installs it. Every one comes from Arch's own `extra` repository and
fits any computer Takumi runs on (they are `any` packages):

| Family | Package | Choose it as |
|---|---|---|
| Inter | `inter-font` | Inter (installed with Takumi) |
| JetBrains Mono | `ttf-jetbrains-mono` | JetBrains Mono (installed with Takumi) |
| Noto | `noto-fonts` | Noto Sans (installed with Takumi) |
| IBM Plex | `ttf-ibm-plex` | IBM Plex Sans, IBM Plex Mono |
| Fira Sans, Fira Mono, Fira Code | `ttf-fira-sans`, `ttf-fira-mono`, `ttf-fira-code` | the same |
| Source Sans, Source Serif, Source Code Pro | `adobe-source-sans-fonts`, `adobe-source-serif-fonts`, `adobe-source-code-pro-fonts` | Source Sans 3, Source Serif 4, Source Code Pro |
| Cascadia Code | `ttf-cascadia-code` | Cascadia Code, Cascadia Mono |
| Hack | `ttf-hack` | Hack |
| Roboto, Roboto Mono | `ttf-roboto`, `ttf-roboto-mono` | the same |
| Ubuntu | `ttf-ubuntu-font-family` | Ubuntu, Ubuntu Mono |
| DejaVu | `ttf-dejavu` | DejaVu Sans |
| Open Sans | `ttf-opensans` | Open Sans |
| Iosevka | `ttc-iosevka` | Iosevka |
| Nerd Font builds of JetBrains Mono, IBM Plex Mono, Fira Code, Source Code Pro, Cascadia Code, Cascadia Mono and Hack | `ttf-jetbrains-mono-nerd`, `ttf-ibmplex-mono-nerd`, `ttf-firacode-nerd`, `ttf-sourcecodepro-nerd`, `ttf-cascadia-code-nerd`, `ttf-cascadia-mono-nerd`, `ttf-hack-nerd` | JetBrainsMono Nerd Font, BlexMono Nerd Font, FiraCode Nerd Font, SauceCodePro Nerd Font, CaskaydiaCove Nerd Font, CaskaydiaMono Nerd Font, Hack Nerd Font |
| Nerd Fonts' symbols alone | `ttf-nerd-fonts-symbols` | nothing: tools that draw the symbols find them |

## Apps in the theme

**Folders.** Papirus draws its folders in two dozen colours. Whenever the
theme changes, Takumi points a small icon theme of its own,
`~/.local/share/icons/Takumi`, at the Papirus colour nearest the theme's
accent (folders, their Documents, Downloads and other faces, and the home
folder) and inherits everything else from Papirus, dark or light with the
theme. GTK uses it unless you chose another icon theme yourself. Papirus's
own files are never touched, so this needs no password; `papirus-folders`,
which changes them, is not in Arch's repositories.

**Glass.** A theme that says `glass = true` in its `[meta]` makes foot and
GTK windows slightly see-through (0.92), so the sky shows behind them; every
other theme stays solid. niri draws the focus ring as a ring around each
window rather than a plate behind it, so the sky, not the ring's colour, is
what shows through. Themes made from a picture ask for it; set it to
`false` in the theme's `theme.toml` to keep yours solid.

**Browsers.** "Colour the browsers with the theme" (`takumi theme
browsers`) reaches Firefox through each profile: its `user.js` allows a
stylesheet (`toolkit.legacyUserProfileCustomizations.stylesheets`) and its
`chrome/userChrome.css` imports `chrome/takumi.css`, a link to the look's
`firefox-userChrome.css`. The tab strip, toolbars, address bar, menus and
sidebar take the theme's colours from Firefox's next start, and follow the
theme at every start after. Takumi adds one marked line to each file and
keeps yours; a profile made later is picked up at the next theme or phase
change.

Chromium, Chrome and Brave build their colours from one colour given as a
managed policy, `{"BrowserThemeColor": "<accent>"}` in
`/etc/chromium/policies/managed/takumi-theme.json` (and Chrome's and Brave's
own policy folders when they are installed). Only root may write there, so
the row asks for your password. Their dark mode follows the theme through
`--force-dark-mode` in `~/.config/chromium-flags.conf`. After you choose
another theme, its notice says when Chromium is still on the old colour;
choosing the row again brings the new one. `takumi theme browsers off`
takes away Takumi's lines, links and policy files and leaves yours.

**The prompt.** "Terminal prompt in the theme's colours" (`takumi theme
prompt`, which turns it on when it is off and off when it is on) installs
starship from Arch's `extra` repository when it is missing, links
`~/.config/starship.toml` to the look's `starship.toml` (the folder, the git
branch and its state, a long command's time, a `›` in the accent, red after
a failure), and adds one marked line that starts it to `~/.bashrc`, and to
zsh's and fish's start files when you use them. A `starship.toml` of your own
is kept as `starship.toml.before-takumi` and comes back when it is turned
off. The prompt follows every theme and phase.

## About this computer

"About this computer" opens a card in the Core: the model as its title, then
Takumi's version and the room in use, the processor, memory, graphics, the
disk, the kernel and how long the computer has been on. `takumi about`
prints the same, one fact a line:

```
Takumi     0.1.0, room from 8 Nov 2026, 09:30
Computer   Framework Laptop 13 (AMD Ryzen 7040Series)
Processor  AMD Ryzen 7 7840U, 8 cores
Memory     32 GB
Disk       412 GB free of 1 TB
Graphics   AMD Phoenix1
Kernel     Linux 6.17.7-arch1-1
Up         3 h 12 min
```

The model is the firmware's (`/sys/class/dmi/id`, Lenovo's by its product
version, not its type code; placeholders such as "To Be Filled By O.E.M."
are left out), or the device tree's on ARM boards. The processor is
`/proc/cpuinfo`'s name without its trade marks and clock speed. Memory is
the size on the box: the kernel keeps some for itself, so the next common
size above what it reports. The disk is the one Takumi runs from, its size
as its maker counts it (1 TB, not 931 GiB). Graphics are lspci's product
names, or each card's driver without lspci. The room is the one the computer
started ([atomic-rooms.md](atomic-rooms.md)), at the time it was made.

## Commands

```
takumi theme from [picture] [name] [--dark|--light]   a theme from a picture; none: the sky's
takumi theme pick                                     choose the picture first
takumi theme check <name>                             each phase's contrast, against the rules
takumi theme browsers [on|off]                        Firefox and Chromium in the theme's colours
takumi theme prompt [on|off]                          the starship prompt in the theme's colours
takumi font set <ui|mono> <family>                    the interface or the code font
takumi font size <10-20|bigger|smaller>               the text size everywhere
takumi font get <family>                              a family from Arch's repositories; none: the list
takumi font list [ui|mono]                            the fonts in use and the families here
takumi about [--json|--card]                          About this computer
```

For scripts, each says how it ended in its exit status and its last line:

| Command | Exit status |
|---|---|
| `theme from`, `theme pick` | 0 made (pick: or nothing chosen) · 2 usage · 3 no picture, or none ImageMagick can read · 4 ImageMagick (pick: zenity) is missing · 1 anything else |
| `theme check` | 0 reads well · 1 a phase breaks a rule · 3 no such theme |
| `theme browsers` | 0 done · 1 no browser to colour · 2 usage · 3 no password: Chromium kept its colours |
| `theme prompt` | 0 done · 1 starship did not install · 2 usage |
| `font set` | 0 chosen · 2 usage · 3 not on this computer, with how to get it |
| `font size` | 0 set · 2 usage |
| `font get` | 0 here now, or already · 1 it did not install · 3 a family Takumi does not know, or several match |
| `about` | 0 · 2 usage |

## Not yet

- Running foot terminals and Qt apps keep their font until they start again;
  Firefox reads its stylesheet only at start.
- Qt apps take the families from fontconfig but not the size or the colours;
  those need a Qt platform theme.
- Chromium's colour is set when you choose the row, not at each theme change,
  because its policy needs your password.
- Video backgrounds, several pictures per theme, and themes shared between
  computers.

## Testing

`test/look` runs on any machine with fake ImageMagick, zenity, fontconfig,
pacman, sudo, GNOME settings, Quickshell and a fake /sys and /proc. It makes
themes from fixed colours (a beach, a night city, pure white, black, grey,
yellow and blue) and checks each phase against the contrast rules, then
checks the folder a theme is written to, its name and sky, the Core opened
on it, the chooser, fonts chosen and fetched as a conversation, the Palette's
font rows, the browsers coloured and given back, the prompt, the folder
icons for a dark and a light theme, and About this computer for a Framework,
a Lenovo and a computer whose firmware says nothing. `test/templates` checks
that glass and your fonts reach foot, GTK and fontconfig; `test/themes`
checks that every shipped theme's text reads at 4.5:1 or better in every
phase.
