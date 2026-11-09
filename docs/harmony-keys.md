# Harmony keys

Harmony makes `Super` the universal Command key, so the editing cluster a Mac
user has in their hands works in every app on day one.

## What works where

| Keys | Everywhere | How |
|---|---|---|
| `Super+C` | Copy | emitted as the `XF86Copy` key, honoured by GTK, Qt, Chromium, Firefox, Electron and foot |
| `Super+V` | Paste | `XF86Paste` |
| `Super+X` | Cut | `XF86Cut` |
| `Super+Z` | Undo | `Ctrl+Z` |
| `Super+Shift+Z` | Redo | `Ctrl+Shift+Z` |
| `Super+A` | Select all | `Ctrl+A` |
| `Super+S` | Save | `Ctrl+S` |
| `Super+F` | Find | `Ctrl+F` |
| `Super+W` | Close tab | `Ctrl+W` |
| `Super+T` | New tab | `Ctrl+T` |
| `Super+N` | New window | `Ctrl+N` |
| `Super+R` | Reload (browser) | `Ctrl+R` in browsers only, see below |
| `Super+,` | Preferences | `Ctrl+,` |

Everything else with `Super` reaches the compositor unchanged, so niri's
`Super+Arrows`, `Super+1..9`, `Super+Space`, `Super+Q` and friends keep
working.

## How

[keyd](https://github.com/rvaiya/keyd) runs as a system daemon and rewrites
keys at the evdev level, before any compositor or app sees them. The whole
layer is one file, `/etc/keyd/default.conf`, shipped from `etc/keyd/`:

```
[ids]
*

[main]
leftmeta = layer(cmd)
rightmeta = layer(cmd)

[cmd:M]
c = copy
v = paste
x = cut
z = C-z
a = C-a
s = C-s
f = C-f
w = C-w
t = C-t
n = C-n
, = C-,
```

`[cmd:M]` declares a layer that behaves as Meta by default, which is why
unlisted keys fall through to niri untouched, and the listed ones are the
Harmony cluster.

## The terminal

The reason to emit `XF86Copy` and not `Ctrl+C` is the terminal. `Ctrl+C` is
an interrupt there, and a copy key that kills your process is a failed
design. foot binds `XF86Copy`/`XF86Paste` to clipboard copy/paste out of the
box, so `Super+C`/`V` are safe. `Super+Z` becomes `Ctrl+Z`, which suspends a
foreground job; the shipped `foot.ini` rebinds that to a no-op and leaves
`Ctrl+Z` typed directly alone.

## Per-app layers

niri implements `wlr-foreign-toplevel-management`, so
`keyd-application-mapper` can swap layers when the focused app changes.
`Super+R` reloads in Chromium and Firefox and cycles column width everywhere
else, which is done with an `[chromium]` and `[firefox]` app section in
`~/.config/keyd/app.conf` seeded from `config/keyd/`. This is the only place
Harmony is app-aware; the editing cluster above never depends on it.

## Opting out

`takumi keys harmony off` moves `/etc/keyd/default.conf` aside and restarts
keyd. `Super` is then a plain modifier and niri's binds are all you have.
`takumi keys harmony on` puts Takumi's file back. Both ask for your password
in the Core.

## A PC keyboard: Alt and Super swapped

On a Mac keyboard the Command key sits beside the space bar; on a PC keyboard
that place is Alt's, with the Windows key further out. Typing "swap alt" (or
"windows key", "command key") in the Core offers **Swap Alt and Super**, which
runs `takumi keys harmony swap on`: the left Alt becomes the Command key, with
Harmony's whole cluster, and the Windows key becomes Alt. **Put Alt and Super
back** (`takumi keys harmony swap off`) undoes it. Only the left keys trade
places: the right Alt stays AltGr, which many layouts type with.

