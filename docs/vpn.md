# VPN

The VPN from work, the one you pay for, and Tailscale, from the Core. Type
"vpn".

## What you see

| Row | Enter |
|---|---|
| VPN Work · Connect | connects, in the Core; asks for the password when it needs one |
| VPN Work · Connected · Enter to disconnect | disconnects |
| Import a VPN… | a file chooser, then what the VPN needs |
| Set up Tailscale | asks, installs it, then signs in |
| Tailscale · Sign in · Enter opens the sign-in page | the sign-in card |
| Tailscale · Connected as laptop · Enter to disconnect | disconnects Tailscale |
| New York, NY, USA · Exit node · Enter sends your internet through it | with "tailscale" or "exit" |
| Forget VPN Work | with "forget": asks, then removes it, its password and its certificates |

The connected VPN comes first, then the most recently used. Three letters of
a VPN's name find it. The rows refresh every five seconds while they are on
show, so "Connecting…" turns into "Connected" in place.

## Importing

"Import a VPN…" opens a file chooser for a WireGuard `.conf` or an OpenVPN
`.ovpn` file, as your work or your VPN provider gives it. The Core steps
aside for the chooser and comes back for the questions:

1. An OpenVPN file made for a username and a password asks for both:
   "Username for VPN Work", then "Password for VPN Work", as dots.
2. "Connect to VPN Work now?" Enter connects; Esc leaves it ready: "Added VPN
   Work. Type vpn to connect".

A VPN never connects by itself. NetworkManager would join an imported
WireGuard profile at every start, so the import turns that off. A name
already taken gets a number ("Work 2"). A WireGuard file whose name cannot
be an interface name (more than 15 letters, or spaces) goes through a
private copy with a short name, removed at once, and the VPN keeps the name
you know.

At a terminal, `takumi vpn import ~/Downloads/work.ovpn` asks the same
questions; with no file and no screen, it asks where the file is.

## Connecting

Enter on "VPN Work · Connect" runs `takumi vpn on Work` as a conversation.
A wrong password shakes the field and asks again: "Username, or Enter to keep
ada", then the password. For scripts, the exit status says what happened and
the last line says it in words:

| Exit | Means |
|---|---|
| 0 | connected |
| 3 | an answer was needed and none came |
| 4 | the username or password did not work, or the VPN asks for something Takumi cannot answer yet |
| 5 | no VPN by that name |
| 1 | anything else |

## How a password travels

As with Wi-Fi, never on a command line. The OpenVPN import leaves a password
to a keyring (`password-flags 1`); Takumi sets `password-flags 0`, so
NetworkManager keeps it with the profile, in a file only root can read, and
hands it to nmcli's editor on stdin (`set vpn.secrets password=…`, with
backslashes, commas and equals signs escaped). The username is no secret and
goes as an argument (`+vpn.data username=…`). Connecting happens with nobody
standing by to answer for secrets, so a wrong password fails at once.

`takumi vpn forget` also removes the certificates the OpenVPN import wrote
from the file into `~/.cert/nm-openvpn`, and nothing outside that folder.

## Tailscale

"Set up Tailscale" (`takumi vpn tailscale`) asks "Tailscale links this
computer with your other devices, wherever they are. Install it?" Then, with
one password, it installs `tailscale` from Arch's repository, starts
`tailscaled` now and with the computer, and makes you its operator
(`tailscale set --operator`), so connecting, disconnecting and exit nodes
need no password after that.

**Signing in** ends on a card, like sharing Wi-Fi: "Sign in to Tailscale", a
code a phone's camera opens the sign-in page from, and the link behind
Enter. The page opens in your browser at the same moment. `tailscale up`
goes on waiting in the background, a quarter of an hour at most, and a
notice says "Tailscale is on" when this computer has joined.

**Exit nodes.** "tailscale" or "exit" lists the exit nodes your tailnet
offers that are online, the one in use first. Mullvad's show as their city,
once per city. Enter sends your internet through one
(`tailscale set --exit-node=<address> --exit-node-allow-lan-access=true`):
printers, speakers and the rest of the network at home keep answering.
Enter on the one in use stops it.

When Tailscale refuses to start because it would undo a setting made
earlier, it names the full command itself; Takumi checks that it is only
`--name=value` settings and runs it.

## The resting Core

`takumi vpn state` prints one line for the shell: `up Work` while a VPN
carries this computer's traffic (Tailscale counts while one of its exit
nodes does), `connecting Work` while one starts, and nothing otherwise.
Tailscale without an exit node is not counted: it reaches your own devices,
and your internet goes out as before.

## Commands

```
takumi vpn list [--json]               your VPNs and Tailscale, the connected one marked
takumi vpn import [file]               add a WireGuard or OpenVPN file
takumi vpn on <name>                   connect
takumi vpn off <name>                  disconnect
takumi vpn forget <name>               remove it, its password and its certificates
takumi vpn tailscale                   set up, sign in, connect
takumi vpn tailscale off               disconnect
takumi vpn tailscale exit <node|off>   your internet through an exit node, or straight out
```

`takumi vpn list --json` prints one object a VPN: `name`, `kind`
(WireGuard, OpenVPN, Tailscale), `state` (connected, connecting, off, sign
in) and, for Tailscale, `exitNode`.

## Not yet

- OpenVPN profiles that need a one-time code or a private key's passphrase:
  connecting says Takumi cannot answer that yet.
- OpenConnect (Cisco AnyConnect, GlobalProtect) and other VPNs that come as
  settings rather than a file.
- Taildrop, and a list of your machines with their addresses.
- WireGuard's `PreUp` and `PostUp` lines: NetworkManager's import skips them.
- The mark in the resting Core: `takumi vpn state` is ready for it.

## Testing

`test/vpn` runs on any machine, against a fake nmcli and a fake tailscale:
names with colons, the rows in their order, importing WireGuard and OpenVPN
files (a long name, a taken name, the file chooser, no screen), the username
and password asked in the Core and never in an argument, a wrong password
asked again, forgetting with the certificates, Tailscale set up with one
reason for the password, signed in on a card with a notice when it joins,
its exit nodes, and the line the resting Core reads.
