#!/usr/bin/env bash
# Migration: the keys and rules of docs/notifications.md and docs/accessibility.md in Takumi's own
# defaults.kdl: notices from the keyboard, floating windows, two screens, the recent-windows switcher on
# Super+Tab and Alt+Tab, picture in picture, the screen reader keys and the accessibility file. Each piece
# is added only where it is missing, and a bind only while its key is free, so a key you took stays yours.
# The file is copied aside first. `takumi settings reset` gives the same file whole.
set -euo pipefail
f="$HOME/.config/niri/takumi/defaults.kdl"
[[ -f "$f" ]] || exit 0

# The binds, one per line: the key, a tab, the line as defaults.kdl has it. Each block is a function: bash 3.2
# misreads a heredoc inside $( ) that holds a backquote.
binds_block() { cat <<'BINDS'
Mod+Shift+Space	    Mod+Shift+Space hotkey-overlay-title="Act on the notice" { spawn "qs" "-c" "takumi" "ipc" "call" "notices" "act"; }
Mod+Escape	    Mod+Escape hotkey-overlay-title="Put every notice away" { spawn "qs" "-c" "takumi" "ipc" "call" "notices" "clear"; }
Mod+Ctrl+Return	    Mod+Ctrl+Return allow-when-locked=true hotkey-overlay-title="Screen reader on or off" { spawn "takumi" "switch" "reader"; }
Mod+F5	    Mod+F5 allow-when-locked=true { spawn "takumi" "switch" "reader"; }
Mod+U	    Mod+U hotkey-overlay-title="Accessibility" { spawn "qs" "-c" "takumi" "ipc" "call" "core" "search" "accessibility"; }
Mod+Ctrl+Up	    Mod+Ctrl+Up hotkey-overlay-title="Float the window, or put it back" { toggle-window-floating; }
Mod+Ctrl+Down	    Mod+Ctrl+Down { switch-focus-between-floating-and-tiling; }
Mod+Ctrl+Left	    Mod+Ctrl+Left        { focus-monitor-left; }
Mod+Ctrl+Right	    Mod+Ctrl+Right       { focus-monitor-right; }
Mod+Shift+Ctrl+Left	    Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
Mod+Shift+Ctrl+Right	    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
BINDS
}
recent_block() { cat <<'RECENT'
// Super+Tab (or Alt+Tab) goes back to the last window; keep holding Super (or Alt) and press Tab again to
// choose among the recent ones, with Shift to go back. Super+` does the same among one app's windows.
recent-windows {
    binds {
        Mod+Tab         { next-window; }
        Mod+Shift+Tab   { previous-window; }
        Mod+grave       { next-window filter="app-id"; }
        Mod+Shift+grave { previous-window filter="app-id"; }
        Alt+Tab         { next-window; }
        Alt+Shift+Tab   { previous-window; }
        Alt+grave       { next-window filter="app-id"; }
        Alt+Shift+grave { previous-window filter="app-id"; }
    }
}
RECENT
}
pip_block() { cat <<'PIP'
// Picture in picture: a video kept small in the bottom-right corner, above the strip, without taking the
// keyboard. Firefox titles that window "Picture-in-Picture"; Chromium and the browsers built on it,
// "Picture in picture".
window-rule {
    match title=r#"^(?i)picture[- ]in[- ]picture$"#
    open-floating true
    open-focused false
    default-floating-position x=24 y=24 relative-to="bottom-right"
    default-column-width { fixed 480; }
    default-window-height { fixed 270; }
}
PIP
}
access_block() { cat <<'ACCESS'
// Your accessibility choices from the Core: the pointer's size and the screen reader at login, written by
// takumi switch pointer and takumi switch reader (docs/accessibility.md). Missing until you choose one.
include optional=true "accessibility.kdl"
ACCESS
}

