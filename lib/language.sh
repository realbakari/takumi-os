#!/usr/bin/env bash
# The desktop's language and formats, for commands/language/* and the Palette's language rows. Sourced, not run;
# bash 3.2, as the tests do on macOS with a fake glibc. See docs/languages.md.
#
# A language is one of glibc's locales ("de_DE.UTF-8"), named from glibc's own sources: in English from
# LC_IDENTIFICATION, in its own words from LC_ADDRESS. systemd-localed keeps the choice in /etc/locale.conf: LANG,
# and the formats (dates, numbers, money, paper, units) when they are set apart from it.

language_i18n=${TAKUMI_I18N:-/usr/share/i18n}
language_conf=${TAKUMI_LOCALE_CONF:-/etc/locale.conf}
language_gen=${TAKUMI_LOCALE_GEN:-/etc/locale.gen}
language_cache="${XDG_CACHE_HOME:-$HOME/.cache}/takumi/languages-1.tsv"
LANGUAGE_FORMATS="LC_TIME LC_NUMERIC LC_MONETARY LC_PAPER LC_MEASUREMENT"
# The languages "language" lists before any is typed, most spoken among people leaving a Mac or Windows first.
LANGUAGE_POPULAR="en_US.UTF-8 en_GB.UTF-8 es_ES.UTF-8 es_MX.UTF-8 pt_BR.UTF-8 pt_PT.UTF-8 fr_FR.UTF-8 de_DE.UTF-8 it_IT.UTF-8 nl_NL.UTF-8 pl_PL.UTF-8 sv_SE.UTF-8 tr_TR.UTF-8 ru_RU.UTF-8 uk_UA.UTF-8 ar_SA.UTF-8 hi_IN ja_JP.UTF-8 ko_KR.UTF-8 zh_CN.UTF-8 zh_TW.UTF-8"

# language_supported: every UTF-8 locale glibc can make, as /etc/locale.gen names it ("de_DE.UTF-8", "hi_IN").
# Reads SUPPORTED as glibc installs it ("de_DE.UTF-8 UTF-8") and as its sources write it ("de_DE.UTF-8/UTF-8 \").
language_supported() {
  [[ -r "$language_i18n/SUPPORTED" ]] || return 0
  sed 's/[[:space:]]*\\$//; s|/| |' "$language_i18n/SUPPORTED" |
    awk '$1 !~ /^#/ && $1 !~ /=/ && $2 == "UTF-8" && $1 !~ /^(C|POSIX)([.@]|$)/ { print $1 }'
}

