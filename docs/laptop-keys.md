# Laptop keys

A laptop's own keys do what their pictures say: the keyboard light keys,
the touchpad key, and the microphone key with the light on it. The pointer,
the touchpad, key repeat and the top row are set from the Core.

## What you see

- The keyboard light keys make the keys brighter or dimmer, and the Core
  shows "Keyboard light" with a meter, as it does for the volume. A laptop
  with a single light key goes round its steps and then off: "Keyboard light
  off". After the computer wakes, the light comes back as you left it.
- The touchpad key turns the touchpad off, so a palm never moves the pointer
  while you type, and on again. The Core says "Touchpad off" and how to get
  it back: the key again, or "touchpad" in the Palette, which finds the same
  switch on a laptop without the key.
- The microphone key mutes the microphone in use, and the light on that key
  shows whether it is muted, whatever muted it: the key, the Core, an app.
  It follows the microphone you are using, a headset's too, not only the
  built-in one.

Many laptops change the keyboard light themselves and never send its keys
to the system. Their light changes as it always did, without a notice.

## The keys

| Key | Does |
|---|---|
| Keyboard light up and down | `takumi keys backlight up`, `down` |
| Keyboard light (one key) | `takumi keys backlight cycle` |
| Touchpad | `takumi switch touchpad` |
| Touchpad on, touchpad off | `takumi switch touchpad on`, `off` |
| Microphone | `wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`; the light follows |

They are niri binds in `config/niri/takumi/defaults.kdl`, on the keys' own
names (`XF86KbdBrightnessUp`, `XF86KbdBrightnessDown`, `XF86KbdLightOnOff`,
`XF86TouchpadToggle`, `XF86TouchpadOn`, `XF86TouchpadOff`,
`XF86AudioMicMute`), and work on the Lock too.

## Commands

```
takumi keys backlight <up|down|cycle|restore>   the keyboard light; restore puts back the level chosen here
takumi switch touchpad [on|off]                 the touchpad; without a word, off when on and on when off
```

`takumi keys backlight` exits 3 on a keyboard without a light, and `takumi
switch touchpad` exits 3 in a home whose niri config does not include the
touchpad's file yet; logging out and in brings it up to date.

## The pointer, the touchpad and key repeat

Type what you want in the Core; each row is the opposite of what is on, and
runs at once:

| Type | Row | Command |
|---|---|---|
| "natural scrolling", "scroll direction" | Turn natural scrolling off (or on) | `takumi keys pointer natural off` |
| "tap to click" | Turn tap to click off (or on) | `takumi keys pointer tap off` |
| "pointer speed", "mouse speed" | Pointer speed: faster · slower, "Now 4 of 8" | `takumi keys pointer speed faster` |
| "key repeat" | Key repeat: faster · slower, "Now 4 of 6" | `takumi keys pointer repeat slower` |

