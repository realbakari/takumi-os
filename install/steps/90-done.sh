#!/usr/bin/env bash
set -euo pipefail
# Say plainly whether updates can be undone on this computer (step 80 wrote it to the log).
rooms=$(grep '^rooms: ' "${TAKUMI_LOG:-/dev/null}" 2>/dev/null | tail -n 2 || true)
cat <<'MSG'

  Takumi OS is installed.

  Log out, pick the "Takumi" session, and press Super+Space.
  Read ~/.local/share/takumi/guide/your-first-hour.md for your first hour.

MSG
[[ -n "$rooms" ]] && printf '  %s\n\n' "${rooms//$'\n'/$'\n'  }"
