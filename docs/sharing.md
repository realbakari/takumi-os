# Sharing and your phone

Files go to phones and computers nearby through LocalSend, and your own phone
joins the Core through KDE Connect: its notifications show here, files and the
clipboard go across, and the Core can make it ring. Both work on your own
network, with nothing in between.

## Send to…

"Send to…" (type "send", "share" or "airdrop") sends the files you copied in
Files (`Super+C`), or right-click selected files in Files › Scripts › Send
to… LocalSend opens on its Send page with them, and every phone or computer
nearby with LocalSend open shows there; you pick who gets them. Without files,
LocalSend opens for you to choose.

The first time, the Core asks: "Sending to phones and computers nearby uses
LocalSend, a free app from Flathub (org.localsend.localsend_app). Get it? No
password needed." It comes from Flathub just for you, like any app on the Shelf
(`takumi app get`). With the firewall on, `takumi firewall allow LocalSend`
then asks to let it in: others reach LocalSend on port 53317, TCP and UDP.

## Smaller to send

A photo from an iPhone is a HEIC that half the world cannot open, and a minute
of 4K video is too big for mail. With photos or videos copied in Files
(`Super+C`), typing "shrink", "smaller" or "email" offers **Shrink 3 photos for
email**; right-click them in Files › Scripts › Make smaller to send does the
same without the Core. Each gets a copy next to it, the original untouched:

- a photo becomes a JPEG at most 2560 pixels on its long side, turned the
  right way up: "IMG_0042 (small).jpg";
- a video becomes an MP4 (H.264 and AAC, which every phone, mail and chat app
  plays) at most 1080 pixels on its short side: "holiday (small).mp4".

Notes say how far it got, and the last word says what it saved: "2 photos and
a video are smaller: 16 MB became 2.2 MB, next to the originals". A JPEG or an
MP4 that was small already is left as it is. From Files the same sentence comes
as a notice that opens the folder. The first time, the Core offers to install
what it needs from Arch: imagemagick with libheif (HEIC) and libjpeg-turbo,
and ffmpeg for videos.

## Receiving