binds=$(binds_block); recent=$(recent_block); pip=$(pip_block); access=$(access_block)
want_recent=yes; grep -qE '^[[:space:]]*recent-windows[[:space:]]*\{' "$f" && want_recent=no
want_pip=yes; grep -qiE 'picture.in.picture' "$f" && want_pip=no
want_access=yes; grep -qF '"accessibility.kdl"' "$f" && want_access=no

# One awk pass: keys are compared as niri reads them (any order, any case, Control for Ctrl), only top-level
# binds count, and strings and comments never move the brace count.
out=$(BINDS="$binds" RECENT="$recent" PIP="$pip" ACCESS="$access" awk -v want_recent="$want_recent" -v want_pip="$want_pip" -v want_access="$want_access" '
  function norm(k,   n, p, i, j, t, s) {
    n = split(tolower(k), p, "+")
    for (i = 1; i <= n; i++) { if (p[i] == "control") p[i] = "ctrl"; if (p[i] == "win") p[i] = "super" }
    for (i = 2; i <= n; i++) { t = p[i]; j = i - 1; while (j > 0 && p[j] > t) { p[j + 1] = p[j]; j-- } p[j + 1] = t }
    s = p[1]; for (i = 2; i <= n; i++) s = s "+" p[i]
    return s
  }
  function bare(s) { gsub(/"[^"]*"/, "", s); sub(/\/\/.*/, "", s); return s }
  function count(s, c,   n) { n = gsub(c, "", s); return n }
  BEGIN {
    nb = split(ENVIRON["BINDS"], blines, "\n")
    for (i = 1; i <= nb; i++) { split(blines[i], kv, "\t"); bname[i] = kv[1]; bkey[i] = norm(kv[1]); bline[i] = substr(blines[i], index(blines[i], "\t") + 1) }
  }
  {
    line = $0; s = bare(line)
    opens = count(s, "[{]"); closes = count(s, "[}]")
    if (depth == 0 && s ~ /^[[:space:]]*binds[[:space:]]*[{]/) {
      if (want_recent == "yes") { print ENVIRON["RECENT"]; print ""; recent_done = 1 }
      if (want_pip == "yes") { print ENVIRON["PIP"]; print ""; pip_done = 1 }
      inbinds = 1; print line; depth += opens - closes; next
    }
    if (inbinds && depth == 1) {
      if (match(s, /^[[:space:]]*[^[:space:]{]+/)) {
        k = substr(s, RSTART, RLENGTH); gsub(/[[:space:]]/, "", k)
        t = line; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t); have[norm(k)] = t
        # The old Super+Tab gives way to the switcher, whose binds rank below ordinary ones.
        if (want_recent == "yes" && norm(k) == "mod+tab" && line ~ /focus-window-previous/) { depth += opens - closes; next }
      }
      if (closes > opens && depth + opens - closes == 0) {
        for (i = 1; i <= nb; i++) {
          t = bline[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
          if (!(bkey[i] in have)) print bline[i]; else if (have[bkey[i]] != t) kept = kept " " bname[i]
        }
        binds_done = 1; inbinds = 0
      }
    }
    print line
    depth += opens - closes
    if (want_access == "yes" && !access_done && line ~ /niri-theme\.kdl"/) { print ""; print ENVIRON["ACCESS"]; access_done = 1 }
  }
  END {
    if (want_access == "yes" && !access_done) { print ""; print ENVIRON["ACCESS"] }
    if (want_recent == "yes" && !recent_done) { print ""; print ENVIRON["RECENT"] }
    if (want_pip == "yes" && !pip_done) { print ""; print ENVIRON["PIP"] }
    if (!binds_done) { print ""; print "binds {"; for (i = 1; i <= nb; i++) print bline[i]; print "}" }
    if (kept != "") print "kept your own bind for:" kept > "/dev/stderr"
  }' "$f")

[[ "$out" == "$(cat "$f")" ]] && exit 0
cp "$f" "$f.bak-$(date +%Y%m%d%H%M%S)"
printf '%s\n' "$out" > "$f.new" && mv "$f.new" "$f"
