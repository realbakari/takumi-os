#!/usr/bin/env bash
# What every Palette provider shares (commands/palette/*). Sourced, not run; bash 3.2.

# Rows on stdin, the query in $1: keeps a row when every word of the query, hyphens ignored, is in its
# title, subtitle or keywords. "wifi off" finds "Turn Wi-Fi off". An empty query keeps every row.
palette_filter() {
  if [[ -z "${1:-}" ]]; then cat; return; fi
  jq -c --arg q "$1" '
    ($q | ascii_downcase | gsub("-"; "") | split(" ") | map(select(length > 0))) as $words
    | select((.title + " " + (.subtitle // "") + " " + (.keywords // "")) | ascii_downcase | gsub("-"; "") as $t
             | all($words[]; . as $w | $t | contains($w)))'
}

# palette_short <query>: true for a query too short to search settings by (under three letters), so a
# provider can stay quiet while someone types an app's first letters.
palette_short() { local q; q=$(printf '%s' "${1:-}" | tr -d '[:space:]'); (( ${#q} < 3 )); }
