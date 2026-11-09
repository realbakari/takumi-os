#!/usr/bin/env bash
# Takumi updates: why one failed, in words, and the packages Takumi's lists name. Sourced, never run; runs on
# bash 3.2. See docs/updates.md.

TAKUMI_UPDATE_LIB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# update_why [file...]: why an update failed, read from pacman's own words in its output (the files, or stdin).
# Prints one line, kind<TAB>sentence<TAB>next step, or nothing and returns 1 when the cause is not one Takumi
# knows. The kinds: lock, space, keyring, damaged, files, deps, network. The strings are pacman's (libalpm's
# error strings and pacman's callbacks, as printed in English: commands that call this run pacman with
# LC_ALL=C or read a log that did) and libcurl's.
update_why() {
  local text line detail
  text=$(cat "$@" 2>/dev/null) || true
  [[ -n "$text" ]] || return 1
  if grep -qE 'unable to lock database|could not lock database' <<< "$text"; then
    printf 'lock\t%s\t%s\n' "Another program is installing software right now." "Wait for it to finish, then update again"
  elif grep -qE 'not enough free disk space|too full: [0-9]+ blocks needed|No space left on device|GiB free on /, need' <<< "$text"; then
    printf 'space\t%s\t%s\n' "There is not enough space on the disk for the update." "Free up space, then update again"
  elif grep -qE 'is unknown trust|is marginal trust|signature from .* is invalid|\(PGP signature\)|required key missing from keyring|could not be looked up remotely|key ".*" is unknown|key ".*" is disabled' <<< "$text" \
       && ! grep -qE 'invalid or corrupted database \(PGP signature\)' <<< "$text"; then
    printf 'keyring\t%s\t%s\n' "The keys that check the downloads are out of date." "Try again: the keys are renewed first"
  elif grep -qE 'invalid or corrupted (package|database)' <<< "$text"; then
    printf 'damaged\t%s\t%s\n' "A download arrived damaged and was thrown away." "Try again"
  elif grep -qE 'exists in filesystem|exists in both' <<< "$text"; then
    line=$(grep -m 1 -E 'exists in filesystem|exists in both' <<< "$text")
    detail=$(sed -E -e 's/^[^:]*: //' -e 's/ exists in (filesystem|both).*//' <<< "$line")
    printf 'files\t%s\t%s\n' "The update would overwrite ${detail:-a file}, which is already on the disk." "Try again in a day or two: Arch usually fixes this quickly"
  elif grep -qE 'breaks dependency|unable to satisfy dependency|could not satisfy dependencies|are in conflict|conflicting dependencies' <<< "$text"; then
    line=$(grep -m 1 -E 'breaks dependency|unable to satisfy dependency|are in conflict' <<< "$text" || true)
    detail=$(sed -E -e 's/^:: //' -e 's/^error: //' <<< "$line")
    printf 'deps\t%s\t%s\n' "Some packages in the update do not fit together yet${detail:+ ($detail)}." "Try again in a day or two: Arch usually fixes this quickly"
  elif grep -qE 'failed retrieving file|Could not resolve host|failed to retrieve some files|failed to synchronize all databases|Failed to connect to|Connection timed out|Operation too slow|Resolving timed out' <<< "$text"; then
    printf 'network\t%s\t%s\n' "The download servers did not answer." "Check the internet connection, then try again"
  else
    return 1
  fi
}

# update_retryable <kind>: a failure that trying again can get past.
update_retryable() { case "$1" in keyring|damaged|network) return 0 ;; *) return 1 ;; esac; }

# update_listed: every package Takumi's lists name, one a line. The installer puts the lists in
# /usr/share/takumi/packages; a checkout keeps them in install/packages.
update_listed() {
  local d
  for d in /usr/share/takumi/packages "$TAKUMI_UPDATE_LIB/../install/packages"; do
    [[ -f "$d/base.txt" ]] || continue
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$d"/base.txt "$d"/desktop.txt 2>/dev/null | awk '{print $1}' | sort -u
    return 0
  done
  return 1
}

# update_unlisted: the package names on stdin that Takumi's lists do not name. Packages nothing needs any more
# (pacman -Qdtq) pass through it before they are removed: a listed package first installed as another's
# dependency stays a dependency, and must never go.
update_unlisted() {
  local listed names
  names=$(cat)
  [[ -n "$names" ]] || return 0
  listed=$(update_listed || true)
  if [[ -n "$listed" ]]; then grep -vxF -- "$listed" <<< "$names" || true; else printf '%s\n' "$names"; fi
}

# update_human <KiB>: "4.2 GB", "310 MB", "under 1 MB".
update_human() {
  awk -v k="${1:-0}" 'BEGIN { if (k >= 1048576) printf "%.1f GB\n", k / 1048576; else if (k >= 1024) printf "%d MB\n", k / 1024; else print "under 1 MB" }'
}