It is a marked block under `[main]` in keyd's file, in place of Harmony's line
for the left Windows key, using keyd's key-to-layer and key-to-key bindings
([keyd's manual](https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc)):

```
# Alt and Super swapped (takumi keys harmony swap)
leftalt = layer(cmd)
leftmeta = layer(alt)
# End of Alt and Super swapped
```

With Harmony off the file holds the swap alone and the two keys only trade
places (`leftalt = leftmeta`, `leftmeta = leftalt`). The swap lasts through
Harmony going off and on; off gives Harmony's file back byte for byte.

## Force quit

`Super+Alt+Escape`, the Mac's `Cmd+Option+Esc`, opens the Core on "force
quit": one row for each app with a window, **Force quit Spotify**, and
**Restart Spotify** beside it. "quit", "stuck", "frozen" or "not responding"
find the same rows, and "restart spotify" the one. Enter asks in place first,
because unsaved work in the app is lost.

`takumi app quit <app>` asks the app's process to stop (SIGTERM) and makes it
(SIGKILL) when it is still there three seconds later. niri says which process
owns each window (`niri msg --json windows`, its `pid`). `--restart` then opens
the app again from its `.desktop` entry, or with the command its process was
started with. With no app it lists the apps with windows: app id, name,
windows, process. Exit status: 0 done · 1 it would not stop · 2 usage · 3 niri
is not running · 4 no window of that app.

**Close all windows** (`takumi app close-all`) is the gentler clean slate: it
says how many first, then asks each window to close as its own close button
does (`niri msg action close-window --id`). An app with unsaved work asks
about it in its own window and stays; the Core names what is still open
(exit 5).

## Layouts and input methods

The keyboards you type with are the computer's: the login screen, the disk's
password prompt and every account type with the same list. Type "keyboard"
in the Core:

| Row | Says | Enter |
|---|---|---|
| Keyboards: English (US), German | Enter to add one · the keyboard mark in the Core switches between them | asks "Which keyboard? A language or a country, like French" in the Core |
| Switch to German | Now English (US) · or press the keyboard mark in the Core | switches |
| Remove the German keyboard | Keeps English (US) | asks first, then removes it |
| Add the French keyboard | After English (US), German · Enter to add it | adds it, at the end |

A language's or a country's name finds its keyboards, layouts before their
variants: "keyboard french" lists French, French (AZERTY) and French
(Switzerland); four letters of a name find them alone ("french"). The names
are xkeyboard-config's own, as the setup disc shows them (`takumi setup
keyboards`). Adding one asks for your password in the Core and changes
nothing else; the keyboard mark in the resting Core appears with the second
keyboard, and a press goes to the next.

A computer switches between four keyboards at most, and always keeps one.
The first is the one it starts with: you type your password with it when
the computer starts and at the login screen. Removing it asks first ("From
now on, type your password with German when the computer starts and at the
login screen. Go on?"). Then the text console's keymap follows the new first
keyboard by setup's rule (US English when it types no Latin letters, the
keyboard a password is typed with), and on an encrypted disk the initramfs
is built again so the disk's password prompt types with it too
(`mkinitcpio -P`, then `takumi room kernel-sync` for the room you are in).
One password covers all of it.

### Japanese, Korean and Chinese

Typing these takes an input method: fcitx5 with an engine that turns what you
type into the language's characters. "japanese", "korean", "chinese",
"pinyin" or "input" finds them:

| Row | Engine | Package | Switch |
|---|---|---|---|
| Type Japanese | Mozc | `fcitx5-mozc` | Ctrl+Space, or 半角/全角 on a Japanese keyboard |
| Type Korean | Hangul | `fcitx5-hangul` | Ctrl+Space, or 한/영 on a Korean keyboard |
| Type Chinese with Pinyin | Pinyin | `fcitx5-chinese-addons` | Ctrl+Space |
| Type Chinese with Zhuyin (Bopomofo) | Chewing | `fcitx5-chewing` | Ctrl+Space |
| Type Chinese with Cangjie | Cangjie 5 | `fcitx5-table-extra` | Ctrl+Space |

Enter installs fcitx5, its doors into GTK and Qt apps (`fcitx5-gtk`,
`fcitx5-qt`) and the engine, with one password in the Core, writes fcitx5's
list (`~/.config/fcitx5/profile`: your keyboard first, then the engines) and
starts it. Ctrl+Space switches between your keyboard and the engine, in every
app at once; holding Ctrl and pressing Space again goes on to the next
engine, as on a Mac. Super+Space stays the Core's. With an input method set up,
"keyboard" also shows "Switch to Japanese" (or "Switch back to English
(US)" while it is on) and "Stop typing Japanese", which asks first. The
keyboard under the engines is the one a password is typed with.

fcitx5's own settings (`~/.config/fcitx5/config`) are written once, the
first time, and are fcitx5's from then on: Ctrl+Space and the Japanese and
Korean keyboards' keys switch, its keys for switching between groups of
input methods are cleared (one of them would be Super+Space), and a switch
holds for every app (`ShareInputState=All`).

At every login while an input method is set up, `takumi-session` starts
fcitx5 before the shell, in a unit of its own (`takumi-input`) that ends with
the session; nothing runs while none is set up, and the package's own
autostart entry is hidden so nothing else starts it. GTK apps, Firefox and
foot reach it through Wayland's own text input. While one is set up, the
session also points the apps the shell opens at it: X11 apps through
`XMODIFIERS`, Qt 6.7 and later through `QT_IM_MODULES` (Wayland's text input
first), Qt 5 through `QT_IM_MODULE`.

### Commands

```
takumi keys layout [--json]                     your keyboards, the one in use marked
takumi keys layout add [<layout> [variant]]     add one at the end; without a name it asks which
takumi keys layout remove <layout> [variant]    remove one, never the last
takumi keys layout next                         switch to the next
takumi keys input [add | remove <japanese|korean|pinyin|zhuyin|cangjie>]
takumi keys input toggle                        the engine on or off
takumi keys input state                         what is set up and on, and its mark (あ, 한, 拼, 注, 倉), as JSON
```

`takumi keys layout add` and `remove` are conversations (`lib/core.sh`). Their
exit status says what happened and the last line says it in words: 0 done,
or nothing to do; 2 usage; 3 an answer or the password was needed and none
came, nothing changed; 4 it would leave no keyboard, or make a fifth; 5 not a
keyboard this computer knows, or not one of yours; 1 anything else.
`takumi keys input` answers 0, 2, 3, 1, and 5 for one that is not set up.

### How it works

systemd-localed keeps the list. `localectl set-x11-keymap --no-convert`
changes it through polkit, so the Core asks for the password; niri follows
localed's list the moment it changes, and the login screen reads the same
from `/etc/vconsole.conf` (`commands/greeter/main`). `--no-convert` keeps
localed from choosing a console keymap of its own: Takumi sets `KEYMAP` only
when the first keyboard changes (`localectl set-keymap --no-convert`), and
then through `sudo`, together with the initramfs. What those print goes to
`~/.local/state/takumi/keyboard.log`.

### Not yet

- A key for the next keyboard: the keyboard mark, the "Switch to" row and
  `takumi keys layout next` switch for now.
- The resting Core shows the keyboard's letters, not yet the input method's
  mark.
- fcitx5's list of candidates in the theme's colours.
- Electron apps (VS Code, Slack) on Wayland, which need their own flag for an
  input method.
- Input methods for other scripts (Vietnamese, Thai, the languages of
  India).

### Testing

`test/keys` runs on any machine against a fake systemd-localed, `sudo`,
niri, `pacman` and fcitx5: the list by name, adding and removing through
polkit, the confirmation, the console keymap and the disk's password prompt
when the first keyboard changes, the limits, the conversation, every row,
fcitx5's profile and settings, and that the session starts the input method
before the shell. On a real computer it is checked in the VM.
