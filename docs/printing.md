# Printing and scanning

Printers and scanners live in the Core. Type "printer" (or "print", "scan")
and the Palette lists the printers set up on this computer, the ones it can
see on the network and by USB, and scanning when a scanner answers. There is
no printer settings window, and no driver to download for a printer made in
the last ten years.

## What you see

| Row | Says | Enter |
|---|---|---|
| a printer set up here | Ready · apps print to it | nothing: it is the default |
| another one | Out of paper · Enter makes it the one apps print to | `takumi printer default` |
| a stopped one | Offline · Enter starts it again | `takumi printer resume`, in the Core |
| Add EPSON ET-2850 Series | On this network · Enter sets it up | `takumi printer add`, in the Core |
| Add Brother HL-1110 series | Plugged in by USB · Enter sets it up | the same |
| Add a printer by its address | For one that does not show up here | asks for the address |
| Scan a document | A PDF in Documents · HP LaserJet M110w | `takumi scan pdf`, in the Core |
| Scan a photo | A PNG in Documents, every detail kept | `takumi scan png` |

How a printer is, in words: Ready, Printing, Out of paper, Paper is stuck, Out
of ink (or toner, as the printer says), A cover is open, Offline, Paused,
Stopped; "Ready · low on toner" when it still prints. "test page" lists "Print
a test page on …" for each printer, and "remove printer" lists "Remove …",
which asks before it removes. A printer's name finds it while the print
service runs. Looking for printers and scanners takes some seconds, so it
runs in the background: "Looking for printers…" shows until it is done, and
the rows look again while they are on show.

## Setting up a printer

Enter on a printer found on the network runs `takumi printer add` as a
conversation in the Core. Most printers made since about 2015 print
driverless (IPP Everywhere, AirPrint, Mopria): CUPS asks the printer what it
can do and needs nothing else. The Core says "Setting up HP LaserJet M110w…",
then "HP LaserJet M110w is ready to print". The first printer set up becomes
the one apps print to.

A printer that cannot print driverless, or one plugged in by USB, gets the
closest driver CUPS has for its make and model, offered in words: "HP LaserJet
1020 needs a driver. Use “HP LaserJet 1020, hpcups 3.22.10”?" Enter takes it;
Esc offers the next one, three at most. When there is none, the Core says the
printer needs a driver this computer does not have. Drivers come in packages:
`hplip` for HP, `gutenprint` and `foomatic-db-engine` for many others.

Every printer is set up to keep trying when it is off or asleep, instead of
stopping and holding every later document until someone starts it again, and
it is not shared with the network.

A printer that does not show up (on another network, or one that does not
announce itself) is added by its address: "Add a printer by its address" asks
for it, and `192.168.1.20` means the printer's standard address there,
`ipp://192.168.1.20/ipp/print`.

## Notices

`takumi-printer.service` follows what you print and says, once each:

- "Printed · Quarterly report.pdf · HP LaserJet M110w" when a document is done
- "Could not print" when the printer gave up on it (a cancelled one says nothing)
- "HP LaserJet M110w is out of paper · add paper and it goes on by itself"
- "Paper is stuck in …", "A cover is open on …", "… is out of toner",
  "… is low on ink"
- "Office Color is offline · turn it on; your document waits for it", only
  while a document of yours waits for it

## Scanning

"Scan a document" scans one page at 300 dpi, in colour, into Documents as
`Scan 2026-11-09 14-32-05.pdf`; the Core says "Scanned", and pressing the
notice opens it. "Scan a photo" makes a PNG, every detail kept. Network
scanners work driverless (eSCL and WSD, through sane-airscan); others through
SANE's own backends.

## Commands

```
takumi printer [--json]                  the printers, how each one is, the default
takumi printer add <uri|address> [name]  set one up (a conversation)
takumi printer default <name>            the one apps print to
takumi printer test <name>               a test page
takumi printer resume <name>             start a stopped printer again (a conversation)
takumi printer remove <name>             remove it (asks first in the Core)
takumi scan [pdf|png]                    scan a page into Documents (a conversation)
```

A name is the printer's own name or its queue's (`HP_LaserJet_M110w`), in any
case. Exit status, for scripts, with the last line saying it in words:

