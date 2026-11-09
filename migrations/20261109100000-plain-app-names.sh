#!/usr/bin/env bash
# Migration: two apps Takumi ships go by what they are, not by their program's name: Foot is Terminal and
# btop++ is System monitor, in the Palette, the row of apps, the grid of every app and on their windows. An
# entry in the home's applications folder takes the place of the package's, the rule every desktop follows
# (https://specifications.freedesktop.org/desktop-entry-spec/latest/). One you already have is left alone.
set -euo pipefail
d="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$d"
if [[ ! -e "$d/foot.desktop" ]]; then
  cat > "$d/foot.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Terminal
GenericName=Terminal
Comment=Type commands; nothing everyday needs it
Exec=foot
Icon=foot
Terminal=false
Categories=System;TerminalEmulator;
Keywords=shell;prompt;command;commandline;foot;console;
EOF
fi
if [[ ! -e "$d/btop.desktop" ]]; then
  cat > "$d/btop.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=System monitor
GenericName=System Monitor
Comment=What is using the processor, memory, disks and network, and which apps
Exec=btop
Icon=btop
Terminal=true
Categories=System;Monitor;ConsoleOnly;
Keywords=system;process;task;activity;btop;
EOF
fi
