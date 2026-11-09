# Bluetooth

Headphones, keyboards, mice and speakers, from the Core. Nothing opens a
terminal, and pairing works the way a phone does: the computer shows the code
it expects and asks whether the device shows the same.

## Where it lives

- **Quick settings** (`Super+I`, or the status marks): the Bluetooth switch,
  saying what is connected ("WH-1000XM4 and 1 more"). Its arrow opens the rows
  below.
- **The Palette**: "bluetooth", "headphones", "airpods", "speaker" or "pair"
  lists, in this order, what is connected (with its battery when it reports
  one), what is paired, and what is nearby. A device's name finds it. While
  the rows are on show the computer looks for devices and the rows update.
  "forget" lists the paired ones to forget.

| Row | Enter |
|---|---|
| Connected · battery 80% | disconnects (`takumi bluetooth disconnect`) |
| Paired | connects, in the Core (`takumi bluetooth connect`) |
| Nearby | pairs, in the Core (`takumi bluetooth pair`) |
| Forget … | asks, then forgets it (`takumi bluetooth forget`) |
| Turn Bluetooth on / off | `takumi switch bluetooth` |

Nearby devices that only have an address, no name, are left out: they are
someone else's watch or a television across the street.

## Pairing

`takumi bluetooth pair <address>` is a conversation (`lib/core.sh`). It runs
`bluetoothctl` with an agent that can show and confirm codes, and answers for
you:

- a phone or a computer shows six digits: the Core asks **"Does Pixel 8 show
  482913?"**, Enter for yes, Esc for no
- a keyboard needs digits typed on it: the Core says **"Type 482913 on
  Keyboard K380, then press its Enter key"**
- an old device that wants a PIN gets a field ("often 0000")

Then the device is trusted, so it reconnects by itself, and connected. If it
does not connect straight away, it connects whenever it is on and nearby.

## Under it

`lib/bluetooth.sh` reads `bluetoothctl` (BlueZ): the adapter, the devices,
`info` for a device's icon and battery, and a background search
(`bluetoothctl --timeout 12 scan on`, one at a time). The state Quick
settings shows comes from `takumi switch state`. `test/bluetooth` checks the
rows and the pairing conversation against a fake `bluetoothctl`.
