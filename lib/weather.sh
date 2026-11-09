#!/usr/bin/env bash
# The weather, from Open-Meteo (https://open-meteo.com: no account, no key). Sourced by commands/weather/*,
# commands/clock/* and the Palette's time rows, after lib/clock.sh, which knows the city the clock is in.
# Runs on bash 3.2 (the tests use a fake curl on macOS). See docs/time.md.
#
# Two addresses are asked, both over HTTPS: Open-Meteo's place search (a name to where it is on the map, and
# its time zone) and its forecast (where to the weather now and over the next six hours). What comes back is
# kept in ~/.cache/takumi/weather.json for half an hour, so a place is looked up at most twice an hour, and
# only while something wants the weather: Today, the Palette or a command.

weather_config="$HOME/.config/takumi/weather.toml"
weather_cache="$HOME/.cache/takumi/weather.json"
weather_search_url="https://geocoding-api.open-meteo.com/v1/search"
weather_forecast_url="https://api.open-meteo.com/v1/forecast"
weather_fresh=1800    # seconds a forecast is kept before it is asked again
weather_stale=10800   # older than this it is not shown at all

# weather_setting <key>: a value from weather.toml without its quotes, or nothing.
weather_setting() {
  local line
  [[ -f "$weather_config" ]] || return 0
  line=$(grep -m 1 -E "^$1[[:space:]]*=" "$weather_config" 2>/dev/null) || return 0
  line=${line#*=}; line=${line%%#*}
  line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  line=${line#\"}; line=${line%\"}
  printf '%s' "$line"
}
# weather_save <show true|false> <place> <units>: weather.toml, written whole.
weather_save() {
  local place
  place=$(printf '%s' "$2" | tr -d '"\\#' | tr '\t' ' ')
  mkdir -p "${weather_config%/*}"
  {
    printf '# The weather in Today, as set from the Core. See docs/time.md.\n\n'
    printf 'show = %s   # true: Today shows the weather, asking Open-Meteo at most every 30 minutes\n' "$1"
    printf 'place = "%s"   # a place; empty: the city the clock is set to\n' "$place"
    printf 'units = "%s"   # celsius or fahrenheit; empty: as your language measures\n' "$3"
  } > "$weather_config.tmp"
  mv "$weather_config.tmp" "$weather_config"
}
weather_shown() { [[ "$(weather_setting show)" == true ]]; }
# weather_units: celsius, or fahrenheit where the language says so (the United States and a few others).
weather_units() {
  local u l
  u=$(weather_setting units)
  case "$u" in celsius|fahrenheit) echo "$u"; return 0 ;; esac
  l=${LC_ALL:-${LC_MEASUREMENT:-${LANG:-}}}; l=${l%%.*}
  case "$l" in *_US|*_BS|*_BZ|*_KY|*_PW|*_LR) echo fahrenheit ;; *) echo celsius ;; esac
}

# weather_get <url>: the answer, over HTTPS only, in ten seconds or not at all.
weather_get() { curl -fsS --max-time 10 --proto '=https' "$1" 2>/dev/null; }
weather_uri() { jq -rn --arg s "$1" '$s | @uri'; }

# weather_find <place> [zone]: "name<TAB>country<TAB>latitude<TAB>longitude<TAB>time zone" for a place's
# name, from Open-Meteo's search. "Paris, Texas" prefers the one whose country or region starts so; given a
# time zone, the one in it (the clock's city "Paris" is the one in Europe/Paris). False when none is found.
weather_find() {
  local name=$1 hint="" zone=${2:-} json
  if [[ "$name" == *,* ]]; then hint=$(clock_fold "${name#*,}"); name=${name%%,*}; fi
  name=$(printf '%s' "$name" | sed 's/^ *//; s/ *$//')
  [[ -n "$name" ]] || return 1
  json=$(weather_get "$weather_search_url?name=$(weather_uri "$name")&count=10&language=en&format=json") || return 1
  HINT=$hint ZONE=$zone jq -re '
    [.results // [] | .[] | select(.latitude != null and .longitude != null)] as $all
    | ([$all[] | select(env.ZONE != "" and .timezone == env.ZONE)]
       + [$all[] | select(env.HINT != "" and ([.country, .admin1, .country_code] | map(. // "" | ascii_downcase) | any(startswith(env.HINT))))]
       + $all) | first | select(. != null)
    | [.name, (.country // ""), (.latitude | tostring), (.longitude | tostring), (.timezone // "")] | @tsv' <<< "$json" 2>/dev/null
}

# weather_words <code>: what the sky is doing, from the forecast's WMO weather code.
weather_words() {
  case "$1" in
    0) echo clear ;; 1) echo "mostly clear" ;; 2) echo "partly cloudy" ;; 3) echo cloudy ;;
    45) echo fog ;; 48) echo "freezing fog" ;;
    51) echo "light drizzle" ;; 53) echo drizzle ;; 55) echo "heavy drizzle" ;; 56) echo "light freezing drizzle" ;; 57) echo "freezing drizzle" ;;
    61) echo "light rain" ;; 63) echo rain ;; 65) echo "heavy rain" ;; 66) echo "light freezing rain" ;; 67) echo "freezing rain" ;;
    71) echo "light snow" ;; 73) echo snow ;; 75) echo "heavy snow" ;; 77) echo "snow grains" ;;
    80) echo "light showers" ;; 81) echo showers ;; 82) echo "heavy showers" ;; 85) echo "snow showers" ;; 86) echo "heavy snow showers" ;;
    95) echo thunderstorm ;; 96) echo "thunderstorm with hail" ;; 99) echo "thunderstorm with heavy hail" ;;
    *) echo "" ;;
  esac
}

