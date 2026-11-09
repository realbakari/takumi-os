#!/usr/bin/env bash
# Migration: two more right-click scripts in Files (right-click selected files › Scripts): "Make smaller to send"
# runs takumi share shrink with them, and "Write to a USB stick" takumi drive write with a disk image. Written the
# way "Send to…" is (lib/share.sh share_script); one already there is written again, since only Takumi writes them.
set -euo pipefail
for l in /usr/share/takumi/lib "$(dirname "$(readlink -f "$0")")/../lib"; do [[ -f "$l/share.sh" ]] && { . "$l/share.sh"; break; }; done
declare -F share_script >/dev/null || exit 0
share_script "Make smaller to send" takumi share shrink
share_script "Write to a USB stick" takumi drive write