"Receive from nearby" keeps LocalSend open in the background, so others can
send to this computer, under the name LocalSend gave it ("Ready to receive:
this computer shows as Quiet Fox in LocalSend nearby."). What arrives is said in the
Core: "Received beach.jpg · from Mira's iPhone", and pressing the notice opens
it. Several files at once open their folder; a message says what it says.
Receiving needs LocalSend let through the firewall, so it stops if you say no
there.

## Your phone

"Connect your phone" (type "phone") pairs it, in the Core:

1. The first time, it installs KDE Connect from Arch's packages; the password
   is asked in the Core. KDE Connect then runs as your own service,
   `takumi-phone.service`, from every login on.
2. With the firewall on, it asks to let KDE Connect in (ports 1714 to 1764,
   KDE Connect's own firewall profile, KDEConnect).
3. "Open KDE Connect on your phone, on the same Wi-Fi as this computer." The
   phone shows up within seconds. With two phones nearby, the Core asks which.
4. The computer asks the phone to pair, and the Core asks **"Does Pixel 8 show
   1A2B3C4D? Tap Accept there"**: both screens show the same code, so you know
   it is your phone and no one else's. A phone that asked first gets "Pixel 8
   asks to pair. Does it show 1A2B3C4D?" Codes that differ, or Esc, cancel it.

Then, under "phone":

| Row | Does |
|---|---|
| Pixel 8 · Connected · battery 82%, charging | how it is |
| Find my phone | it rings loudly, even on silent (`takumi phone ring`) |
| Send to Pixel 8 · The 2 files you copied | sends them (`takumi phone send`); Files has right-click › Scripts › Send to phone |
| Send the clipboard to Pixel 8 | what you copied, ready to paste there (`takumi phone clipboard`) |
| Pixel 8 is not connected | open KDE Connect on it, on the same Wi-Fi |
| Forget Pixel 8 | asks first ("forget phone"); the last one forgotten stops KDE Connect |

The phone's notifications show in the Core as they arrive, like any app's,
and wait in Earlier. Files the phone sends land in Downloads, and KDE Connect
says so in the Core.

**What needs the KDE Connect app on the phone: all of it.** On Android, get
KDE Connect from Google Play or F-Droid, and allow it to read notifications
when it asks, or they stay on the phone. On an iPhone, KDE Connect from the App
Store sends files and the clipboard, but notifications stay on the phone,
because iOS does not let an app read other apps' notifications, and an iPhone
answers "Find my phone" only while the app is open.

## The rows together

"send" lists Send to…, Send to Pixel 8 and the clipboard row; "airdrop" lists
Send to… and Receive from nearby; "phone" lists the phone's rows first, then
these. A phone asking to pair comes first of all.

## Commands

```
takumi share [file...]            LocalSend with these files, or the ones you copied
takumi share --receive            LocalSend ready in the background for what others send
takumi share shrink [file...]     smaller copies to send, of these or the copied ones
takumi phone pair [device]        pair a phone, checking the code on both screens
takumi phone ring                 find my phone
takumi phone send [file...]       files to the phone, or the ones you copied
takumi phone clipboard            the clipboard to the phone
takumi phone status [--json]      paired phones, connected or not, battery
takumi phone forget               forget the phone
```

`ring`, `send`, `clipboard` and `forget` take `--to <phone>` when more than one
is paired; otherwise they use the one that is connected. `takumi share` exits 0
LocalSend is open · 1 it could not open · 2 a file is not there · 3 LocalSend
is needed and was not got; `takumi phone pair` exits 0 paired · 1 not paired ·
3 an answer was needed and none came · 5 no phone showed up. `takumi share
shrink` exits 0 made smaller · 2 no photo or video to shrink · 3 what it needs
was not installed · 1 one or more did not shrink (the log is
`~/.local/state/takumi/share-shrink.log`).

## How it works

**LocalSend** runs as the Flatpak `org.localsend.localsend_app` (a LocalSend
installed another way is used too). Files reach it through Flatpak's document
portal (`flatpak run --file-forwarding … @@ files @@`), so it can read them
wherever they are; a LocalSend already open takes them over from a second
start and shows its window. `takumi share receive`, run by `takumi share`,
follows the list of what LocalSend received (`flutter.ls_receive_history` in
its `shared_preferences.json`) for as long as LocalSend runs and says each new
entry in the Core with `takumi notice --open`. The right-click scripts are
`~/.local/share/nautilus/scripts/Send to…` and `Send to phone`; each hands
the selected files' full paths to a `takumi` command.

**Shrinking** is [ImageMagick](https://imagemagick.org/)'s `magick
"<photo>[0]" -auto-orient -resize '2560x2560>' -background white -flatten
-quality 82` (the first image of a HEIC, transparency on white) and
[ffmpeg](https://ffmpeg.org/) with `libx264 -crf 23 -pix_fmt yuv420p`, `aac
-b:a 128k` and `-movflags +faststart`, its progress read from `-progress
pipe:1` against `ffprobe`'s duration. imagemagick, libheif, libjpeg-turbo and
ffmpeg are in Arch's `extra` repository; ImageMagick reads HEIC only with
libheif installed. The right-click script is `~/.local/share/nautilus/scripts/Make
smaller to send`, written by a migration; what it was given waits in
`$XDG_RUNTIME_DIR/takumi/shrink-files` when the Core must install something
first. The row is in the drives provider (`commands/palette/drives`), next to
Files' other rows.

**KDE Connect** is `kdeconnectd` in `takumi-phone.service`. Pairing turns
KDE Connect's own autostart off for your account
(`~/.config/autostart/org.kde.kdeconnect.daemon.desktop`, `Hidden=true`), so
it never runs twice. Takumi talks to it through `kdeconnect-cli` and its D-Bus
interface (`busctl --user --auto-start=no`, so nothing starts it behind the
service's back): the devices, the pairing code (`verificationKey`), accepting
a phone's request, the battery. The clipboard is read by KDE Connect itself
(`kdeconnect-cli --send-clipboard`), so what you copied never goes on a command
line.

## Not done

- **Choosing who gets the files in the Core.** LocalSend's own window does
  that.
- **Receiving from login on.** LocalSend runs from the first "Send to…" or
  "Receive from nearby" until it is closed or you log out.
- **Texts and calls** from the phone: KDE Connect can, the Core does not show
  them yet.
- **KDE Connect's own settings** (which plugins run, sharing the clipboard as
  you copy) are in its app, `kdeconnect-app`.
- An HDR video from a phone becomes plain 8-bit colour without tone mapping,
  so its colours may look flat.
- What LocalSend received is read from its own settings file; if a LocalSend
  update changes that file, the notices stop and sending still works.

## Testing

`test/share` runs on any machine with a fake LocalSend (`flatpak`, `pgrep`,
its list of what arrived), a fake clipboard (`wl-paste`) and a fake KDE Connect
(`kdeconnect-cli`, and `busctl` answering for its D-Bus): LocalSend only after
asking, files through the document portal, the firewall asked only when it is
on, what arrives said with Open, pairing with the code on both screens, a phone
that asked first, two phones nearby, ringing, sending, the clipboard, the rows,
and forgetting. In the VM, LocalSend and KDE Connect are real; a phone on the
same network as the VM, or LocalSend on the Mac, is the other side.
It also checks shrinking against fake ImageMagick and ffmpeg: the row from the
copied files, asking before installing, the copies and their names, the
commands, the notes and the sentence, a small photo left alone, a failure, and
the notice from Files.
