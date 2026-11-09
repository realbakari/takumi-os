#!/usr/bin/env bash
set -euo pipefail
# Drop-ins we own outright. Each path is listed so the step reads as a manifest.
sudo install -Dm644 "$TAKUMI_PATH/etc/keyd/default.conf"            /etc/keyd/default.conf
sudo install -Dm644 "$TAKUMI_PATH/default/keyd/default.conf"        /usr/share/takumi/default/keyd/default.conf
sudo install -Dm440 "$TAKUMI_PATH/etc/sudoers.d/takumi"             /etc/sudoers.d/takumi
sudo install -Dm644 "$TAKUMI_PATH/etc/sysctl.d/90-takumi.conf"      /etc/sysctl.d/90-takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/udev/rules.d/60-takumi-iosched.rules" /etc/udev/rules.d/60-takumi-iosched.rules
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/system/plocate-updatedb.timer.d/takumi.conf" /etc/systemd/system/plocate-updatedb.timer.d/takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/pacman.d/hooks/takumi-room-notice.hook" /etc/pacman.d/hooks/takumi-room-notice.hook
sudo install -Dm644 "$TAKUMI_PATH/etc/pacman.d/hooks/95-takumi-room-kernel.hook" /etc/pacman.d/hooks/95-takumi-room-kernel.hook
sudo install -Dm644 "$TAKUMI_PATH/etc/tmpfiles.d/systemd-nspawn.conf"  /etc/tmpfiles.d/systemd-nspawn.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/tmpfiles.d/portables.conf"       /etc/tmpfiles.d/portables.conf
sudo install -Dm644 "$TAKUMI_PATH/default/tmpfiles/takumi.conf"         /usr/lib/tmpfiles.d/takumi.conf
for l in "$TAKUMI_PATH"/lib/*.sh; do sudo install -Dm644 "$l" "/usr/share/takumi/lib/$(basename "$l")"; done   # rooms.sh, wifi.sh
sudo install -Dm644 "$TAKUMI_PATH/install/shelf.tsv"                   /usr/share/takumi/shelf.tsv
for u in "$TAKUMI_PATH"/default/systemd/system/*.service; do sudo install -Dm644 "$u" "/usr/lib/systemd/system/$(basename "$u")"; done
[[ -d /run/systemd/system ]] && sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/takumi.conf >/dev/null 2>&1 || true
sudo install -Dm644 "$TAKUMI_PATH/etc/zram-generator.conf"          /etc/systemd/zram-generator.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/modules-load.d/takumi-ddc.conf"   /etc/modules-load.d/takumi-ddc.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/system.conf.d/10-takumi.conf"      /etc/systemd/system.conf.d/10-takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/user.conf.d/10-takumi.conf"        /etc/systemd/user.conf.d/10-takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/system/user@.service.d/10-takumi.conf" /etc/systemd/system/user@.service.d/10-takumi.conf
# The desktop survives an app that eats the memory: systemd-oomd stops the app, not the desktop (docs/tuning.md).
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/oomd.conf.d/10-takumi.conf"        /etc/systemd/oomd.conf.d/10-takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/etc/systemd/user/app.slice.d/10-takumi.conf"   /etc/systemd/user/app.slice.d/10-takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/default/pam/takumi-lock"         /etc/pam.d/takumi-lock
sudo mkdir -p /usr/share/takumi
sudo rsync -a --delete "$TAKUMI_PATH/themes/"         /usr/share/takumi/themes/
sudo rsync -a --delete "$TAKUMI_PATH/default/app-colours/" /usr/share/takumi/app-colours/
sudo rm -rf /usr/share/takumi/default/themed   # /usr/share/takumi/default/themed: where the templates lived before app-colours
sudo rsync -a --delete "$TAKUMI_PATH/default/palette/" /usr/share/takumi/default/palette/   # /usr/share/takumi/default/palette/emoji.tsv
sudo rsync -a --delete "$TAKUMI_PATH/default/coding-agents/" /usr/share/takumi/coding-agents/   # /usr/share/takumi/coding-agents/takumi/SKILL.md
# Sound (docs/sound.md): Bluetooth headsets connect and take the sound; the two qualities; speaker tunings.
sudo install -Dm644 "$TAKUMI_PATH/default/wireplumber/wireplumber.conf.d/60-takumi-bluetooth.conf" /usr/share/wireplumber/wireplumber.conf.d/60-takumi-bluetooth.conf
sudo install -Dm644 "$TAKUMI_PATH/default/pipewire/pipewire-pulse.conf.d/60-takumi-new-devices.conf" /usr/share/pipewire/pipewire-pulse.conf.d/60-takumi-new-devices.conf
sudo install -Dm644 "$TAKUMI_PATH/default/pipewire/studio.conf"   /usr/share/takumi/default/pipewire/studio.conf
sudo install -Dm644 "$TAKUMI_PATH/default/pipewire/balanced.conf" /usr/share/takumi/default/pipewire/balanced.conf
sudo rsync -a --delete "$TAKUMI_PATH/default/audio/" /usr/share/takumi/default/audio/   # /usr/share/takumi/default/audio/tunings/<name>.conf
# This computer's fixes, as data (docs/hardware.md): every update applies them to the room it builds.
sudo rsync -a --delete "$TAKUMI_PATH/default/hardware/" /usr/share/takumi/default/hardware/   # /usr/share/takumi/default/hardware/*.toml, read by takumi hardware
# Hibernating with an update waiting wakes the system that hibernated (docs/power.md).
sudo install -Dm755 "$TAKUMI_PATH/default/systemd/system-sleep/takumi-rooms" /usr/lib/systemd/system-sleep/takumi-rooms   # /usr/lib/systemd/system-sleep/takumi-rooms
# Printers on the network are found by their .local names (docs/printing.md).
grep -q mdns_minimal /etc/nsswitch.conf || sudo sed -i '/^hosts:/ s/ resolve/ mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf   # /etc/nsswitch.conf
# The time zone follows a new network when you asked for that (docs/time.md).
sudo install -Dm755 "$TAKUMI_PATH/default/networkmanager/dispatcher.d/90-takumi-clock" /usr/lib/NetworkManager/dispatcher.d/90-takumi-clock   # /usr/lib/NetworkManager/dispatcher.d/90-takumi-clock
# Updates prepared on the charger start their build through polkit, without a password (docs/updates.md).
sudo install -Dm644 "$TAKUMI_PATH/etc/polkit-1/rules.d/50-takumi-update.rules" /etc/polkit-1/rules.d/50-takumi-update.rules
# Allowing a Thunderbolt dock asks for the password in the Core, never silently (docs/hardware.md).
sudo install -Dm644 "$TAKUMI_PATH/etc/polkit-1/rules.d/50-takumi-bolt.rules" /etc/polkit-1/rules.d/50-takumi-bolt.rules
# Steady Wi-Fi: its power saving off on the charger, on on battery (docs/wifi.md); udev runs it when the charger
# comes or goes (default/udev/80-takumi-wifi-power.rules, below).
sudo install -Dm755 "$TAKUMI_PATH/default/networkmanager/dispatcher.d/80-takumi-wifi-power" /usr/lib/NetworkManager/dispatcher.d/80-takumi-wifi-power   # /usr/lib/NetworkManager/dispatcher.d/80-takumi-wifi-power
# The microphone key's light (docs/laptop-keys.md), and the Wi-Fi's power saving following the charger (docs/wifi.md).
for r in "$TAKUMI_PATH"/default/udev/*.rules; do sudo install -Dm644 "$r" "/usr/lib/udev/rules.d/$(basename "$r")"; done   # /usr/lib/udev/rules.d/70-takumi-micmute.rules, 80-takumi-wifi-power.rules
if [[ -d /run/systemd/system ]]; then
  sudo udevadm control --reload || true
  sudo udevadm trigger --subsystem-match=leds --action=add || true
  sudo udevadm trigger --subsystem-match=power_supply --action=change || true
fi
sudo rsync -a --delete "$TAKUMI_PATH/migrations/"     /usr/share/takumi/migrations/
sudo rsync -a --delete "$TAKUMI_PATH/install/packages/" /usr/share/takumi/packages/   # the lists a room upgrade reads
sudo rsync -a --delete "$TAKUMI_PATH/config/"         /usr/share/takumi/config/
sudo rsync -a --delete "$TAKUMI_PATH/shell/"          /usr/share/takumi/shell/
sudo install -m644 "$TAKUMI_PATH/version" /usr/share/takumi/version
sudo install -m755 "$TAKUMI_PATH/bin/takumi" /usr/bin/takumi
sudo ln -sf takumi /usr/bin/tk
sudo mkdir -p /usr/lib/takumi
sudo rsync -a --delete "$TAKUMI_PATH/commands/" /usr/lib/takumi/commands/   # /usr/lib/takumi/commands/<group>/<name>
# Commands lived in /usr/bin as takumi-<group>-<name> before; those copies go. takumi-session is not a command.
for old in /usr/bin/takumi-*; do
  if [[ -f "$old" && "$old" != /usr/bin/takumi-session ]]; then sudo rm -f -- "$old"; fi   # /usr/bin/takumi-<group>-<name>
done
sudo systemctl enable keyd NetworkManager bluetooth systemd-timesyncd
# Printing, network printers and power profiles, when their packages are present. Decided from files:
# in the installer's chroot systemctl cannot list units, and asking it left these off on every new install.
for u in cups.socket avahi-daemon.service power-profiles-daemon.service rtkit-daemon.service NetworkManager-dispatcher.service takumi-room-carry.service systemd-oomd.service; do
  [[ -f "/usr/lib/systemd/system/$u" ]] && sudo systemctl enable "$u" >/dev/null 2>&1 || true   # /etc/systemd/system/*.wants/$u
done
[[ -d /run/systemd/system ]] && sudo systemctl start keyd NetworkManager bluetooth systemd-timesyncd || true   # not in a chroot
[[ -d /run/systemd/system && -f /usr/lib/systemd/system/systemd-oomd.service ]] && sudo systemctl start systemd-oomd.service || true
sudo systemctl daemon-reload
