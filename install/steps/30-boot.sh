#!/usr/bin/env bash
set -euo pipefail
# The boot (docs/boot.md): Takumi's splash, no menu unless you hold a key, and a kernel that keeps its
# messages to itself. Safe to run again.
. "$TAKUMI_PATH/lib/rooms.sh"
# An encrypted disk is opened in the initramfs, with the keyboard its password was typed on (docs/encryption.md).
if rooms_encrypted; then
  sudo install -Dm644 "$TAKUMI_PATH/etc/mkinitcpio.conf.d/takumi-encrypt.conf" /etc/mkinitcpio.conf.d/takumi-encrypt.conf   # /etc/mkinitcpio.conf.d/takumi-encrypt.conf
fi
if ! command -v plymouth >/dev/null; then
  echo "boot: plymouth is not installed; the computer starts with text"
  if rooms_encrypted; then
    sudo mkinitcpio -P >/dev/null 2>&1 || { echo "boot: the initramfs could not be rebuilt" >&2; exit 1; }
    [[ -n "$(rooms_current)" ]] && sudo takumi room kernel-sync
  fi
  exit 0
fi
theme=/usr/share/plymouth/themes/takumi
sudo install -d "$theme"
sudo install -m644 "$TAKUMI_PATH"/default/plymouth/takumi/* "$theme/"                      # /usr/share/plymouth/themes/takumi/*
printf '[Daemon]\nTheme=takumi\nShowDelay=0\nDeviceTimeout=8\n' | sudo tee /etc/plymouth/plymouthd.conf >/dev/null   # /etc/plymouth/plymouthd.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/mkinitcpio.conf.d/takumi-plymouth.conf" /etc/mkinitcpio.conf.d/takumi-plymouth.conf

# Quiet: the splash instead of kernel and service messages; a serial console, when there is one, still gets them.
# The text console's black is the splash's night (#0b0f14), so the moment between the splash and the login
# screen, when the console shows, stays the same dark instead of flashing black. And the console is a plain
# terminal to systemd (systemd.tty.term.console, see kernel-command-line(7)): it is sent no escape codes and
# asked nothing, so no step of the start waits on an answer the splash is holding.
cmdline=/etc/kernel/cmdline
if [[ -s "$cmdline" ]]; then
  for opt in quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto vt.global_cursor_default=0 plymouth.ignore-serial-consoles \
             vt.default_red=11 vt.default_grn=15 vt.default_blu=20 systemd.tty.term.console=dumb zswap.enabled=0; do
    grep -qE "(^| )$opt( |$)" "$cmdline" || sudo sed -i "s/[[:space:]]*\$/ $opt/" "$cmdline"   # /etc/kernel/cmdline
  done
fi

# No menu: systemd-boot starts the default at once; holding Space while it starts shows the rooms.
esp=$(rooms_esp || true)
if [[ -n "$esp" && -f "$esp/loader/loader.conf" ]]; then
  if grep -q '^timeout' "$esp/loader/loader.conf"; then sudo sed -i 's/^timeout.*/timeout 0/' "$esp/loader/loader.conf"   # <esp>/loader/loader.conf
  else echo 'timeout 0' | sudo tee -a "$esp/loader/loader.conf" >/dev/null; fi                                            # <esp>/loader/loader.conf
fi

sudo mkinitcpio -P >/dev/null 2>&1 || { echo "boot: the initramfs could not be rebuilt" >&2; exit 1; }
# The running room's boot entry gets the new initramfs and options (in an install's chroot too).
[[ -n "$(rooms_current)" ]] && sudo takumi room kernel-sync
echo "boot: Takumi's splash, no menu, quiet"
