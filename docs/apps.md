# Apps

Apps come and go in the Core, like everything else. There is no app store
window, no default apps page and no uninstaller: type what you want.

## Default apps

Type "default" and the Palette lists each kind of app and the one that opens
it, one row each:

| Row | Opens |
|---|---|
| Browser: Firefox | web links and pages, and Super+B |
| Mail: none chosen | email links |
| Terminal: Foot | Super+Return and terminal apps |
| Editor: Text Editor | text and code files |
| PDFs: Papers | PDF documents |
| Images: Image Viewer | pictures and photos |
| Video: Celluloid | films and clips |
| Music: Celluloid | songs and recordings |
| Files: Files | folders, and Super+E |

Enter on one lists the apps installed that can be it, the one in use first.
A kind's own word does the same from anywhere: "browser", "pdf", "terminal",
"photos", "default editor". Enter on another app makes it the default, and
the Core says so: "Browser: Chromium · web links and pages open there now".
Browser, mail, editor and video end with a row that looks on the Shelf for
another ("Get another browser"). An app's name beside "default" finds every
kind it can be: "make chrome default" shows "Browser: Google Chrome" and
"PDFs: Google Chrome".

An app is offered for a kind when it says it is one, or opens that kind's
files: a browser is a WebBrowser or opens https links, a mail app opens
mailto links, a terminal is a TerminalEmulator, an editor a TextEditor or an
IDE, a file manager a FileManager. For PDFs, pictures, video and music it is
the types the app declares, without the apps that make such files rather
than show them: a browser is not offered for pictures, a drawing app not for
PDFs. Hidden entries never show.

Super+B, Super+E and Super+Return run `takumi app open browser`, `files`
and `terminal`, so they open what you chose.

## Web apps

A web app is a site in a window of its own, with its own icon, in the Core
like any app: its row, the apps grid, and its name in the resting Core while
you use it. The Shelf has the ones people coming from Windows and macOS ask
for:

| Rows | Site |
|---|---|
| Get Outlook, Get Word, Get Excel, Get PowerPoint, Get Teams | Microsoft 365 ("office" or "microsoft" lists all five) |
| Get WhatsApp | web.whatsapp.com |
| Get Gmail, Get Google Calendar | Google |
| Get Notion, Get Figma | notion.so, figma.com |
| Get Discord (web) | discord.com, beside the Discord app |
| Get ChatGPT, Get Claude | chatgpt.com, claude.ai |
| Get GeForce NOW, Get Xbox Cloud Gaming | play.geforcenow.com, xbox.com/play: games streamed from the cloud, in the browser the makers support |

Enter makes it in a second or two, and its row leaves the Shelf.
`takumi app web <address> [name]` makes one from any site; without a name it
takes the site's own short name (its application-name or og:site_name, else
its title when that is short), else one from the address.

**The browser.** A web app opens in a Chromium-family browser's app mode
(`--app`): the default browser when it is one, else the first installed of
Chromium, Google Chrome, Brave, Microsoft Edge and Vivaldi, from Arch or from
Flathub. It shares that browser's sign-ins, so signing in to Microsoft in
Outlook signs Word in too. Firefox has no app mode. When it is the only
browser, the Core says so and offers Chromium from Flathub, just for you; if
you say no, it offers to open the site in GNOME Web, whose menu installs a
site as an app.

**The icon.** The site's own, from the site you asked for: its
apple-touch-icon, the largest its web app manifest names, a PNG or SVG icon
link, or `/apple-touch-icon.png`. A site that sends you to a sign-in page on
another site gives no icon from that page, and nobody else is asked for one.
Without one, the icon is the name's first letter on a colour, drawn on the
computer. It goes in the icon theme as `takumi-web-<name>`, in
`~/.local/share/icons/hicolor`.

**The entry.** `~/.local/share/applications/takumi-web-<name>.desktop`:

```ini
Exec=/usr/bin/chromium --app=https://web.whatsapp.com/ --class=takumi-web-whatsapp
StartupWMClass=chrome-web.whatsapp.com__-Default
X-Takumi-Web=https://web.whatsapp.com/
```