| Exit | `printer add` | `printer remove`, `default`, `test`, `resume` | `scan` |
|---|---|---|---|
| 0 | set up, or it already was | done | saved |
| 3 | no address or password came, or no driver was chosen | not confirmed, or no password came (remove, resume) | |
| 4 | it needs a driver this computer does not have | | |
| 5 | the printer did not answer | no printer by that name | no scanner |
| 6 | this account may not add printers | may not (remove, resume) | |
| 2 | not a printer's address | no name given | not pdf or png |
| 1 | anything else | anything else | anything else |

## How it works

CUPS prints (`cups.socket` starts it when anyone asks). The rows and the list
read `lpstat -d -v -l -p` once: the default, each printer's address, and its
state with the reasons CUPS keeps (`media-empty-error`, `offline-report`, …),
which `lib/printer.sh` turns into words. Whether a supply is ink or toner comes
from the printer's own `marker-types` (`lpoptions -p`).

Printers are found with `lpinfo --include-schemes dnssd,ipp,ipps,usb -l -v`,
which listens for printers announcing themselves (Avahi) and asks the USB
ports. One line per printer: CUPS folds a printer's IPP and IPPS announcements
into one, and a USB printer that also shows on the network keeps its network
line, which needs no driver. What it found is kept a minute in
`$XDG_RUNTIME_DIR/takumi-printers-found`.

Setting up is `lpadmin -p <name> -D <description> -E -v <address> -m everywhere
-o printer-error-policy=retry-job -o printer-is-shared=false`, or `-m <driver>`
from `lpinfo --device-id … -m` (else `--make-and-model`), which cups-driverd
ranks closest first; drivers for another brand, the raw queue and the
driverless model already tried are left out. CUPS lets an administrator's own
account change printers over its local socket (the `wheel` group is in its
`SystemGroup`), so usually nothing is asked. When CUPS refuses, `core_sudo`
asks for the password in the Core ([approvals.md](approvals.md)) and runs the
same command. The default is yours alone: `lpoptions -d` keeps it in
`~/.cups/lpoptions`, which every app's print dialog reads, with no password.

`takumi printer watch` (the service) asks systemd whether the print service
runs, which never starts it. While it runs, it asks CUPS every 3 seconds while
a document of yours waits or prints, else every 20. CUPS numbers jobs in order,
across restarts; a watermark in `~/.local/state/takumi/printer-watermark`
stays just under the oldest job still waiting, so a document on a slow printer
is told even when a later one on a fast printer finished first, and nothing
from before is told twice. A job's result is its `job-state-reasons`
(`lpstat -l -W completed -o`); its name comes from `lpq` while it waits.

Scanning runs `scanimage --format=jpeg --resolution 300 --mode Color` (fewer
options when the scanner refuses one) on the scanner `scanimage -L` found last,
kept five minutes in `$XDG_RUNTIME_DIR/takumi-scanners` (cameras are left out).
`img2pdf` wraps the JPEG in a PDF as it is, without scanning it again;
ImageMagick's `magick` is used when img2pdf is missing; with neither, the JPEG
is kept and the notice says why. The notice is `takumi notice --open`, and the
conversation ends without a last sentence so that offer stays.

## Not yet

- Accounts that are not administrators cannot add or remove printers: CUPS
  and sudo both refuse them. Asking polkit through cups-pk-helper would let
  them, with an administrator's password.
- Two identical printers on one network show with the tag they announce
  (`[4C1A2B]`), which is all that tells them apart.
- Printing options (two-sided by default, paper size, colour) are set in each
  app's print dialog; there are no rows for them.
- Scanning several pages into one PDF, and making scans searchable.

## Testing

`test/printer` runs on any machine with fake CUPS and SANE tools that keep
their state in files: the words for every state, the rows, setting a printer
up driverless and with a driver as a conversation, sudo only when CUPS refuses
and asked in the Core, every exit status, the watch's notices told once and in
order, and scans that land in Documents.

In the VM the real stack runs without a printer: `ippeveprinter -k "Test
Printer"` (part of CUPS) is an IPP Everywhere printer that announces itself on
the network, and its web page sets its paper and ink levels, which is how the
out-of-paper and low-ink notices are seen. SANE's `test` backend, uncommented
in `/etc/sane.d/dll.conf`, is a scanner. A printer's own paper, a real USB
printer that needs a driver, and a network scanner still need the hardware.
