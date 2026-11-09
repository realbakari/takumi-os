# Games

## Steam

"steam" finds "Get Steam" (`takumi install gaming`), a conversation in the
Core. It looks at the graphics chips (`lspci`) and asks once, naming what it
will add: "Get Steam, with the AMD graphics drivers for 32-bit games, game
mode and the performance overlay? It needs your password and brings the
system's packages up to date first."

Steam and most games still use 32-bit libraries, which Arch keeps in its
multilib repository. If multilib is off, its section in `/etc/pacman.conf`
is turned on. Then, with one password:

| Graphics chip | Drivers added beside Steam |
|---|---|
| AMD | `vulkan-radeon`, `lib32-vulkan-radeon`, `lib32-mesa` |
| Intel | `vulkan-intel`, `lib32-vulkan-intel`, `lib32-mesa` |
| NVIDIA, its own driver | `lib32-nvidia-utils` |
| NVIDIA, the open driver | `vulkan-nouveau`, `lib32-vulkan-nouveau`, `lib32-mesa` |
| none of these (a virtual machine) | `vulkan-swrast`, `lib32-vulkan-swrast`, `lib32-mesa`: games draw on the processor |

A laptop with two chips gets both. `gamemode` and `mangohud` come with their
32-bit halves, and you join the `gamemode` group, which takes effect at your
next login. Everything goes in with `pacman -Syu`: multilib's list is new,
and Arch never installs onto an older list, so the system's packages are
brought up to date in the same step.

Game mode asks the computer for its full speed while a game runs, and
MangoHud draws the frame rate and temperatures over it. In Steam, a game's
Properties take both as its launch options:

```
gamemoderun mangohud %command%
```

Steam runs only on Intel and AMD computers (x86_64). On an Arm computer the
row says so, in those words, and points to RetroArch and Moonlight, which
run there.

## Controllers

Xbox controllers (Xbox One, One S, Elite, Elite Series 2, Series X|S) work
by cable through the kernel's xpad driver. Without a cable they pair over
Bluetooth like any device: hold the pairing button on top until the Xbox
button blinks fast, then type "pair" in the Core. Newer controllers talk
Bluetooth Low Energy and the One S classic Bluetooth; the kernel's
hid-microsoft driver and BlueZ, as Arch ships them, handle both, rumble
included. Takumi ships no Bluetooth setting for them:

- Turning off ERTM (`disable_ertm`) was for old controller firmware; a
  controller updated once from Windows or an Xbox does not need it.
- BlueZ's own defaults (`/etc/bluetooth/input.conf`, which belongs to the
  bluez package and has no folder for extras) let them connect; nothing is
  changed there.
- xpadneo, a driver of its own with more of the controller's features, is
  only in the AUR, which Takumi never installs by itself.

With a controller plugged in, This computer says "Xbox controller · works by
cable and over Bluetooth" (`default/hardware/xbox-controller.toml`).
Microsoft's Xbox Wireless Adapter, the USB stick, has no driver in Linux
itself: its row says "its driver is only in the AUR" (xone).

## The Shelf

| Row | From Flathub, just for you |
|---|---|
| Get Heroic | Epic, GOG and Amazon games |
| Get Lutris | games from every other store |
| Get RetroArch | classic games and consoles |
| Get Moonlight | games streamed from another computer |
| Get Bottles | one Windows program at a time |

"games" lists them. For whole Windows programs, see "Windows programs" in
[apps.md](apps.md).

## Commands

```
takumi install gaming
```

Exit status: 0 · 3 an answer was needed and none came, or no · 5 Steam does
not run on this computer · 1 anything else. The last line says it in words.

## Not yet

- Game mode and the overlay for every game at once; today each game takes
  its launch options.
- Xbox controllers with their own driver (xpadneo) or through the Xbox
  Wireless Adapter (xone): both are only in the AUR.

## Testing

`test/apps` checks `takumi install gaming` against fake `lspci`, `pacman`
and `pacman-conf`: the drivers for AMD, Intel with NVIDIA's own driver,
NVIDIA's open driver and a virtual machine, multilib turned on only when it
is off, the gamemode group, no on Arm in plain words, and nothing installed
after no.

The code: `commands/install/gaming`.