`--class` names the window on X11. On Wayland Chromium names an app window
after its address (the browser's own word, the host, the path and the
profile, any character a file name cannot hold made `_`), so
`StartupWMClass` carries that name and the resting Core finds the entry for
the window. A Flatpak browser runs as `flatpak run <id>`.

## Removing apps

"remove", "uninstall" or "delete" lists what you can remove, and a name
narrows it: "remove spotify", "uninstall gimp". Enter asks in the Core
first, and says what stays.

| Row | What goes |
|---|---|
| Remove Gmail · Web app | its entry and icon; what you signed in to stays in the browser |
| Remove Spotify · From Flathub, just for you | the app and the runtimes no other app uses; its settings stay in `~/.var/app` |
| Remove Kdenlive · Installed apart from Takumi | the package and what only it needed (`pacman -Rs`), with your password |
| Remove Windows | the container and its disk, with everything in it; `~/Windows` stays |

An app Takumi ships stays, because every update would bring it back. Only
apps installed apart from Takumi's package lists are offered: ones a person
asked for (`pacman -Qqe`), outside `install/packages/*.txt`, that show among
the apps. An app another app needs stays too, and the Core says so. A Flatpak
app installed for everyone is removed through polkit, so the Core asks for
your password.

## Windows programs

"windows" finds "Set up Windows": Windows 11 in a window, for the programs
that need Windows itself. For one older program, Bottles on the Shelf may be
enough.

1. The Core checks that the processor can run virtual machines
   (`/dev/kvm`), that the computer has 8 GB of memory in all, and that the
   home folder has 40 GB free. If not, it says which, in words.
2. One question, sized to the computer: "Set up Windows 11 with 8 GB of
   memory, 4 cores and a 64 GB disk? It downloads about 7 GB from Microsoft,
   then installs itself, which takes 20 to 40 minutes." Half the memory (4 to
   8 GB) and half the cores (2 to 8); the disk takes only the space Windows
   fills.
3. Podman and FreeRDP are installed with your password, and Podman gets a
   range of user IDs of yours (`/etc/subuid`, `/etc/subgid`) when you have
   none.
