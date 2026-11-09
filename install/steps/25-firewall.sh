#!/usr/bin/env bash
set -euo pipefail
# The firewall (docs/firewall.md): connections other devices start are turned away, and everything this computer
# starts goes out, as on a Mac or a Windows PC. ufw keeps these settings in its own files, which have no folder for
# extras, so this step sets them with ufw itself and says what it set. Safe to run again. In the installer's chroot
# nothing is loaded into the running kernel: ufw is set to start with the computer instead.
. "$TAKUMI_PATH/lib/firewall.sh"
if ! command -v ufw >/dev/null; then echo "firewall: ufw is not installed; this computer has no firewall"; exit 0; fi
sudo install -Dm644 "$TAKUMI_PATH/etc/ufw/applications.d/takumi" "$firewall_etc/ufw/applications.d/takumi"   # /etc/ufw/applications.d/takumi
sudo ufw default deny incoming >/dev/null    # /etc/default/ufw
sudo ufw default allow outgoing >/dev/null   # /etc/default/ufw
echo "firewall: connections other devices start are turned away, everything this computer starts goes out (ufw: deny incoming, allow outgoing)"
# A computer whose SSH server is already on stays reachable over SSH, or turning the firewall on would lock out
# whoever looks after it from elsewhere.
if firewall_ssh_server_on; then
  if sudo ufw allow SSH >/dev/null; then   # /etc/ufw/user.rules, /etc/ufw/user6.rules
    echo "firewall: SSH is let in, because this computer's SSH server is on"
  else
    echo "firewall: left off, because this computer's SSH server is on and SSH could not be let in"; exit 0
  fi
fi
if [[ ! -f "$firewall_units/ufw.service" ]]; then echo "firewall: left off, because ufw has no service here to start it with the computer"; exit 0; fi
# Decided from files: in the installer's chroot systemctl cannot talk to a manager, and enable is all it can do.
sudo systemctl enable ufw.service >/dev/null 2>&1 ||   # /etc/systemd/system/multi-user.target.wants/ufw.service
  { echo "firewall: left off, because ufw.service could not be enabled"; exit 0; }
if [[ "${TAKUMI_IN_CHROOT:-}" == 1 ]] || sudo systemd-detect-virt --chroot --quiet 2>/dev/null; then   # reads /proc/1/root, writes nothing
  sudo sed -i 's/^ENABLED=.*/ENABLED=yes/' "$firewall_etc/ufw/ufw.conf"   # /etc/ufw/ufw.conf
  echo "firewall: on from the first start"
else
  sudo ufw --force enable >/dev/null   # /etc/ufw/ufw.conf, and the rules, now
  echo "firewall: on"
fi
sudo takumi firewall apply note   # /etc/takumi/firewall
