# Sound

Sound lives in the Core. Type "sound" (or "volume", "headphones",
"microphone", "media", "speakers"), or click the speaker in the resting
Core, and the Palette lists where sound goes, where it comes from, what is
playing and how it sounds.

## What you see

The rows read from the field upward:

1. The output in use: "Speakers · Sound goes here · 60%". Every other output
   says "Enter to send sound here": headphones, HDMI, a Bluetooth headset.
   A Bluetooth one also says how its sound travels: "AAC, good quality".
2. "Mute" or "Unmute", and "Volume 25%", "50%", "75%", "100%".
3. Each app playing now, with its own volume: "Firefox · 75%", and under it
   what it plays and what Enter does next ("Lo-fi beats · Enter for 50%").
   Enter steps an app down 100, 75, 50, 25, mute, and back to 100.
4. The microphone in use, the others ("Enter to use this microphone"), and
   "Mute the microphone" (or "Unmute the microphone" while it is muted).
5. Whoever is recording: "Zoom is using the microphone", at the top.
6. With two media apps open or more, which one the media keys control:
   "Media keys: Spotify · The media keys control it", and "Enter to control
   it with the media keys" on the others.
7. On a laptop, the speaker tuning: "Speakers tuned for this laptop · Enter
   to hear them as they are", or "Tune the speakers" when it is off.
8. "Sound: Balanced" and "Sound: Studio quality", the one in use saying so.

The rows update themselves every four seconds while they are open. Three
letters of a device or an app find it from anywhere ("hdm" finds HDMI), and
every word counts ("volume 75").

Devices get plain names: Speakers, Headphones, HDMI, Line out, Bluetooth:
and the headset's name, Built-in microphone, Headset microphone. The raw
name from the sound server shows only when nothing plainer fits.

## Keys

None of these use Super, so they never meet Harmony's keys.

| Keys | Does |
|---|---|
| Volume up, Volume down | 5% at a time, and the Core shows the level |
| Alt with either | 1% at a time |
| Shift with either | all the way up, or silent |
| Mute | mute or unmute the sound |
| Shift+Mute | the next output; the Core names it: "Sound: AirPods Pro" |
| Microphone, or Alt+Mute | mute or unmute the microphone: "Microphone off" |
| Shift+Microphone | the next microphone |
| Alt+Microphone | the microphone rows: who is listening |
| Play | play or pause the app the media keys control |
| Next, Previous | the next or the previous track |
| Alt+Next, Alt+Previous | ten seconds on, or back |
| Shift+Play, Shift+Next | the media keys move to the next app: "Media keys: Spotify" |
| Shift+Previous | the media keys move to the previous app |
| Alt+Play | pause every app that is playing |

Any change of level also unmutes: turning the sound up means you want to
hear it. Alt+Mute is there for keyboards without a microphone key. Where a
laptop links the microphone key's light to the sound chip, the light
follows.

## Switching

Enter on another output makes it the default and moves everything that is
playing to it at once, so the song you were listening to follows you to the
headphones. Recordings stay where they are. The Core says "HDMI 1 · Sound
goes here". Shift+Mute does the same with the next output, in a fixed order
(by the sound server's priority, then by name), so pressing it again goes
round them all.

## Which app the media keys control

The media keys reach one app at a time. Shift+Play picks the next one, the
Core names it, and the choice is remembered. While that app is closed, the
keys reach another window of the same app (a new Firefox is still Firefox),
then whichever app is open.

## Bluetooth headsets

A paired headset or pair of headphones that is on and in range connects by
itself at login, and BlueZ takes a trusted one back whenever it comes into
range, or after the link drops. When it connects it becomes the output, as
on a phone; a USB headset's microphone becomes the input too. A screen's
HDMI sound never takes over that way: plugging in a monitor leaves the
sound where it was. When headphones go away, what was playing pauses instead of carrying on
out of the speakers.

A headset plays music in high quality (A2DP) and switches to headset mode,
where its microphone works but the sound is call quality, only while an app
records from it. When the call ends it goes back to music quality by itself.

`takumi audio codec` says how the sound travels, in words: "AirPods Pro ·
AAC · good quality". LDAC and aptX HD are "very high quality", aptX and LC3
"high quality", AAC and SBC XQ "good quality", SBC "standard quality", and
headset mode "call quality, while an app uses the microphone".

## Sound quality

"Sound: Balanced" is where every computer starts. "Sound: Studio quality"
plays each song at its own sample rate with a short delay, for hi-res music,
recording and instruments; Balanced mixes everything at one rate with a
longer buffer, which uses less battery and never crackles, for everything
else. The change is at once and stays.

Studio quality lets the sound card follow the music's rate (44.1, 48, 88.2,
96, 176.4 or 192 kHz) instead of converting it, and makes the buffer a
quarter as long (256 samples, about 5 ms). Balanced keeps 48 kHz and 1024
samples, PipeWire's own choice.

