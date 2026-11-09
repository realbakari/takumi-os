#!/usr/bin/env bash
# Time, Today and keeping up to date: the clock's format, the time zone and the places it can be, clocks for
# other cities, words like "tomorrow 9:00" turned into a moment, reminders and timers, and whether an update
# is ready. Sourced by commands/clock/*, remind/*, timer/*, weather/*, update/check, update/prepare and the
# Palette's time rows; never run. Runs on bash 3.2 with GNU or BSD date (the tests use fakes on macOS).
# See docs/time.md and docs/updates.md.

clock_config="$HOME/.config/takumi/clock.toml"
clock_state="$HOME/.local/state/takumi"
clock_cache="${XDG_RUNTIME_DIR:-$HOME/.cache/takumi}"
TAKUMI_ZONEINFO=${TAKUMI_ZONEINFO:-/usr/share/zoneinfo}

# ---- Settings: ~/.config/takumi/clock.toml, written whole

# clock_setting <key>: a value from clock.toml without its quotes, or nothing.
clock_setting() {
  local line
  [[ -f "$clock_config" ]] || return 0
  line=$(grep -m 1 -E "^$1[[:space:]]*=" "$clock_config" 2>/dev/null) || return 0
  line=${line#*=}; line=${line%%#*}
  line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  line=${line#\"}; line=${line%\"}
  printf '%s' "$line"
}

# clock_save <format> <auto> <cities, one "City|Area/Zone" per line>
clock_save() {
  local list="" c
  while IFS= read -r c; do [[ -n "$c" ]] && list+="${list:+, }\"$c\""; done <<< "$3"
  mkdir -p "${clock_config%/*}"
  {
    printf '# The clock, as set from the Core. See docs/time.md.\n\n'
    printf 'format = "%s"   # 24h or 12h; empty: as your language writes the time\n' "$1"
    printf 'auto = %s   # true: the time zone follows the network (takumi clock auto)\n' "$2"
    printf 'cities = [%s]   # clocks for other places in Today, "City|Area/Zone"\n' "$list"
  } > "$clock_config.tmp"
  mv "$clock_config.tmp" "$clock_config"
}
clock_auto_on() { [[ "$(clock_setting auto)" == true ]]; }
clock_auto_word() { if clock_auto_on; then echo true; else echo false; fi; }
clock_cities() { clock_setting cities | grep -o '"[^"]*"' | tr -d '"' || true; }

# clock_format: 12h or 24h, as chosen, else as the language writes the time (en_US: 12h).
clock_format() {
  local f t
  f=$(clock_setting format)
  case "$f" in 12h|24h) echo "$f"; return 0 ;; esac
  t=$(locale t_fmt 2>/dev/null || true)
  case "$t" in *%r*|*%I*|*%l*|*%p*) echo 12h ;; *) echo 24h ;; esac
}

# ---- Moments

# The time now, in seconds. TAKUMI_NOW stands in for it in the tests.
clock_now() { echo "${TAKUMI_NOW:-$(date +%s)}"; }

# clock_date <epoch> <+format> [zone]: date(1) for a moment, GNU or BSD, here or in another zone.
clock_date() {
  if [[ -n "${3:-}" ]]; then TZ=$3 date -d "@$1" "$2" 2>/dev/null || TZ=$3 date -r "$1" "$2"
  else date -d "@$1" "$2" 2>/dev/null || date -r "$1" "$2"; fi
}
# clock_epoch <YYYY-MM-DD HH:MM>: that moment here, in seconds.
clock_epoch() { date -d "$1:00" +%s 2>/dev/null || date -j -f '%Y-%m-%d %H:%M:%S' "$1:00" +%s 2>/dev/null; }
clock_today() { clock_date "$(clock_now)" +%Y-%m-%d; }
# clock_day <n>: the date n days from today. Noon to noon, so a change to or from summer time is no matter.
clock_day() {
  local noon
  noon=$(clock_epoch "$(clock_today) 12:00") || return 1
  clock_date $(( noon + $1 * 86400 )) +%Y-%m-%d
}
# clock_days_until <epoch>: whole days from today to that moment's day: 0 today, 1 tomorrow, -1 yesterday.
clock_days_until() {
  local a b d
  a=$(clock_epoch "$(clock_today) 12:00") && b=$(clock_epoch "$(clock_date "$1" +%Y-%m-%d) 12:00") || { echo 0; return 0; }
  d=$(( b - a ))
  if (( d >= 0 )); then echo $(( (d + 43200) / 86400 )); else echo $(( -((43200 - d) / 86400) )); fi
}