Natural scrolling is the touchpad's (two fingers move the page the way they
go, as on a Mac); a mouse wheel keeps scrolling the usual way. The speed is
the touchpad's and the mouse's together, libinput's `accel-speed` in eight
steps from -0.6 to 0.8 (0.0 is libinput's own). Key repeat is how long a held
key waits and how fast it then repeats, in six steps from 600 ms and 15 a
second to 180 ms and 60 a second; Takumi starts at 280 ms and 40.
`takumi keys pointer` alone says where each stands. Past the last step it
exits 4 and says so.

The choices live in `~/.config/niri/takumi/input.kdl`, which Takumi's
`defaults.kdl` includes (optionally: a home without it is fine) after its own
`input` block, and only `takumi keys pointer` writes it, whole. niri does not
merge a pointing device's block from two files: the later one replaces it
([niri: include](https://github.com/YaLTeR/niri/wiki/Configuration:-Include)),
so the file restates every touchpad and mouse setting `defaults.kdl` makes,
with your choices in place ([niri: input](https://github.com/YaLTeR/niri/wiki/Configuration:-Input)).
niri reads it again when it changes, and is asked to at once. The touchpad
key's `touchpad { off }`, in `touchpad.kdl`, comes later still, so off is off
whatever these say; on again, they apply. `overrides.kdl` still wins.

## The top row

Typing "function keys", "fn" with another word, or "media keys" offers **Top
row: F1 to F12 first** or **Top row: media keys first**, whichever is not on
now (`takumi keys fn fkeys`, `takumi keys fn media`). It asks for your
password in the Core. Two kinds of keyboard let the system choose:

- Apple's keyboards, and others driven by the kernel's `hid_apple`: its
  `fnmode`, 1 for media keys first, 2 for F1 to F12 first. Set now in
  `/sys/module/hid_apple/parameters/fnmode` and from the next start in
  `/etc/modprobe.d/takumi-fn.conf` (`options hid_apple fnmode=2`).
- Laptops whose driver shows the Fn lock: Lenovo's (`ideapad_laptop`,
  `/sys/bus/platform/devices/VPC2004:*/fn_lock`) and Huawei's (`huawei-wmi`,
  `/sys/devices/platform/huawei-wmi/fn_lock_state`), 1 for F1 to F12 first.
  The laptop's firmware keeps it.

Every other keyboard decides in its own firmware, and the row says so: **Top
row: the keyboard decides**, press its Fn lock (Fn+Esc on many laptops) or
look in the settings before the computer starts. `takumi keys fn` exits 4
there. Exit status otherwise: 0 done · 2 usage · 3 no password.

## How it works

**The keyboard light** is the kernel's `<name>::kbd_backlight`. brightnessctl
changes it through logind, which lets the person at the computer do so
without a password. Up and down move a tenth of its range; one key goes
round in thirds, or one step at a time on a light with three levels or
fewer. The level chosen with the keys is kept for the session in
`$XDG_RUNTIME_DIR/takumi-kbd-backlight`, and `takumi-idle.service` runs
`takumi keys backlight restore` after the computer wakes, since some laptops
wake with the light off. A light the laptop changes itself is never kept
there, so restore leaves it alone. Between starts, systemd keeps the level
(`systemd-backlight`).

**The touchpad** is niri's: `~/.config/niri/takumi/touchpad.kdl`, which
`config.kdl` includes after `defaults.kdl`, holds `touchpad { off }` inside
`input` when it is off and nothing when it is on
([niri: input](https://github.com/YaLTeR/niri/wiki/Configuration:-Input)).
Only `takumi switch touchpad` writes it, and asks niri to read its config
again at once (`niri msg action load-config-file`). Your own touchpad
settings go in `overrides.kdl`, which is read last.

**The microphone light** is the kernel's `<name>::micmute`.
`takumi-micled.service` runs `takumi power micled` on a computer that has
one. It reads `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` whenever `pactl
subscribe` says a microphone or the choice of microphone changed (every two
seconds without `pactl`), and switches the light only when the answer
changes. The kernel's own trigger for the light follows only the built-in
microphone's switch, so the follower takes the light from it while it runs
and gives it back when it stops. `default/udev/70-takumi-micmute.rules` lets
the `wheel` group, which everyone Takumi's setup makes is in, write the
light's `brightness` and `trigger`; for anyone else, brightnessctl asks
logind.

## Not yet

- The top row on laptops whose driver shows no Fn lock (Dell, HP, ASUS and
  most others): their firmware keeps it, and Takumi cannot reach it.
- Natural scrolling for a mouse wheel on its own.
- A notice when the microphone key mutes: on a laptop without the light,
  nothing on screen says the microphone is muted.
- A notice when the laptop changes the keyboard light itself.
- Turning the touchpad off while a mouse is plugged in, and a touchpad
  tile in Quick settings.

## Testing

`test/keys` checks the pointer, the touchpad's settings, key repeat and the
top row: the file written whole with every setting `defaults.kdl` makes, the
steps and their ends, the rows in their words, `hid_apple` and a Lenovo's Fn
lock in a folder standing in for `/sys` (`TAKUMI_SYS`), and the password
refused.

`test/power` checks these against fake lights in a folder (`TAKUMI_LEDS`), a
fake brightnessctl, a fake niri and a fake PipeWire: steps up and down,
going round in thirds and on a three-level light, the notice and its meter,
restore after waking and leaving alone a light it did not set, the
touchpad's file and niri told to read it, the home without the include, and
the microphone light following a mute and a change of microphone, taken
from the kernel's trigger and given back, and through brightnessctl when the
light is not writable.
