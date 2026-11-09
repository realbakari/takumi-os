#!/usr/bin/env bash
set -euo pipefail
[[ -f /etc/arch-release ]] || { echo "not Arch"; exit 1; }
[[ $EUID -ne 0 ]] || { echo "run as a user"; exit 1; }
# The setup disc installs from its own packages (TAKUMI_OFFLINE=1, commands/setup/install).
[[ "${TAKUMI_OFFLINE:-}" == 1 ]] || curl -fsS --max-time 10 https://archlinux.org >/dev/null || { echo "no network"; exit 1; }
free_gib=$(( $(df --output=avail / | tail -1) / 1048576 ))
(( free_gib >= 10 )) || { echo "need 10 GiB free on /, have $free_gib"; exit 1; }
sudo -v   # one prompt; later steps reuse the timestamp (no prompt in the VM: NOPASSWD)