## Speaker tuning

Laptop speakers are small, and played flat they sound thin and distort when
turned up. A tuning is an EQ and a limiter that run in front of the built-in
speakers: a little less of the bass they cannot play, more body and clearer
voices, and never a level that distorts. The headphones on the same jack are
left alone: the tuning is on only while the speakers themselves play.

A computer whose model Takumi knows gets the tuning measured for it, on for
everyone, and the row reads "Speakers tuned for this laptop". Enter hears
the speakers as they are, and that choice is yours alone. On any other
laptop "Tune the speakers" tries a general tuning, `laptop-speakers`.

A tuning is data: `default/audio/tunings/<name>.conf` holds the `filter.graph`
of a PipeWire [filter-chain](https://docs.pipewire.org/page_module_filter_chain.html),
with three lines at its head: `# title:`, `# about:` and `# needs:` (the
package its plugins come from). Your own go in `~/.config/takumi/tunings/`
and win over Takumi's. The hardware data says which tuning a model needs by
running, as root, `takumi audio tuning default <name>`, which writes the
name to `/var/lib/takumi/audio/tuning`; `takumi audio tuning default none`
takes it away.

## Privacy marks

While any app records the microphone, a microphone mark in the accent sits
in the resting Core; a click on it opens the microphone rows. While an app
takes the camera through the camera portal, a camera mark shows beside it.
A screen recorder taking the desktop sound does not count as the
microphone, and neither does the sound server's own bridge to a headset.
An app that opens the camera device directly, without the portal, is not
seen; most browsers on Wayland use the portal.

A left click on the speaker opens the sound rows; a right click mutes.

## Commands

```
takumi audio output <name|id|next>             send sound to an output; "hdmi" finds "HDMI 1"
takumi audio input <name|id|next>              use a microphone
takumi audio volume <0-100|up|down|mute|unmute> [--fine|--max|--min]
takumi audio mic <mute|unmute|toggle>          the microphone in use
takumi audio app <stream id> <0-100|mute|unmute>   one app's own volume
takumi audio player [next|previous|<name>]     which app the media keys control; alone, the list
takumi audio media <play-pause|next|previous|forward|back|pause-all>
takumi audio codec                             how a Bluetooth headset's sound travels
takumi audio quality [studio|balanced]         alone, the one in use
takumi audio tuning [on [<tuning>] [--for <output>] | off | list]
takumi audio tuning default <tuning|none>      the computer's own tuning (root)
takumi audio state [--marks]                   one line for the resting Core
```

A command that changes something says what happened in its last line, and
the Core says it too.

| Exit | Means |
|---|---|
| 0 | done |
| 1 | the sound server is not running, or the change did not take |
| 2 | words the command does not know |
| 3 | no such device, app or tuning; no Bluetooth sound device; no media app open |
| 4 | `tuning on`: nothing to tune (no built-in speakers, or no such output) |
| 5 | `tuning on`: a package the tuning needs is not installed |
| 6 | `tuning default`: only an administrator can set it |

`--for <output>` tunes another output, a USB speaker or the VM's, on any
route. `takumi audio tuning run` is what `takumi-tuning.service` runs.

## How it works

Everything is read from one `pw-dump`, the whole PipeWire graph as JSON,
and turned into two tables by `lib/audio.sh`: devices and streams. A
device's plain name comes from its active route ("analog-output-speaker"
is Speakers). Volumes are shown as a person reads them: PipeWire keeps them
cubed, so the shown value is the cube root. Switching runs `wpctl
set-default` and pins every playing stream to the new output with
`pw-metadata`, so a stream an app pointed elsewhere moves too. The volume
and microphone keys ask `wpctl` alone, which answers faster than a whole
dump. The media keys go through `playerctl`; the app they control is in
`~/.local/state/takumi/player`.

