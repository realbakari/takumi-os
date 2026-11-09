# Firmware

The firmware of the computer and its devices (the BIOS or UEFI, a dock, a
touchpad, a dbx update) comes through fwupd, from the Core.

`takumi firmware` (the Palette row "Update firmware"; "firmware", "bios" or
"uefi" also lists the devices fwupd can update) is a conversation:

1. **Only on the charger.** On battery it stops before doing anything: firmware
   must never run out of power halfway.
2. **Never during an update.** It takes the same lock as `takumi update`
   (`$XDG_RUNTIME_DIR/takumi-update.lock`), so the two never run together.
3. **One question, every device named**: "Update the firmware of System
   Firmware, Dock? Keep the computer on and plugged in until it is done."
4. fwupd asks for the password through polkit, which is the Core
   ([approvals.md](approvals.md)).
5. The answer: "Firmware updated: System Firmware, Dock.", or "Restart when it
   suits you to finish" when a device applies it at the next start. A failure
   says the devices keep the firmware they had, and where the details are
   (`~/.local/state/takumi/firmware.log`).

`test/firmware` checks all of it against a fake fwupd.