# clock_hm <epoch> [zone]: "14:05", or "2:05 PM" on the 12-hour clock. Worked out here, not by the language's
# own AM and PM, so it reads the same everywhere.
clock_hm() {
  local hm h
  hm=$(clock_date "$1" +%H:%M "${2:-}")
  [[ "${clock_fmt:=$(clock_format)}" == 12h ]] || { echo "$hm"; return 0; }
  h=$((10#${hm%%:*}))
  if (( h < 12 )); then echo "$(( h == 0 ? 12 : h )):${hm#*:} AM"; else echo "$(( h == 12 ? 12 : h - 12 )):${hm#*:} PM"; fi
}

# clock_say_when <epoch>: "at 15:00", "tomorrow at 9:00", "on Friday at 18:00", "on 24 Dec at 9:00".
clock_say_when() {
  local d t
  d=$(clock_days_until "$1"); t=$(clock_hm "$1")
  case "$d" in
    0) echo "at $t" ;;
    1) echo "tomorrow at $t" ;;
    2|3|4|5|6) echo "on $(clock_date "$1" +%A) at $t" ;;
    *) echo "on $(clock_date "$1" '+%-d %b') at $t" ;;
  esac
}

# clock_length <seconds>: "45 s", "10 min", "2 min 30 s", "1 h 20 min".
clock_length() {
  local s=$1 m r h
  if (( s < 60 )); then echo "$s s"; return 0; fi
  if (( s < 3600 )); then
    m=$(( s / 60 )); r=$(( s % 60 ))
    if (( r == 0 )); then echo "$m min"; elif (( m < 10 )); then echo "$m min $r s"; else echo "$(( (s + 30) / 60 )) min"; fi
    return 0
  fi
  h=$(( s / 3600 )); m=$(( (s % 3600 + 30) / 60 ))
  if (( m == 60 )); then h=$((h + 1)); m=0; fi
  if (( m == 0 )); then echo "$h h"; else echo "$h h $m min"; fi
}

# ---- Words to moments
# The parsers read the lowercased words in lw[] (n of them) that their caller set, and leave what they found
# in _t_* (a time of day), _d_* (a length of time) and _w_* (a moment), with *_end the word after it.

_clock_unit() {
  case "$1" in
    s|sec|secs|second|seconds) echo 1 ;; m|min|mins|minute|minutes) echo 60 ;;
    h|hr|hrs|hour|hours) echo 3600 ;; d|day|days) echo 86400 ;; *) return 1 ;;
  esac
}
_clock_weekday() {
  case "$1" in
    mon|monday) echo 1 ;; tue|tues|tuesday) echo 2 ;; wed|weds|wednesday) echo 3 ;; thu|thur|thurs|thursday) echo 4 ;;
    fri|friday) echo 5 ;; sat|saturday) echo 6 ;; sun|sunday) echo 7 ;; *) return 1 ;;
  esac
}