**Bluetooth.** `default/wireplumber/wireplumber.conf.d/60-takumi-bluetooth.conf`
(installed in `/usr/share/wireplumber/wireplumber.conf.d/`) sets WirePlumber's
own [settings](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/settings.html):
`bluetooth.autoswitch-to-headset-profile` for headset mode only while an app
records, `bluetooth.use-persistent-storage`, `linking.pause-playback`, and
`bluez5.auto-connect = [ a2dp_sink hfp_hf hsp_hs ]` for every headset. A
headset coming back into range is BlueZ's own doing for a trusted device
(pairing trusts it, see [bluetooth.md](bluetooth.md)); its defaults power
the adapter at start and retry a dropped link seven times over about two
minutes, and BlueZ has no folder for extra settings, so Takumi leaves
`/etc/bluetooth/main.conf` alone. `default/pipewire/pipewire-pulse.conf.d/60-takumi-new-devices.conf`
(in `/usr/share/pipewire/pipewire-pulse.conf.d/`) loads PipeWire's
[module-switch-on-connect](https://docs.pipewire.org/page_pulse_module_switch_on_connect.html)
with HDMI left out: a new device becomes the default, and a device you
picked in the Core stays until the next one connects. The codec is the
node's `api.bluez5.codec`.

**Realtime.** PipeWire raises its audio threads to realtime priority through
RealtimeKit (`rtkit`), so sound does not crackle while the computer is busy.

**Quality.** `default/pipewire/studio.conf` and `balanced.conf` (in
`/usr/share/takumi/default/pipewire/`) are `pipewire.conf.d` files.
`takumi audio quality` copies the chosen one to
`~/.config/pipewire/pipewire.conf.d/60-takumi-quality.conf` for the next start,
and sets the same values now through PipeWire's `settings` metadata
(`default.clock.quantum` in the file is `clock.quantum` there), so nothing
restarts and nothing that plays stops.

**Tuning.** `takumi audio tuning run` writes a small PipeWire configuration
to `$XDG_RUNTIME_DIR/takumi-tuning.conf` and runs it as a PipeWire of its
own, as PipeWire's `filter-chain.conf` runs filters, so a tuning that fails
to load never touches the sound server. Its one filter is a WirePlumber
[smart filter](https://pipewire.pages.freedesktop.org/wireplumber/policies/smart_filters.html)
in front of the speakers' node: whatever plays to the speakers goes through
it, and it is never an output of its own. The speakers are the output whose
device has a speaker route, whichever route is in use. The command then
follows the graph (`pw-dump -m`) and turns the filter on while the speaker
route is in use and off for the headphones, through WirePlumber's `filters`
metadata. `takumi audio tuning on` starts `takumi-tuning.service`, or the
same command as a unit of its own for this session when the service is not
installed, and waits for the filter to join the graph. What you chose is in
`~/.config/takumi/sound.toml`; the computer's own tuning wins only until you
choose. The general tuning's limiter is `swh-plugins`' fast lookahead
limiter (LADSPA).

## Not yet

- Balance, and choosing a Bluetooth headset's profile by hand: the switch
  while an app records covers the everyday case.
- A test sound.
- Tunings measured for particular models: only the general one ships, and
  the hardware data names the others as they come.
- The microphone key's light on laptops that do not link it to the sound
  chip's capture switch.

## Testing

`test/sound` runs on any machine with a fake PipeWire, a fake `playerctl`
and a fake systemd: plain names, the output in use first, apps with their
own volume, who is using the microphone, the privacy marks, that switching
moves what plays but not what records, every volume and microphone key,
the next output, the media keys' app, Bluetooth codecs in words, both
qualities set now and kept, and the speaker tuning from the Palette's row to
the configuration it runs and the route it follows. It also checks that
every bracket closes in the files PipeWire and WirePlumber read.

In the VM, `pw-cli` makes fake outputs and `pw-cat` a fake song and a fake
call ([vm.md](vm.md)). The VM's sound card is QEMU's HDA output, so the
tuning is tried there with `--for`. A real Bluetooth headset and real laptop
speakers are checked on hardware.