# weather_asked [place]: what a forecast is kept under: the place and units, or the clock's zone and units
# when no place is named, so moving the clock or choosing another place asks again.
weather_asked() {
  local p=${1:-}
  [[ -n "$p" ]] || p=$(weather_setting place)
  if [[ -n "$p" ]]; then echo "place:$(clock_fold "$p")|$(weather_units)"; else echo "zone:$(clock_zone)|$(weather_units)"; fi
}

# weather_cached [place] [seconds]: the kept forecast when it is for that place and younger than that.
weather_cached() {
  local asked max=${2:-$weather_fresh}
  [[ -s "$weather_cache" ]] || return 1
  asked=$(weather_asked "${1:-}")
  A=$asked jq -ce --argjson now "$(clock_now)" --argjson max "$max" 'select(.asked == env.A and ($now - (.fetched // 0)) < $max)' "$weather_cache" 2>/dev/null
}

# weather_fetch [place] [keep]: ask Open-Meteo and print the answer as one JSON object: {asked, place, country,
# lat, lon, units, fetched, temp, code, words, later, line}. keep=yes (the default) keeps it as Today's; a
# one-off look at another place passes no. A place found before is not searched again. False when the
# internet or Open-Meteo does not answer.
weather_fetch() {
  local want=${1:-} keep=${2:-yes} asked units zone="" name="" country="" lat="" lon="" found json words out
  asked=$(weather_asked "$want"); units=$(weather_units)
  [[ -n "$want" ]] || want=$(weather_setting place)
  if [[ -s "$weather_cache" ]] && out=$(A=$asked jq -re 'select(.asked == env.A) | [.place, .country, (.lat | tostring), (.lon | tostring)] | @tsv' "$weather_cache" 2>/dev/null); then
    IFS=$'\t' read -r name country lat lon <<< "$out"
  else
    if [[ -z "$want" ]]; then zone=$(clock_zone); want=$(clock_city "$zone"); fi
    found=$(weather_find "$want" "$zone") || return 1
    IFS=$'\t' read -r name country lat lon _ <<< "$found"
  fi
  [[ -n "$lat" && -n "$lon" ]] || return 1
  json=$(weather_get "$weather_forecast_url?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,precipitation_probability&forecast_hours=7&timezone=auto$([[ $units == fahrenheit ]] && printf '&temperature_unit=fahrenheit')") || return 1
  words=$(weather_words "$(jq -r '.current.weather_code // empty' <<< "$json" 2>/dev/null)")
  # Later: rain on the way when it is dry now (60% or more within six hours), else the warmest or coolest of
  # the next six hours when it is 2 or 3 degrees away from now.
  out=$(A=$asked P=$name C=$country U=$units W=$words jq -c --argjson now "$(clock_now)" --argjson lat "$lat" --argjson lon "$lon" '
    (.current.temperature_2m // null) as $t | select($t != null)
    | (.current.weather_code // -1) as $code | ($t | round) as $temp
    | ((.hourly.temperature_2m // [])[1:7] | map(select(. != null))) as $temps
    | ((.hourly.precipitation_probability // [])[1:7] | map(. // 0)) as $rain
    | ([51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99] | index($code)) as $wet
    | (if $wet == null and (($rain | max) // 0) >= 60 then (if (($temps | min) // 5) <= 0 then "snow later" else "rain later" end)
       elif ($temps | length) > 0 and (($temps | max | round) - $temp) >= 2 then "\($temps | max | round)° later"
       elif ($temps | length) > 0 and ($temp - ($temps | min | round)) >= 3 then "\($temps | min | round)° later"
       else "" end) as $later
    | {asked: env.A, place: env.P, country: env.C, lat: $lat, lon: $lon, units: env.U, fetched: $now,
       temp: $temp, code: $code, day: ((.current.is_day // 1) == 1), words: env.W, later: $later,
       line: ([env.P + " " + ($temp | tostring) + "°", env.W, $later] | map(select(. != "")) | join(" · "))}' <<< "$json" 2>/dev/null) || return 1
  [[ -n "$out" ]] || return 1
  if [[ $keep == yes ]]; then
    mkdir -p "${weather_cache%/*}"
    printf '%s\n' "$out" > "$weather_cache.$$" && mv "$weather_cache.$$" "$weather_cache"
  fi
  printf '%s\n' "$out"
}

# weather_glyph <json>: the row's icon: a drop when it is wet, the moon at night, else the sun.
weather_glyph() {
  jq -r 'if ([51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99] | index(.code)) != null then "drop" elif .day == false then "moon" else "sun" end' <<< "$1" 2>/dev/null || echo sun
}