4. The row shows the download ("Downloading Windows 11 from Microsoft…
   42.5%"), then "Windows 11 is installing itself". You can close the Core;
   it says when Windows is ready.

A "Windows" app is then in the Core. Opening it starts Windows (about a
minute), shows it full screen with sound and the clipboard, and shuts it down
when you close the window, so it holds no memory while you are not using it.
Closing is shutting down: save your work in Windows first. `~/Windows` is
the Shared folder on Windows' desktop. Opened while Windows is still
installing, it shows the installation's screen in your browser instead.
Windows needs a licence of your own; without one it runs unactivated.

It is the [dockur/windows](https://github.com/dockur/windows) image under
rootless Podman, as you: the container `takumi-windows`, Windows' disk in
`~/.local/share/takumi/windows`, RDP (3389) and the installation's screen
(8006) on 127.0.0.1 only. On an Arm computer it is `dockurr/windows-arm`,
Windows 11 for Arm. The account is your login name and a password made on
the computer, kept in `~/.local/state/takumi/windows/env`, which only you can
read; it reaches Podman as `--env-file` and FreeRDP 3 on its stdin
(`/args-from:stdin`), never on a command line. `xfreerdp3` is used when it is
there, else `sdl-freerdp3`.

## Commands

```
takumi app default [<kind> [app]] [--json]    the defaults; with a kind, its apps; with an app, choose it
takumi app open <kind> [file, link or command]  the app of a kind, in a new window
takumi app web <address> [name]                 make a web app
takumi app web-remove <name>                    remove one
takumi app get <flathub id or address> [name]   a Shelf app: from Flathub, or a web app
takumi app remove <id, package or name>         remove an app, asking first
takumi install windows [--memory GB] [--cores N] [--disk GB]
takumi app windows [open|stop]                  what the Windows app runs (hidden)
takumi app shelf [query]                        the Shelf's rows (hidden)
takumi app login [<app> on|off]                 the apps that open at login; with an app, change it
```

**Open at login.** In the Palette, "login" or "startup" lists the apps that
open when you log in (Enter stops one), and "login Spotify" offers to add it
(`commands/palette/login`). They are XDG autostart entries: turning one on
copies the app's entry into `~/.config/autostart`; turning off one the system
ships writes yours with `Hidden=true`. niri's session starts them; where niri
runs on its own (a VM, or drawing without a graphics driver) `takumi-session`
starts them one by one.

The kinds are browser, mail, terminal, editor, pdf, images, video, music and
files. The last line of each says what happened in words; the exit status
says it for scripts:

| Command | Exit |
|---|---|
| `app default` | 0 · 2 not a kind · 4 no such app, or more than one matches · 5 xdg-utils is missing |
| `app open` | 0 · 2 not a kind · 3 no app for it |
| `app login` | 0 · 2 usage · 4 no app by that name |
| `app web` | 0 · 2 not a web address · 3 no answer, or no · 5 no browser can open it as an app |
| `app web-remove` | 0 · 2 · 4 no such web app |
| `app remove` | 0 · 2 · 3 no answer, or no · 4 nothing by that name · 6 it comes with Takumi |
| `install windows` | 0 ready · 2 usage · 3 no answer, or no · 5 this computer cannot run it |
| `app windows` | 0 · 3 not set up · 5 FreeRDP is missing · 1 Windows did not start |

## How it works

**Defaults.** Choosing runs `xdg-mime default <app> <types>` for the kind's
main type and every other type of the kind the app declares, and for the
browser `xdg-settings set default-web-browser`, which is what browsers ask
when they check whether they are the default. Both write
`~/.config/mimeapps.list`, the file Takumi's own defaults come in
(`config/mimeapps.list`), and the Core reads it directly. The terminal is
the first line of `~/.config/xdg-terminals.list`, which
`xdg-terminal-exec` follows; without that file, Super+Return opens foot.

**The Shelf.** `install/shelf.tsv` holds a name, a Flathub ID or a web
address, search words and one line. `takumi app shelf <query>` prints its
rows: "Get" for each app you do not have, and "Remove" rows when the query
asks. A Flathub app installs just for you, without a password
(`flatpak --user`). Besides the everyday ones it has the apps people ask for
by name: Microsoft Edge (`com.microsoft.Edge`), 1Password
(`com.onepassword.OnePassword`), Dropbox (`com.dropbox.Client`), Prism
Launcher for Minecraft (`org.prismlauncher.PrismLauncher`, found by
"minecraft") and Sunshine (`dev.lizardbyte.app.Sunshine`), which streams
this computer's games to Moonlight on another device. "games" lists every
launcher, streamer and cloud service on the Shelf. Sunshine is reached from
other devices only once the firewall lets it in ("allow sunshine",
[firewall.md](firewall.md)). Getting Sunshine also runs its own one-time setup
step (`flatpak run --command=additional-install.sh dev.lizardbyte.app.Sunshine`,
[Sunshine's docs](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2getting__started.html)),
which asks for the password in the Core, so the mouse and keyboard of the
device streaming from it reach this computer. It captures the screen through
the desktop portal, as Flatpak cannot use KMS capture.

The code: `lib/apps.sh`, `commands/app/*`, `commands/install/windows`,
`commands/palette/defaults`.

## Not yet

- A web app as the mail app, so mailto links open Gmail or Outlook.
- Windows was written against dockur/windows' documented settings and has
  not run yet: the VM has no `/dev/kvm`, so there it shows the message for a
  computer without virtualization.
- The Wayland window name is Chromium's own rule, worked out here; if a
  Chromium release changes it, the resting Core shows the address instead of
  the web app's name.
- Other file types (documents, archives) are chosen in Files, with Open
  With; the Core covers the nine kinds above.

## Testing

`test/apps` runs on any machine with fake `xdg-mime`, `gio`, `flatpak`,
`pacman`, `podman`, FreeRDP and `curl`, and only basic tools besides: which
apps can be which default, what choosing one writes, the defaults rows, web
apps (the Exec line, quoting, the icon from each source, the name, the
browser, Chromium offered when only Firefox is there), the Shelf's rows,
removing each kind of app, Windows set up in the Core and opened, and that
Windows' password reaches no command's arguments.
