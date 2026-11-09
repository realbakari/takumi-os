# Installing Takumi

You need a computer that starts with UEFI (any PC from the last ten years), a
USB stick of 4 GB or more, and about twenty minutes. Takumi either takes a
whole disk, erasing it, or goes beside Windows into free space you make for it.

## Make the USB stick

Download `takumi-<version>-x86_64.iso` and its `.sha256` file. On a Mac or a
Windows PC, write the file to the stick with balenaEtcher or Fedora Media
Writer (on Windows, Rufus in "DD image" mode works too). The stick is erased.

On a Mac with Apple silicon, try Takumi in a virtual machine instead: in UTM,
make a new Linux machine from `takumi-<version>-aarch64.iso` with a 40 GB disk,
and remove the disc from the machine after the install.

## Start from it

Turn the computer on and press its boot-menu key: F12 on most Dell and Lenovo
laptops, F9 on HP, Esc or F2 on many others. Choose the USB stick. The 匠
tile appears on a dark screen, then setup.

Nothing needs a network. Every package Takumi installs is on the stick.

## Five questions

1. **Which language?** The language your apps and desktop will speak. Setup
   guesses from the computer's own language; type a language or a country to
   find yours. Setup itself stays in English.
2. **Which keyboard is this?** It starts on the keyboard most people who
   speak your language use. Type a language or a country to find yours, press
   Enter to pick it, and try it in the field under the list. Enter again goes
   on.
3. **Where are you?** Type your city, or one near it in the same time zone.
   The clock and the sky follow. With a network cable in, "Find it online"
   asks ipinfo.io where you are, once, and only when you press it.
4. **Who is this computer for?** Your name and a password, twice. You type
   this password when the computer starts; it also locks the disk. Choose
   "For someone else" to set it up for a person who is not here: see below.
5. **Where should Takumi go?** Pick the disk. Setup says what is on it now;
   "Erase and install" turns red and needs a second press. To keep Windows,
   first give Takumi room in Windows: open Disk Management, right-click the
   C: drive, choose Shrink Volume and free 40 GB or more. Setup then offers
   "Beside Windows", and a menu at every start lets you choose.

## Your recovery code

At the end, setup shows a recovery code: 36 digits in six groups, and a code
your phone's camera can keep. If you ever forget your password, the code
opens the disk instead. Write it down or photograph it, and keep it away from
the computer. Setup asks for its last six digits before going on.

To make a new code later, open the Palette (`Super+Space`), type "recovery
code" and choose "New recovery code". The old code stops working.

## The first start

Take the stick out and restart. The computer asks for your password once,
under the 匠 tile, then opens your desktop. [Your first hour](your-first-hour.md)
takes it from there.

## Setting it up for someone else

On "Who is this computer for?", choose **For someone else** and type a
password for now, twice. Takumi installs with no account and no recovery code
yet. Turn the computer off and give it to its owner with that password.

When it first starts, it asks for that password once. Then its owner sees the
same setup screen: their language, their keyboard, their city, and their own
name and password. That password replaces yours on the disk, and they get
their own recovery code, which nobody else has seen. Then their desktop opens.

## Erasing a computer to start again

To sell or give away a computer, or to start over: `Super+Space`, type
`erase` and choose **Erase this computer**. Takumi asks you to type the word
erase, your password, and a password for the next start. Then it restarts,
and before anyone logs in it removes every account and its files, saved
Wi-Fi networks, Bluetooth pairings, fingerprints, older systems kept for
undoing updates, and the logs. The computer then asks who it is for, as
above, and its new owner chooses their own password and gets a new recovery
code. The old password, recovery code and security chip no longer open the
disk.

What it does not do: the apps and Takumi itself stay, and so do printers.
Deleted files are removed, not overwritten, and the disk keeps its own key,
so someone with special tools and the old way into the disk could in
principle find pieces of them. To be sure nothing can be recovered, install
Takumi again from the USB stick instead: that gives the disk a new key.