# _clock_time <i>: "15:00", "15.00", "15h30", "3pm", "3:30 pm", "noon", "midnight", or a bare hour ("3",
# _t_bare=yes), which only counts after "at" or a day.
_clock_time() {
  local k=$1 t=${lw[$1]:-} next=${lw[$(( $1 + 1 ))]:-} ap="" h m re_hm='^([0-9]{1,2})[h.:]([0-9]{2})$' re_h='^([0-9]{1,2})(h?)$'
  _t_bare=no; _t_end=$((k + 1))
  case "$t" in noon) _t_h=12; _t_m=0; return 0 ;; midnight) _t_h=0; _t_m=0; return 0 ;; esac
  case "$t" in
    *a.m.) ap=am; t=${t%a.m.} ;; *p.m.) ap=pm; t=${t%p.m.} ;;
    *am) ap=am; t=${t%am} ;; *pm) ap=pm; t=${t%pm} ;;
  esac
  if [[ -z "$ap" ]]; then
    case "$next" in am|a.m.) ap=am; _t_end=$((k + 2)) ;; pm|p.m.) ap=pm; _t_end=$((k + 2)) ;; esac
  fi
  if [[ "$t" =~ $re_hm ]]; then h=${BASH_REMATCH[1]}; m=${BASH_REMATCH[2]}
  elif [[ "$t" =~ $re_h ]]; then
    h=${BASH_REMATCH[1]}; m=0
    if [[ -z "$ap" && -z "${BASH_REMATCH[2]}" ]]; then _t_bare=yes; fi
  else return 1; fi
  h=$((10#$h)); m=$((10#$m))
  if [[ -n "$ap" ]]; then
    (( h >= 1 && h <= 12 )) || return 1
    if (( h == 12 )); then h=0; fi
    if [[ $ap == pm ]]; then h=$((h + 12)); fi
  fi
  (( h <= 23 && m <= 59 )) || return 1
  _t_h=$h; _t_m=$m
}

# _clock_span <i>: "10 min", "1 h 30", "90s", "1h30", "an hour", "half an hour", "2 days". A number on its
# own is minutes, first ("in 10") or after hours ("1 h 30").
_clock_span() {
  local k=$1 total=0 t u num prev=""
  local re_n='^([0-9]+)(s|sec|secs|second|seconds|m|min|mins|minute|minutes|h|hr|hrs|hour|hours|d|day|days)?$' re_hm='^([0-9]+)h([0-9]+)m?$'
  while (( k < n )); do
    t=${lw[$k]}
    if [[ "$t" == half && "${lw[$((k + 1))]:-} ${lw[$((k + 2))]:-}" == "an hour" ]]; then total=$((total + 1800)); k=$((k + 3)); prev=x; continue; fi
    if [[ ( "$t" == a || "$t" == an ) && -z "$prev" ]] && u=$(_clock_unit "${lw[$((k + 1))]:-}"); then total=$((total + u)); k=$((k + 2)); prev=x; continue; fi
    if [[ "$t" == and && -n "$prev" ]]; then k=$((k + 1)); continue; fi
    if [[ "$t" =~ $re_hm ]]; then total=$((total + 10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60)); k=$((k + 1)); prev=x; continue; fi
    [[ "$t" =~ $re_n ]] || break
    num=${BASH_REMATCH[1]}; u=${BASH_REMATCH[2]}
    (( ${#num} <= 6 )) || break
    num=$((10#$num))
    if [[ -z "$u" ]] && _clock_unit "${lw[$((k + 1))]:-}" >/dev/null; then u=${lw[$((k + 1))]}; k=$((k + 1)); fi
    if [[ -z "$u" ]]; then
      [[ -z "$prev" || "$prev" == h ]] || break
      u=min
    fi
    u=$(_clock_unit "$u"); total=$((total + num * u)); k=$((k + 1))
    if (( u == 3600 )); then prev=h; else prev=x; fi
  done
  [[ -n "$prev" ]] || return 1
  _d_secs=$total; _d_end=$k
}

# _clock_on_day <days ahead> <i>: that day, at the time from word i on ("at" optional), or 9:00 when none is
# given. A bare hour from 1 to 7 is the afternoon: "tomorrow at 3" is 15:00.
_clock_on_day() {
  local d=$1 k=$2 h=9 m=0
  if [[ "${lw[$k]:-}" == at ]]; then k=$((k + 1)); fi
  if (( k < n )) && _clock_time "$k"; then
    h=$_t_h; m=$_t_m; k=$_t_end
    if [[ $_t_bare == yes ]] && (( h >= 1 && h <= 7 )); then h=$((h + 12)); fi
  elif [[ "${lw[$2]:-}" == at ]]; then return 1
  fi
  _w_at=$(clock_epoch "$(clock_day "$d") $(printf '%02d:%02d' "$h" "$m")") || return 1
  _w_end=$k
}

# _clock_when_at <i>: a moment told from word i on: "in <length>", "at <time> [tomorrow]", "<time>",
# "tomorrow [at <time>]", "today at <time>", "tonight", "[on|next] <weekday> [at <time>]".
_clock_when_at() {
  local i=$1 t=${lw[$1]:-} now wd today d k next=no hm
  now=$(clock_now)
  case "$t" in
    in)
      _clock_span $((i + 1)) || return 1
      (( _d_secs > 0 && _d_secs <= 31622400 )) || return 1
      _w_at=$((now + _d_secs)); _w_end=$_d_end; return 0 ;;
    tomorrow) _clock_on_day 1 $((i + 1)); return ;;
    tonight)
      if [[ "${lw[$((i + 1))]:-}" == at ]]; then _clock_on_day 0 $((i + 1)) || return 1
      else _w_at=$(clock_epoch "$(clock_day 0) 20:00") || return 1; _w_end=$((i + 1)); fi
      (( _w_at > now )); return ;;
    today)
      k=$((i + 1)); if [[ "${lw[$k]:-}" == at ]]; then k=$((k + 1)); fi
      _clock_time "$k" || return 1
      _clock_on_day 0 $((i + 1)) || return 1
      (( _w_at > now )); return ;;
    on|next)
      [[ $t == next ]] && next=yes
      _clock_weekday "${lw[$((i + 1))]:-}" >/dev/null || return 1
      i=$((i + 1)); t=${lw[$i]} ;;
  esac
  if wd=$(_clock_weekday "$t"); then
    today=$(clock_date "$now" +%u); d=$(( (wd - today + 7) % 7 ))
    if [[ $next == yes ]] && (( d == 0 )); then d=7; fi
    _clock_on_day "$d" $((i + 1)) || return 1
    if (( _w_at <= now )); then _clock_on_day $((d + 7)) $((i + 1)) || return 1; fi
    return 0
  fi
  # "at 15:00", or a time on its own: today, or tomorrow once it has passed. A bare hour needs "at" and is the
  # next time the clock shows it: "at 3" is 15:00 in the morning and 3:00 in the evening.
  k=$i; if [[ "$t" == at ]]; then k=$((i + 1)); fi
  _clock_time "$k" || return 1
  [[ "$t" == at || $_t_bare == no ]] || return 1
  if [[ "${lw[$_t_end]:-}" == tomorrow ]]; then
    hm=$(printf '%02d:%02d' "$_t_h" "$_t_m"); k=$_t_end
    if [[ $_t_bare == yes ]] && (( _t_h >= 1 && _t_h <= 7 )); then hm=$(printf '%02d:%02d' $((_t_h + 12)) "$_t_m"); fi
    _w_at=$(clock_epoch "$(clock_day 1) $hm") || return 1; _w_end=$((k + 1)); return 0
  fi
  _w_end=$_t_end
  local first second
  first=$(clock_epoch "$(clock_day 0) $(printf '%02d:%02d' "$_t_h" "$_t_m")") || return 1
  if (( first > now )); then _w_at=$first; return 0; fi
  if [[ $_t_bare == yes ]] && (( _t_h < 12 )); then
    second=$(clock_epoch "$(clock_day 0) $(printf '%02d:%02d' $((_t_h + 12)) "$_t_m")") || return 1
    if (( second > now )); then _w_at=$second; return 0; fi
  fi
  _w_at=$(clock_epoch "$(clock_day 1) $(printf '%02d:%02d' "$_t_h" "$_t_m")") || return 1
}

# clock_when <words...>: "<epoch>\t<what>" for a reminder said either way round: "in 10 min stretch", "call Ana
# at 3", "tomorrow 9:00 dentist", "me to water the plants on friday". False when no moment is in it.
clock_when() {
  local s lower w=() lw=() n i start=0 what="" found=no
  s=$(printf '%s ' "$@" | tr '\t\n' '  ' | tr -s ' ' | sed 's/^ //; s/ $//')
  lower=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
  read -r -a w <<< "$s"; read -r -a lw <<< "$lower"; n=${#w[@]}
  (( n > 0 )) || return 1
  if [[ "${lw[0]}" == me ]]; then start=1; fi
  if (( start < n )) && _clock_when_at "$start"; then
    found=yes; what="${w[*]:$_w_end}"
  else
    for (( i = start + 1; i < n; i++ )); do
      if _clock_when_at "$i" && (( _w_end == n )); then found=yes; what="${w[*]:$start:$((i - start))}"; break; fi
    done
  fi
  [[ $found == yes ]] || return 1
  what=${what#to }; what=${what#To }
  if [[ "$what" == to || "$what" == To ]]; then what=""; fi
  printf '%s\t%s\n' "$_w_at" "$what"
}

# clock_duration <words...>: "<seconds>\t<name>" for a timer: "10", "10 min", "1 h 30", "90 s", "25 min tea",
# "tea 25 min". False when no length is in it.
clock_duration() {
  local s lower w=() lw=() n i start=0
  s=$(printf '%s ' "$@" | tr '\t\n' '  ' | tr -s ' ' | sed 's/^ //; s/ $//')
  lower=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
  read -r -a w <<< "$s"; read -r -a lw <<< "$lower"; n=${#w[@]}
  (( n > 0 )) || return 1
  if [[ "${lw[0]}" == for ]]; then start=1; fi
  if (( start < n )) && _clock_span "$start"; then
    (( _d_secs > 0 && _d_secs <= 86400 )) || return 1
    printf '%s\t%s\n' "$_d_secs" "${w[*]:$_d_end}"; return 0
  fi
  for (( i = start + 1; i < n; i++ )); do
    if _clock_span "$i" && (( _d_end == n && _d_secs > 0 && _d_secs <= 86400 )); then
      printf '%s\t%s\n' "$_d_secs" "${w[*]:$start:$((i - start))}"; return 0
    fi
  done
  return 1
}

# ---- Places and time zones

# clock_zone: the time zone this computer keeps (Europe/Lisbon), as timedated says.
clock_zone() {
  local z
  z=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  [[ -n "$z" ]] || z=$(readlink /etc/localtime 2>/dev/null | sed -n 's|.*/zoneinfo/||p' || true)
  printf '%s' "${z:-UTC}"
}

# clock_zones: every time zone as "zone<TAB>city<TAB>country", by city: what takumi setup zones prints,
# kept for the session so the Palette can look through it at every key.
clock_zones() {
  local f="$clock_cache/takumi-zones.tsv"
  if [[ ! -s "$f" || "$TAKUMI_ZONEINFO/zone.tab" -nt "$f" ]]; then
    mkdir -p "$clock_cache"
    takumi setup zones 2>/dev/null | jq -r '[.zone, .city, .country] | @tsv' > "$f.$$" 2>/dev/null || true
    if [[ -s "$f.$$" ]]; then mv "$f.$$" "$f"; else rm -f "$f.$$"; return 0; fi
  fi
  cat "$f"
}

# clock_fold <text>: lowercase, without accents, apostrophes or dots, "_" and "-" as spaces: "São Paulo" and
# "sao_paulo" both read "sao paulo". Each accented letter is its own substitution: sed's brackets would
# split a letter's bytes.
clock_fold() {
  local plain='^[a-z0-9 ]+$'
  if [[ "$1" =~ $plain && "$1" != *"  "* && "$1" != " "* && "$1" != *" " ]]; then printf '%s\n' "$1"; return 0; fi
  printf '%s' "$1" | sed -e "s/[_-]/ /g; s/[.']//g" \
    -e 's/À/a/g;s/Á/a/g;s/Â/a/g;s/Ã/a/g;s/Ä/a/g;s/Å/a/g;s/à/a/g;s/á/a/g;s/â/a/g;s/ã/a/g;s/ä/a/g;s/å/a/g;s/ā/a/g;s/ą/a/g' \
    -e 's/Ç/c/g;s/ç/c/g;s/Ć/c/g;s/ć/c/g;s/Č/c/g;s/č/c/g;s/È/e/g;s/É/e/g;s/Ê/e/g;s/Ë/e/g;s/è/e/g;s/é/e/g;s/ê/e/g;s/ë/e/g;s/ē/e/g;s/ę/e/g;s/ě/e/g' \
    -e 's/Ì/i/g;s/Í/i/g;s/Î/i/g;s/Ï/i/g;s/ì/i/g;s/í/i/g;s/î/i/g;s/ï/i/g;s/ī/i/g;s/ı/i/g;s/İ/i/g;s/Ñ/n/g;s/ñ/n/g;s/ń/n/g;s/ň/n/g' \
    -e 's/Ò/o/g;s/Ó/o/g;s/Ô/o/g;s/Õ/o/g;s/Ö/o/g;s/Ø/o/g;s/ò/o/g;s/ó/o/g;s/ô/o/g;s/õ/o/g;s/ö/o/g;s/ø/o/g;s/ō/o/g;s/ő/o/g' \
    -e 's/Ù/u/g;s/Ú/u/g;s/Û/u/g;s/Ü/u/g;s/ù/u/g;s/ú/u/g;s/û/u/g;s/ü/u/g;s/ū/u/g;s/ů/u/g;s/ű/u/g;s/Ý/y/g;s/ý/y/g;s/ÿ/y/g' \
    -e 's/Š/s/g;s/Ś/s/g;s/Ş/s/g;s/Ș/s/g;s/š/s/g;s/ś/s/g;s/ş/s/g;s/ș/s/g;s/Ž/z/g;s/Ź/z/g;s/Ż/z/g;s/ž/z/g;s/ź/z/g;s/ż/z/g' \
    -e 's/Ł/l/g;s/ł/l/g;s/Đ/d/g;s/đ/d/g;s/ď/d/g;s/Ř/r/g;s/ř/r/g;s/Ť/t/g;s/ť/t/g;s/ț/t/g;s/ţ/t/g;s/ğ/g/g;s/ß/ss/g;s/Æ/ae/g;s/æ/ae/g;s/Œ/oe/g;s/œ/oe/g' |
    tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/^ //; s/ $//'
}

# clock_find <place>: the time zones a place could mean, as "zone<TAB>city<TAB>country", from the zone
# table: a zone's own name (Europe/Lisbon), a city ("lisbon", "São Paulo"), a country ("Portugal"), or the
# start of a city or a country. Only the best kind of match is printed: a city named exactly hides the
# cities that merely start the same way.
clock_find() {
  local q z re='^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$'
  q=$(clock_fold "$1"); [[ -n "$q" ]] || return 0
  z=$(printf '%s' "$1" | sed 's/^ *//; s/ *$//; s/ /_/g')
  clock_zones | Q="$q" Z="$z" awk -F '\t' '
    function fold(s) { s = tolower(s); gsub(/[_-]/, " ", s); gsub(/[.'\'']/, "", s); return s }
    BEGIN { q = ENVIRON["Q"]; z = tolower(ENVIRON["Z"]) }
    { r = 9; city = fold($2); country = fold($3)
      if (tolower($1) == z) r = 0
      else if (city == q) r = 1
      else if (country == q) r = 2
      else if (index(city, q) == 1) r = 3
      else if (index(" " city, " " q) > 0) r = 4
      else if (index(country, q) == 1) r = 5
      if (r < 9) out[r] = out[r] $0 "\n" }
    END { for (r = 0; r < 9; r++) if (r in out) { printf "%s", out[r]; break } }' > "$clock_cache/takumi-found.$$" 2>/dev/null || true
  if [[ -s "$clock_cache/takumi-found.$$" ]]; then cat "$clock_cache/takumi-found.$$"
  elif [[ "$z" =~ $re && -f "$TAKUMI_ZONEINFO/$z" ]]; then printf '%s\t%s\t\n' "$z" "$(clock_city "$z")"
  fi
  rm -f "$clock_cache/takumi-found.$$"
}

# clock_city <zone>: the city a zone is named for, as the zone table spells it ("America/Sao_Paulo": Sao Paulo).
clock_city() {
  local c=""
  [[ "$1" == UTC ]] && { echo UTC; return 0; }
  c=$(clock_zones | awk -F '\t' -v z="$1" '$1 == z && c == "" { c = $2 } END { print c }')
  if [[ -z "$c" ]]; then c=${1##*/}; c=${c//_/ }; fi
  echo "$c"
}
clock_country() { clock_zones | awk -F '\t' -v z="$1" '$1 == z && c == "" { c = $3 } END { print c }'; }

# clock_place <place>: the time zone a place means, as "zone<TAB>city<TAB>country": from the zone table, or,
# for a town the table does not name, from Open-Meteo's place search (lib/weather.sh, over the internet).
# Returns 4 and prints the candidates when the place has several time zones (a country, or the start of
# several names), 1 when nothing is found.
clock_place() {
  local found n z c k
  found=$(clock_find "$1"); n=$(printf '%s' "$found" | grep -c . || true)
  if (( n == 1 )); then printf '%s\n' "$found"; return 0; fi
  if (( n > 1 )); then printf '%s\n' "$found"; return 4; fi
  declare -F weather_find >/dev/null || return 1
  found=$(weather_find "$1") || return 1
  IFS=$'\t' read -r c k _ _ z <<< "$found"
  [[ -n "$z" && "$z" != *..* && -f "$TAKUMI_ZONEINFO/$z" ]] || return 1
  printf '%s\t%s\t%s\n' "$z" "$c" "$k"
}
# clock_several <candidates>: the first few cities of clock_place's candidates, "Sao Paulo, Manaus or Recife".
clock_several() {
  printf '%s\n' "$1" | cut -f2 | awk 'NF && n < 4 { a[n++] = $0 } END { for (i = 0; i < n; i++) printf "%s%s", a[i], (i == n - 2 ? " or " : i < n - 1 ? ", " : "") }'
}

# clock_set_zone <zone>: through timedated, whose polkit rule lets the person at the computer change the
# time zone without a password. False when it would want one.
clock_set_zone() { timedatectl --no-ask-password set-timezone "$1" >/dev/null 2>&1; }

# clock_offset [zone]: seconds east of UTC now, here or in a zone.
clock_offset() {
  local z sign=1
  if [[ -n "${1:-}" ]]; then z=$(TZ=$1 date +%z); else z=$(date +%z); fi
  [[ "$z" == -* ]] && sign=-1
  z=${z#[+-]}
  echo $(( sign * (10#${z:0:2} * 3600 + 10#${z:2:2} * 60) ))
}
# clock_diff <seconds>: how far ahead a place is, in words: "+9 h", "−4 h 30 min", "same time".
clock_diff() {
  local s=$1 sign="+" h m
  if (( s == 0 )); then echo "same time"; return 0; fi
  if (( s < 0 )); then sign="−"; s=$(( -s )); fi
  h=$(( s / 3600 )); m=$(( s % 3600 / 60 ))
  if (( m == 0 )); then echo "$sign$h h"; elif (( h == 0 )); then echo "$sign$m min"; else echo "$sign$h h $m min"; fi
}

# The clocks for other places Today shows, as "City|Area/Zone". clock_city_name keeps a typed name safe to
# write into clock.toml.
clock_city_name() { printf '%s' "$1" | tr -d '"|\\#' | tr '\t' ' ' | sed 's/^ *//; s/ *$//'; }
clock_city_add() {  # <city> <zone>: false when it is already there
  local list c
  list=$(clock_cities)
  while IFS= read -r c; do [[ -n "$c" && "${c#*|}" == "$2" ]] && return 1; done <<< "$list"
  clock_save "$(clock_setting format)" "$(clock_auto_word)" "$(printf '%s\n%s|%s' "$list" "$(clock_city_name "$1")" "$2")"
}
clock_city_remove() {  # <city or zone>: false when no such clock is there
  local q list c keep="" gone=no
  q=$(clock_fold "$1"); list=$(clock_cities)
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    if [[ "$(clock_fold "${c%%|*}")" == "$q" || "$(clock_fold "${c#*|}")" == "$q" ]]; then gone=yes; continue; fi
    keep+="$c"$'\n'
  done <<< "$list"
  [[ $gone == yes ]] || return 1
  clock_save "$(clock_setting format)" "$(clock_auto_word)" "$keep"
}

# ---- Reminders and timers
# One line each in ~/.local/state/takumi/reminders.tsv: id <tab> remind|timer <tab> when (epoch) <tab> made
# (epoch) <tab> what it says. Each has a timer in the person's own systemd, takumi-<kind>-<id>, that runs
# `takumi remind fire <id>` at that moment: a calendar time in UTC, so it rings on waking from sleep when its
# moment passed during it, and within a second (AccuracySec=1s), not a minute. The file outlives the session;
# takumi remind restore puts the timers back at login.

remind_file="$clock_state/reminders.tsv"
remind_lines() { [[ -s "$remind_file" ]] || return 0; sort -t "$(printf '\t')" -k3,3n "$remind_file"; }
remind_get() { [[ -f "$remind_file" ]] || return 0; awk -F '\t' -v id="$1" '$1 == id && !f { print; f = 1 }' "$remind_file"; }
remind_drop() {
  [[ -f "$remind_file" ]] || return 0
  awk -F '\t' -v id="$1" '$1 != id' "$remind_file" > "$remind_file.tmp" && mv "$remind_file.tmp" "$remind_file"
}
remind_new_id() {
  local f="$clock_state/reminders.next" i
  i=$(cat "$f" 2>/dev/null || echo 1); [[ "$i" =~ ^[0-9]+$ ]] || i=1
  mkdir -p "$clock_state"; echo $((i + 1)) > "$f"; echo "$i"
}
# remind_schedule <id> <kind> <epoch>: the timer in systemd. systemd-run --on-active would be simpler, but
# that clock stops while the computer sleeps (systemd.timer(5)), so a reminder set before closing the lid
# would come late.
remind_schedule() {
  local stamp bin
  stamp=$(clock_date "$3" '+%Y-%m-%d %H:%M:%S' UTC)
  bin=$(command -v takumi || echo /usr/bin/takumi)
  systemd-run --user --quiet --collect --unit="takumi-$2-$1" --description="Takumi $2 $1" \
    --on-calendar="$stamp UTC" --timer-property=AccuracySec=1s "$bin" remind fire "$1" >/dev/null 2>&1
}
remind_unschedule() { systemctl --user stop "takumi-$2-$1.timer" >/dev/null 2>&1 || true; }
remind_scheduled() { systemctl --user is-active --quiet "takumi-$2-$1.timer" 2>/dev/null; }
# remind_add <kind> <epoch> <text>: the new id, or false when systemd would not take the timer.
remind_add() {
  local id text
  text=$(printf '%s' "$3" | tr '\t\n\r' '   ' | sed 's/^ *//; s/ *$//'); text=${text:0:200}
  id=$(remind_new_id)
  remind_schedule "$id" "$1" "$2" || return 1
  mkdir -p "$clock_state"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$1" "$2" "$(clock_now)" "$text" >> "$remind_file"
  echo "$id"
}
# remind_json: what is coming, soonest first, one JSON object a line: {id, kind, at, made, text}.
remind_json() { remind_lines | jq -Rc 'split("\t") | select(length >= 5) | {id: .[0], kind: .[1], at: (.[2] | tonumber), made: (.[3] | tonumber), text: (.[4:] | join("\t"))}'; }

# ---- Updates
# updates_ready: the name of a room built with the waiting updates and staged for the next start, newer than
# the one running (lib/rooms.sh must be sourced). False when none is.
updates_ready() {
  local cur f r
  declare -F rooms_current >/dev/null || return 1
  cur=$(rooms_current 2>/dev/null || true); [[ -n "$cur" ]] || return 1
  for f in "${TAKUMI_STATE:-/var/lib/takumi/state}"/*; do
    [[ -f "$f" ]] || continue
    r=${f##*/}
    [[ "$r" > "$cur" ]] || continue
    if [[ "$(sed -n 's/^status=//p' "$f" | tail -n 1)" == staged ]]; then echo "$r"; return 0; fi
  done
  return 1
}
updates_file="$clock_state/updates.json"
# updates_get <field>: a field of updates.json ({count, checked, important, ready, room}), or nothing.
updates_get() { [[ -s "$updates_file" ]] || return 0; jq -r --arg f "$1" '.[$f] // empty | if type == "array" then join(", ") else tostring end' "$updates_file" 2>/dev/null || true; }
# updates_online: connected, with the internet answering (or NetworkManager not checking).
updates_online() { local s; s=$(LC_ALL=C nmcli -t -f STATE,CONNECTIVITY general 2>/dev/null || true); [[ "$s" == connected:full || "$s" == connected:unknown ]]; }
# updates_metered: a connection paid by the byte, as set or as NetworkManager guesses (a phone's hotspot):
# its Metered property is 1 (yes) or 3 (guessed yes).
updates_metered() {
  local m
  m=$(busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered 2>/dev/null || true)
  [[ "$m" == "u 1" || "$m" == "u 3" ]]
}
