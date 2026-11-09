#!/usr/bin/env bash
set -euo pipefail
sudo install -Dm644 "$TAKUMI_PATH/default/wayland-sessions/takumi.desktop" /usr/share/wayland-sessions/takumi.desktop
sudo install -Dm755 "$TAKUMI_PATH/default/takumi-session"                 /usr/bin/takumi-session
for u in "$TAKUMI_PATH"/default/systemd/user/*; do sudo install -Dm644 "$u" "/usr/lib/systemd/user/$(basename "$u")"; done
# The login screen: greetd with Takumi's greeter, unless another login manager is already in charge.
. "$TAKUMI_PATH/lib/rooms.sh"
# One password when the disk is encrypted: it was opened with its owner's password a moment ago, so the
# first session since the computer started opens without asking again (greetd's initial_session runs once per
# start; docs/encryption.md). After a logout, the login screen asks.
greetd_cfg=$(cat "$TAKUMI_PATH/default/greetd/config.toml")
owner=$(awk -F: '$3 >= 1000 && $3 < 60000 && $6 ~ /^\/home\// { print $1; exit }' /etc/passwd)
if rooms_encrypted && [[ -n "$owner" ]]; then
  greetd_cfg+=$'\n\n[initial_session]\ncommand = "takumi session start"\nuser = "'"$owner"$'"\n'
fi
sudo install -d /usr/share/takumi/greetd
printf '%s\n' "$greetd_cfg" | sudo tee /usr/share/takumi/greetd/config.toml >/dev/null   # /usr/share/takumi/greetd/config.toml
sudo install -Dm644 "$TAKUMI_PATH/default/systemd/system/greetd.service.d/takumi.conf" /etc/systemd/system/greetd.service.d/takumi.conf
sudo install -Dm644 "$TAKUMI_PATH/shell/greeter.qml" /usr/share/takumi/shell/greeter.qml
# Decided from files, not from systemctl's view: the installer runs in a chroot, where systemctl cannot
# list units, and asking it once made every fresh install boot to a text console.
dm=/etc/systemd/system/display-manager.service
if [[ -e "$dm" && "$(readlink -f "$dm")" != */greetd.service ]]; then
  echo "login: another login manager is in charge ($(basename "$(readlink -f "$dm")")); pick the Takumi session there"
elif [[ -f /usr/lib/systemd/system/greetd.service ]]; then
  sudo systemctl enable greetd.service   # /etc/systemd/system/display-manager.service
  [[ "$(readlink -f "$dm")" == */greetd.service ]] || { echo "login: greetd could not be enabled" >&2; exit 1; }
  sudo install -d -m 0700 -o greeter -g greeter /var/cache/takumi/greeter   # /var/cache/takumi/greeter: its caches, kept between boots
  echo "login: the Takumi login screen is on"
else
  echo "login: greetd is not installed; the computer starts to a text login" >&2
  exit 1
fi