# language_build: the table below, from glibc's locale sources. <Uxxxx> escapes become the letters they name.
language_build() {
  local codes
  codes=$(language_supported)
  [[ -n "$codes" ]] || return 0
  while IFS= read -r c; do printf '%s\t%s\n' "$c" "$language_i18n/locales/$(printf '%s' "$c" | sed 's/\.[^@]*//')"; done <<< "$codes" |
  awk -F '\t' '
    function val(s) { sub(/^[^"]*"/, "", s); sub(/".*$/, "", s); return s }
    {
      code = $1; f = $2; sect = ""; lang = ""; terr = ""; nlang = ""; nterr = ""
      while ((getline line < f) > 0) {
        if (line ~ /^LC_[A-Z]+[ \t]*$/) { sect = line; sub(/[ \t]+$/, "", sect); continue }
        if (line ~ /^END LC_/) { sect = ""; continue }
        split(line, w, /[ \t]+/)
        if (sect == "LC_IDENTIFICATION" && w[1] == "language") lang = val(line)
        else if (sect == "LC_IDENTIFICATION" && w[1] == "territory") terr = val(line)
        else if (sect == "LC_ADDRESS" && w[1] == "lang_name") nlang = val(line)
        else if (sect == "LC_ADDRESS" && w[1] == "country_name") nterr = val(line)
      }
      close(f)
      print code "\t" lang "\t" terr "\t" nlang "\t" nterr
    }' | sed 's/<U\([0-9A-Fa-f]\{4\}\)>/\\u\1/g' |
  POP=$LANGUAGE_POPULAR jq -Rr '
    def dec: (try ("\"" + . + "\"" | fromjson) catch .);
    def short: if . == "United States" then "US" elif . == "United Kingdom" then "UK" else . end;
    (env.POP | split(" ")) as $pop
    | split("\t") | .[0] as $code
    | (.[1] | dec | if test(" English$") then "English" else . end) as $lang
    | (.[2] | dec) as $terr | (.[3] | dec) as $nlang | (.[4] | dec) as $nterr
    | ((($code | capture("@(?<m>.+)$") | .m) // "") | if . == "" then "" else (.[0:1] | ascii_upcase) + .[1:] end) as $mod
    | (if $lang == "" then $code else $lang + " (" + ([($terr | short), $mod] | map(select(. != "")) | join(", ")) + ")" end) as $name
    | (if $nlang == "" then "" else $nlang + (if $nterr != "" then " (" + $nterr + ")" else "" end) end) as $own
    | ($pop | index($code)) as $rank
    | [$code, $name, (if $own == $name or $own == ($lang + " (" + $terr + ")") then "" else $own end), $lang, $terr,
       (if $rank then $rank + 1 else 0 end | tostring)] | join("\t")'
}

# language_table: one line per language: code <tab> name in English <tab> its own name ("" when the same)
# <tab> language <tab> territory <tab> its place among the popular ones (0 when not). Built once, kept in ~/.cache.
language_table() {
  if [[ ! -s "$language_cache" || "$language_i18n/SUPPORTED" -nt "$language_cache" ]]; then
    mkdir -p "${language_cache%/*}"
    language_build > "$language_cache.new" && mv "$language_cache.new" "$language_cache"
  fi
  cat "$language_cache" 2>/dev/null || true
}

# language_find <words>: the table's lines whose names or code hold every word, popular ones first, then a
# language in its own country ("de_DE" before "de_AT"), then by name.
language_find() {
  language_table | Q=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]') awk -F '\t' '
    BEGIN { n = split(ENVIRON["Q"], w, " ") }
    { t = tolower($1 " " $2 " " $3 " " $4 " " $5); ok = n > 0
      for (i = 1; i <= n; i++) if (index(t, w[i]) == 0) { ok = 0; break }
      if (!ok) next
      ll = $1; sub(/_.*/, "", ll); cc = $1; sub(/^[^_]*_/, "", cc); sub(/[.@].*/, "", cc)
      print ($6 > 0 ? $6 : (tolower(cc) == ll ? 100 : 200)) "\t" $0 }' | sort -t "$(printf '\t')" -k1,1n -k3,3 | cut -f 2-
}

# language_pick <language|place> <answer>: what an answer names. "one <tab> code <tab> name" when it is clear:
# the only match; a name or code typed whole; for a place, the one in your language; one popular language, or
# one in its own country, called what was typed; one whose language is a word typed. Else "several <tab> some
# names", or "none".
language_pick() {
  language_find "$2" | MODE=$1 Q=$2 NOW=$(language_now) jq -Rrs '
    (env.Q | ascii_downcase | split(" ") | map(select(length > 0))) as $w
    | (env.Q | ascii_downcase | gsub("^ +| +$"; "")) as $whole
    | (env.NOW | split("_")[0]) as $nowll
    | def one: "one\t" + .code + "\t" + .name;
    def known: .rank > 0 or .main;
    split("\n") | map(select(length > 0) | split("\t")
      | {code: .[0], name: .[1], own: .[2], language: (.[3] | ascii_downcase), territory: (.[4] | ascii_downcase), rank: (.[5] | tonumber)}
      | . + {ll: (.code | split("_")[0]), main: ((.code | split("_")[0]) == ((.code | split("_")[1] // "") | split(".")[0] | split("@")[0] | ascii_downcase))})
    | if length == 0 then "none"
      elif length == 1 then .[0] | one
      elif any(.[]; (.name | ascii_downcase) == $whole or (.own | ascii_downcase) == $whole or (.code | ascii_downcase) == $whole) then
        first(.[] | select((.name | ascii_downcase) == $whole or (.own | ascii_downcase) == $whole or (.code | ascii_downcase) == $whole)) | one
      elif env.MODE == "place" and (map(.territory) | unique | length) == 1 and any(.[]; .ll == $nowll) then first(.[] | select(.ll == $nowll)) | one
      elif (map(select(known and (.language == $whole or (env.MODE == "place" and .territory == $whole)))) | length) == 1 then
        first(.[] | select(known and (.language == $whole or (env.MODE == "place" and .territory == $whole)))) | one
      elif (map(select(.language as $l | any($w[]; . == $l))) | length) == 1 then first(.[] | select(.language as $l | any($w[]; . == $l))) | one
      else "several\t" + ((.[0:3] | map(.name) | join(", ")) + (if length > 3 then ", …" else "" end))
      end' 2>/dev/null || echo none
}

# language_resolve <code in any usual spelling>: the code as glibc lists it ("de-de", "de_DE.utf8" and "de" are
# de_DE.UTF-8; "pt" is pt_PT.UTF-8, a language in its own country), or nothing.
language_resolve() {
  local want
  want=$(printf '%s' "$1" | sed 's/^\([A-Za-z]\{2,3\}\)-\([A-Za-z]\{2\}\)/\1_\2/' | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/')
  language_supported | W=$want POP=$LANGUAGE_POPULAR awk '
    { c = tolower($1); gsub(/utf-8/, "utf8", c); base = c; sub(/\.[^@]*/, "", base)
      ll = c; sub(/[_.@].*/, "", ll); cc = c; sub(/^[^_]*_?/, "", cc); sub(/[.@].*/, "", cc)
      if (c == ENVIRON["W"] || base == ENVIRON["W"]) { print $1; found = 1; exit }
      if (ll == ENVIRON["W"]) { if (index(" " ENVIRON["POP"] " ", " " $1 " ") && pop == "") pop = $1; if (cc == ll && own == "") own = $1; if (any == "") any = $1 } }
    END { if (!found) { if (pop != "") print pop; else if (own != "") print own; else if (any != "") print any } }'
}

# language_get <variable>: its value in /etc/locale.conf, or nothing.
language_get() {
  [[ -r "$language_conf" ]] || return 0
  sed -n "s/^$1=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" "$language_conf" | tail -n 1
}
language_now() { local l; l=$(language_get LANG); printf '%s' "${l:-C}"; }
# The formats: the locale LC_TIME names, or the language's own.
language_formats_now() { local f; f=$(language_get LC_TIME); [[ -n "$f" ]] && printf '%s' "$f" || language_now; }

# language_name <code>: "German (Germany)"; English with none chosen; the code for one glibc does not list.
language_name() {
  case "$1" in C|C.*|POSIX|"") printf 'English, none chosen'; return 0 ;; esac
  local n
  n=$(language_table | awk -F '\t' -v c="$1" '$1 == c { print $2; exit }')
  printf '%s' "${n:-$1}"
}
# language_place <code>: its territory, "Germany".
language_place() {
  case "$1" in C|C.*|POSIX|"") printf 'none chosen'; return 0 ;; esac
  local n
  n=$(language_table | awk -F '\t' -v c="$1" '$1 == c { print $5; exit }')
  printf '%s' "${n:-$1}"
}

# language_norm <code>: the spelling `locale -a` uses, "de_de.utf8".
language_norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/'; }
# language_ready <code>: glibc has made it.
language_ready() {
  local have
  have=$(locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/') || true
  [[ $'\n'"$have"$'\n' == *$'\n'"$(language_norm "$1")"$'\n'* ]]
}

# language_gen_with <code>: /etc/locale.gen with the code's line on (uncommented, or added at the end).
language_gen_with() {
  [[ -r "$language_gen" ]] || { printf '%s UTF-8\n' "$1"; return 0; }
  awk -v c="$1" '
    { line = $0; s = line; sub(/^#[ \t]*/, "", s); split(s, f, /[ \t]+/)
      if (f[1] == c && f[2] == "UTF-8") { print s; found = 1; next }
      print line }
    END { if (!found) print c " UTF-8" }' "$language_gen"
}

# language_packs <code>: the language packs Firefox and LibreOffice need to speak it, when they are installed and
# the packs are not: firefox-i18n-de, libreoffice-fresh-pt-br. Only packs the package lists have.
language_packs() {
  local ll cc app pre cand
  ll=$(printf '%s' "$1" | sed 's/[_.@].*//')
  cc=$(printf '%s' "$1" | sed -n 's/^[a-z]*_\([A-Za-z]*\).*/\1/p' | tr '[:upper:]' '[:lower:]')
  [[ "$ll" == en && ( "$cc" == us || -z "$cc" ) ]] && return 0   # the apps' own language
  for app in firefox libreoffice-fresh libreoffice-still; do
    pacman -Q "$app" >/dev/null 2>&1 || continue
    pre=$app; [[ $app == firefox ]] && pre=firefox-i18n
    for cand in ${cc:+"$pre-$ll-$cc"} "$pre-$ll"; do
      pacman -Si "$cand" >/dev/null 2>&1 || continue
      pacman -Q "$cand" >/dev/null 2>&1 || printf '%s\n' "$cand"
      break
    done
  done
  return 0
}

# language_sample <code>: how it writes the last day of 2026, a number and the paper size: "31.12.2026 ·
# 1.234,56 · A4". Only for a locale glibc has made.
language_sample() {
  local d dp="" ts="" h paper=""
  d=$(TZ=UTC LC_ALL=$1 date -d @1798718400 +%x 2>/dev/null || TZ=UTC LC_ALL=$1 date -r 1798718400 +%x 2>/dev/null || true)
  { IFS= read -r dp; IFS= read -r ts; } < <(LC_ALL=$1 locale decimal_point thousands_sep 2>/dev/null) || true
  h=$(LC_ALL=$1 locale height 2>/dev/null || true)
  case "$h" in 297) paper=A4 ;; 279) paper=Letter ;; esac
  printf '%s1%s234%s56%s' "${d:+$d · }" "$ts" "${dp:-.}" "${paper:+ · $paper paper}"
}

# language_assign <language|formats> <code>: the variables for localed, one assignment a line. A new language
# keeps the formats set apart and drops what would speak over it (LANGUAGE, LC_MESSAGES); new formats set all
# five apart, or none when they are the language's own.
language_assign() {
  local what=$1 code=$2 lang k v
  lang=$(language_now); [[ $what == language ]] && lang=$code
  printf 'LANG=%s\n' "$lang"
  [[ -r "$language_conf" ]] && while IFS='=' read -r k v; do
    v=${v#\"}; v=${v%\"}
    case "$k" in
      LANG|LANGUAGE|LC_MESSAGES|"") [[ $what == formats && $k != LANG && -n "$k" ]] && printf '%s=%s\n' "$k" "$v" ;;
      LC_TIME|LC_NUMERIC|LC_MONETARY|LC_PAPER|LC_MEASUREMENT) [[ $what == language && "$v" != "$lang" ]] && printf '%s=%s\n' "$k" "$v" ;;
      LC_*) printf '%s=%s\n' "$k" "$v" ;;
    esac
  done < <(grep -E '^[A-Z_]+=' "$language_conf")
  if [[ $what == formats && "$code" != "$lang" ]]; then for k in $LANGUAGE_FORMATS; do printf '%s=%s\n' "$k" "$code"; done; fi
  return 0
}

# --- For commands, after lib/core.sh: asking which, and making the change.

# language_ask <language|place> <question>: asks until an answer names one, and sets LANGUAGE_PICKED to its code.
# "portuguese" asks again with the ones it could be; "brazil" then narrows it.
LANGUAGE_PICKED=""
language_ask() {
  local words="" answer pick rest tab=$'\t'
  while :; do
    core_ask answer "$2" || core_fail 3 "Nothing changed"
    answer=$(printf '%s' "$answer" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
    [[ -n "$answer" ]] || continue
    pick=$(language_pick "$1" "${words:+$words }$answer")
    case "$pick" in
      one"$tab"*) rest=${pick#one"$tab"}; LANGUAGE_PICKED=${rest%%"$tab"*}; return 0 ;;
      several"$tab"*) words="${words:+$words }$answer"; core_wrong "Several match: ${pick#several"$tab"}. Type more, like a country" ;;
      *) words=""; core_wrong "Nothing here is called $answer" ;;
    esac
  done
}

# language_apply <code> <assignments> <packs> <why>: glibc makes the locale when it has not yet, localed is handed
# the assignments, and the packs are installed. With only localed to ask, through polkit (the Core asks for the
# password, docs/approvals.md); with more, one password for all of it, through sudo. LANGUAGE_PACKS_FAILED is
# set when the packs did not install (no network): the language changed all the same.
LANGUAGE_PACKS_FAILED=""
language_apply() {
  local code=$1 why=$4 log="$HOME/.local/state/takumi/language.log" args=() a out
  while IFS= read -r a; do [[ -n "$a" ]] && args+=("$a"); done <<< "$2"
  if language_ready "$code" && [[ -z "$3" ]]; then
    core_note "Changing the language…"
    if ! out=$(LC_ALL=C localectl set-locale "${args[@]}" 2>&1); then
      case "$out" in *"Access denied"*|*uthenticat*) core_fail 3 "Nothing changed: the password was not given" ;; esac
      core_fail 1 "Nothing changed: $(printf '%s' "$out" | sed 's/^Failed to [^:]*: //' | head -n 1)"
    fi
    return 0
  fi
  admin() { core_sudo "$why" "$@"; }
  admin -v 2>/dev/null || core_fail 3 "Nothing changed: the password was not given"
  mkdir -p "${log%/*}"
  if ! language_ready "$code"; then
    core_note "Making $(language_name "$code") ready…"
    language_gen_with "$code" | admin tee "$language_gen" >/dev/null \
      || core_fail 1 "Nothing changed: $language_gen could not be written"           # /etc/locale.gen
    admin locale-gen >> "$log" 2>&1 \
      || core_fail 1 "Nothing changed: $(language_name "$code") could not be made: $log"   # /usr/lib/locale/locale-archive
  fi
  admin localectl set-locale "${args[@]}" >> "$log" 2>&1 || core_fail 1 "Nothing changed: $log"   # /etc/locale.conf
  if [[ -n "$3" ]]; then
    core_note "Getting Firefox and LibreOffice in $(language_name "$code")…"
    # shellcheck disable=SC2086
    admin pacman -S --needed --noconfirm $3 >> "$log" 2>&1 || LANGUAGE_PACKS_FAILED=yes   # /usr (the language packs)
  fi
  return 0
}
