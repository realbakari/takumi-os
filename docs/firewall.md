# Firewall

Takumi turns away connections other devices start, and lets out everything
this computer starts, as a Mac or a Windows PC does. A file share, a game
server or a remote login you never meant to offer cannot be reached from a
café's Wi-Fi. When an app needs to be reached, such as LocalSend receiving a
file, the Core asks once and lets it in.

## What you see

Type "firewall" and the Palette says how it stands:

| Row | Enter |
|---|---|
| Firewall · On · 1 app allowed | nothing: the rows under it are what you can change |
| Firewall · Off · other devices can connect to this computer · Enter turns it on | turns it on, in the Core |
| Firewall · On until the computer restarts · Enter keeps it on | ufw is on, but would not start with the computer; Enter fixes that |
| Firewall · Not set up · Enter sets it up | installs ufw, then turns it on |
| Allow LocalSend · Receives files from nearby devices · blocked now | asks, then lets it in |
| Block SSH · Lets other computers log in to this one · allowed now | blocks it again |
| Turn the firewall off | asks first |

An app has a row when it is on this computer (LocalSend or Steam from
Flathub or as a command, Sunshine, an SSH server that starts with the
computer) or when it is already let in. Its name finds its row from
anywhere: "localsend" shows "Allow LocalSend" next to the app itself.

## Letting an app in

Enter on "Allow LocalSend" is a conversation in the Core:

1. The question says what the app does: "LocalSend receives files from
   nearby devices. Allow it?" Enter for yes, Esc for no.
2. The Core asks for your password, once: "Changing the firewall needs your
   password" ([approvals.md](approvals.md)).
3. "LocalSend may be reached through the firewall now."

Blocking asks only for the password. Turning the firewall off asks first:
"Other devices on the network could then connect to anything this computer
offers. Turn the firewall off?" The rules you made stay for when it is on
again.

The apps Takumi knows:

| App | Lets in | Profile |
|---|---|---|
| LocalSend | 53317, TCP and UDP | `etc/ufw/applications.d/takumi` |
| SSH | 22, TCP | ufw's own, `ufw-loginserver` |
| Steam Remote Play | UDP 27031 to 27036, TCP 27036 and 27037 | `etc/ufw/applications.d/takumi` |
| Sunshine | TCP 47984, 47989 and 48010, UDP 47998 to 48000 | `etc/ufw/applications.d/takumi` |
| Remote help | 5900, TCP, only while remote help is on ([capture.md](capture.md)) | `etc/ufw/applications.d/takumi` |

SSH is not repeated in Takumi's file: two profiles of one name make ufw warn
on every run. Any other ufw profile works by its name at a terminal
(`takumi firewall allow "WWW Full"`), with a plainer question.

## Commands

```
takumi firewall [--json]       on or off, and what is let in, in words
takumi firewall allow <app>    let an app in; asks first
takumi firewall deny <app>     block it again
takumi firewall on             turn it on, installing ufw when it is missing
takumi firewall off            turn it off; asks first
```

`allow` and `deny` exit 0 when done, 1 when nothing changed (you said no,
or ufw refused), 2 for usage and 5 for a name no profile has. A word finds
its app: `takumi firewall allow ssh`, `takumi firewall deny steam`.
`takumi firewall --json` prints one object:

```json
{"state":"on","incoming":"deny","apps":["LocalSend"],"rules":["8080/tcp"]}
```

`state` is on, restart (on until a restart), off, or none (ufw is not
installed); `incoming` is what happens to a connection nobody allowed: deny,
reject or allow.

## How it works

The firewall is [ufw](https://launchpad.net/ufw).

**On a new computer** `install/steps/25-firewall.sh` sets it and says what
it set: incoming denied and outgoing allowed (`ufw default`), Takumi's
profiles in `/etc/ufw/applications.d/takumi`, and `ufw.service` enabled. ufw
keeps these in its own files, which have no folder for extras, so the step
sets them with ufw itself. On a running computer `ufw --force enable` loads
the rules at once. In the installer's chroot nothing may be loaded into the
running kernel, so the step writes `ENABLED=yes` in `/etc/ufw/ufw.conf`
instead and the rules load at the first start. A computer whose SSH server
starts with it (`sshd.service` or `sshd.socket` enabled) gets SSH let in
before the firewall comes on, so whoever looks after it from elsewhere is not
locked out.

**What the Core reads.** ufw keeps its rules in files only root can read. So
`takumi firewall apply` (hidden, run through sudo by `allow`, `deny`, `on`,
`off` and the step) writes `/etc/takumi/firewall` from `ufw show added`
after every change: one line per app or rule let in. The rows and
`takumi firewall` read that note, `/etc/ufw/ufw.conf`, `/etc/default/ufw`
and whether `ufw.service` is enabled, with no password. Outgoing, routed and
deny rules are left out of the note: they are not about other devices
reaching this computer. A rule you add with ufw yourself shows after the
next change made from the Core.

**One password a change.** Each change is a single `core_sudo` call of
`takumi firewall apply`, so the ufw commands and the note take one password.

ufw lets in, without asking, the replies to what this computer started,
DHCP, and the multicast that finds printers and other devices (mDNS, UPnP),
from its own `before.rules`.

## Not yet

- Rules per network, so home can be more open than a café.
- Letting an app in from the local network only, instead of from anywhere.
- Asking when an app starts listening: today an app is let in from its row,
  or by `takumi firewall allow`, before it is used.
- A computer installed before this step gets ufw with its next update, off
  until "Firewall · Off · Enter turns it on", and without Takumi's profiles
  until the step runs.

## Testing

`test/firewall` runs on any machine, against a fake ufw, sudo and systemd and
a folder standing in for `/etc`: what the step sets in a chroot and on a
running computer, SSH kept reachable, the rows and their words, the question
before an app is let in, one password per change, `takumi firewall` in words
and as JSON, and the note the Core reads.
