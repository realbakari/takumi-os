#!/usr/bin/env bash
# Apps: the default apps, web apps, removing apps, the Shelf and Windows in a window, for commands/app/*,
# commands/install/* and the Palette's defaults rows. Sourced, not run. Runs on bash 3.2: the tests use fake
# xdg-mime, flatpak, pacman, podman and curl on macOS. See docs/apps.md.

apps_data="${XDG_DATA_HOME:-$HOME/.local/share}"
apps_config="${XDG_CONFIG_HOME:-$HOME/.config}"
apps_state="$HOME/.local/state/takumi"
apps_here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
apps_terminals="$apps_config/xdg-terminals.list"
apps_web_dir="$apps_data/applications"
apps_icons="$apps_data/icons/hicolor"

# --- Desktop entries -----------------------------------------------------------------------------------

# The folders that hold .desktop entries, the first that has an ID winning (the desktop entry spec's order):
# yours, Flatpak's for you, Flatpak's for everyone, then the system's. TAKUMI_APPS_DIRS (folders joined by
# ":") replaces the list, for the tests.
apps_dirs() {
  if [[ -n "${TAKUMI_APPS_DIRS:-}" ]]; then printf '%s\n' "$TAKUMI_APPS_DIRS" | tr ':' '\n'; return 0; fi
  printf '%s\n' "$apps_data/applications" "$apps_data/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications
  local d IFS=:
  for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do printf '%s\n' "$d/applications"; done
}

# Every entry once: id <tab> path.
apps_list() {
  local d f id seen=" " dirs
  dirs=$(apps_dirs)
  while IFS= read -r d; do
    for f in "$d"/*.desktop; do
      [[ -f "$f" ]] || continue
      id=${f##*/}
      [[ "$seen" == *" $id "* ]] && continue
      seen+="$id "
      printf '%s\t%s\n' "$id" "$f"
    done
  done <<< "$dirs"
}

# apps_path <id>: the file for a desktop ID, given with or without ".desktop".
apps_path() {
  local id=${1%.desktop}.desktop d dirs
  [[ "$id" == */* || "$id" == .desktop ]] && return 1
  dirs=$(apps_dirs)
  while IFS= read -r d; do [[ -f "$d/$id" ]] && { printf '%s\n' "$d/$id"; return 0; }; done <<< "$dirs"
  return 1
}

# apps_key <file> <key>: a key's value in the [Desktop Entry] group (not in an action's group).
apps_key() { awk -v k="$2" '/^\[/ { g = ($0 == "[Desktop Entry]"); next } g && index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$1"; }

# apps_name <id>: an app's name, or its ID when it has none.
apps_name() {
  local f n=""
  f=$(apps_path "$1") && n=$(apps_key "$f" Name)
  printf '%s\n' "${n:-${1%.desktop}}"
}

# Every app a person can see, once: id <tab> name <tab> ;categories; <tab> ;mime types;. Entries marked
# NoDisplay or Hidden, and anything that is not an application, are left out.
apps_table() {
  local files=() id f list
  list=$(apps_list)
  while IFS=$'\t' read -r id f; do [[ -z "$f" ]] || files+=("$f"); done <<< "$list"
  [[ ${#files[@]} -gt 0 ]] || return 0
  awk '
    function flush(   n, p) { if (file != "" && type == "Application" && nd != "true" && hid != "true" && name != "") { n = split(file, p, "/"); print p[n] "\t" name "\t;" cats ";\t;" mimes ";" } }
    FNR == 1 { flush(); file = FILENAME; g = 0; name = ""; cats = ""; mimes = ""; nd = ""; hid = ""; type = "" }
    /^\[/ { g = ($0 == "[Desktop Entry]"); next }
    g && /^Name=/ && name == "" { name = substr($0, 6) }
    g && /^Categories=/ { cats = substr($0, 12) }
    g && /^MimeType=/ { mimes = substr($0, 10) }
    g && /^NoDisplay=/ { nd = substr($0, 11) }
    g && /^Hidden=/ { hid = substr($0, 8) }
    g && /^Type=/ { type = substr($0, 6) }
    END { flush() }' "${files[@]}"
}

# apps_exec_of <file>: the command an entry runs, one word per line, without its %u-style codes. A Flatpak
# app is "flatpak run <id>".
apps_exec_of() {
  local f=$1 id
  case "$f" in */flatpak/exports/share/applications/*) id=${f##*/}; printf '%s\n' flatpak run "${id%.desktop}"; return 0 ;; esac
  apps_key "$f" Exec | tr ' ' '\n' | sed '/^%[a-zA-Z]$/d; /^$/d; s/^"\(.*\)"$/\1/'
}

# apps_exec_arg <word>: one argument written the way an entry's Exec line wants it: % doubled, quoted when it
# holds a character the Exec line reserves. Fails for the four characters that would need escaping inside
# the quotes (" ` $ \), which no web address Takumi accepts holds.
apps_exec_arg() {
  local a
  a=$(printf '%s' "$1" | sed 's/%/%%/g')
  case "$a" in *[\"\`\$\\]*) return 1 ;; esac
  case "$a" in *[[:space:]\'\>\<~\|\&\;\*\?\#\(\)]*) printf '"%s"' "$a" ;; *) printf '%s' "$a" ;; esac
}

# --- Default apps -------------------------------------------------------------------------------------

apps_kinds="browser mail terminal editor pdf images video music files"
apps_kind_ok() { [[ -n "$1" && " $apps_kinds " == *" $1 "* ]]; }
apps_kind_label() {
  case "$1" in browser) echo Browser ;; mail) echo Mail ;; terminal) echo Terminal ;; editor) echo Editor ;; pdf) echo PDFs ;;
    images) echo Images ;; video) echo Video ;; music) echo Music ;; files) echo Files ;; esac
}
# What a kind's app opens, in words.
apps_kind_what() {
  case "$1" in browser) echo "web links and pages" ;; mail) echo "email links" ;; terminal) echo "Super+Return and terminal apps" ;;
    editor) echo "text and code files" ;; pdf) echo "PDF documents" ;; images) echo "pictures and photos" ;;
    video) echo "films and clips" ;; music) echo "songs and recordings" ;; files) echo "folders and Super+E" ;; esac
}
apps_kind_glyph() {
  case "$1" in browser) echo globe ;; mail) echo quote ;; terminal) echo term ;; editor|pdf) echo edit ;; images) echo shot ;;
    video) echo video ;; music) echo headphones ;; files) echo folder ;; esac
}
# The type a kind's default is read from, and every type it is set for (the app's own among them).
apps_kind_primary() {
  case "$1" in browser) echo x-scheme-handler/https ;; mail) echo x-scheme-handler/mailto ;; editor) echo text/plain ;;
    pdf) echo application/pdf ;; images) echo image/png ;; video) echo video/mp4 ;; music) echo audio/mpeg ;; files) echo inode/directory ;; esac
}
apps_kind_types() {
  case "$1" in
    browser) echo "x-scheme-handler/https x-scheme-handler/http text/html application/xhtml+xml" ;;
    mail)    echo "x-scheme-handler/mailto message/rfc822" ;;
    editor)  echo "text/plain text/markdown text/x-python text/x-csrc text/x-chdr text/x-c++src text/javascript application/javascript application/json application/x-shellscript text/x-shellscript text/css text/xml application/xml application/toml text/x-rust text/x-go text/x-java" ;;
    pdf)     echo "application/pdf" ;;
    images)  echo "image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/heic image/heif image/avif image/jxl" ;;
    video)   echo "video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg video/3gpp" ;;
    music)   echo "audio/mpeg audio/flac audio/ogg audio/x-vorbis+ogg audio/opus audio/x-wav audio/wav audio/mp4 audio/aac audio/x-m4a" ;;
    files)   echo "inode/directory" ;;
  esac
}
# apps_kind_rule <kind>: "<categories>|<types>|<categories left out>". An app can be a kind's default when it
# has one of the categories or declares one of the types, and has none of the categories left out: a
# browser that also shows pictures is not offered for pictures, a vector drawing app not for PDFs.
apps_kind_rule() {
  case "$1" in
    browser)  echo "WebBrowser|x-scheme-handler/https|" ;;
    mail)     echo "Email|x-scheme-handler/mailto|" ;;
    terminal) echo "TerminalEmulator||" ;;
    editor)   echo "TextEditor IDE||WebBrowser" ;;
    pdf)      echo "|application/pdf|VectorGraphics RasterGraphics WordProcessor Spreadsheet Presentation" ;;
    images)   echo "|image/png image/jpeg|WebBrowser Office" ;;
    video)    echo "|video/mp4 video/x-matroska video/webm|WebBrowser Office" ;;
    music)    echo "|audio/mpeg audio/flac audio/ogg|WebBrowser Office" ;;
    files)    echo "FileManager||" ;;
  esac
}
# Takumi's own choice, for a kind nobody chose (config/mimeapps.list says the same). Mail has none.
apps_takumi_default() {
  case "$1" in browser) echo firefox.desktop ;; terminal) echo foot.desktop ;; editor) echo org.gnome.TextEditor.desktop ;;
    pdf) echo org.gnome.Papers.desktop ;; images) echo org.gnome.Loupe.desktop ;; video|music) echo io.github.celluloid_player.Celluloid.desktop ;;
    files) echo org.gnome.Nautilus.desktop ;; esac
}

# apps_candidates <kind> [table]: the apps that can be a kind's default, id <tab> name, by name. A table
# from apps_table, when given, saves reading every entry again.
apps_candidates() {
  local rule cats types out
  rule=$(apps_kind_rule "$1"); cats=${rule%%|*}; rule=${rule#*|}; types=${rule%%|*}; out=${rule#*|}
  if [[ -n "${2:-}" ]]; then printf '%s\n' "$2"; else apps_table; fi | CATS="$cats" TYPES="$types" OUT="$out" awk -F '\t' '
    function any(list, field,   n, a, i) { n = split(list, a, " "); for (i = 1; i <= n; i++) if (index(field, ";" a[i] ";")) return 1; return 0 }
    (any(ENVIRON["CATS"], $3) || any(ENVIRON["TYPES"], $4)) && !any(ENVIRON["OUT"], $3) { print $1 "\t" $2 }' |
    sort -t "$(printf '\t')" -k2,2f
}

# The terminal xdg-terminal-exec opens: the first entry of xdg-terminals.list (its own format: one desktop ID
# a line, an action after a colon, "-" lines excluded).
apps_terminal_listed() {
  [[ -f "$apps_terminals" ]] || return 0
  sed -n -e 's/[[:space:]]*#.*//' -e '/^-/d' -e 's/^+//' -e 's/:.*//' -e '/^[[:space:]]*$/d' -e 'p;q' "$apps_terminals"
}

# apps_listed_default <type>: the default ~/.config/mimeapps.list names for a type. Takumi's own choices
# and xdg-mime's changes both live there, so it is read directly, which is quicker than xdg-mime for a key
# press; nothing when a desktop's own mimeapps.list could win over it.
apps_listed_default() {
  local f="$apps_config/mimeapps.list"
  [[ -f "$f" ]] || return 0
  if ls "$apps_config"/*-mimeapps.list >/dev/null 2>&1; then return 0; fi
  awk -F '=' -v t="$1" '/^\[/ { g = ($0 == "[Default Applications]"); next } g && $1 == t { sub(/;.*/, "", $2); print $2; exit }' "$f"
}

# apps_default <kind>: the app a kind opens: the one chosen (mimeapps.list, else xdg-mime, or
# xdg-terminals.list for the terminal), else Takumi's own. Fails when neither is installed.
apps_default() {
  local id=""
  if [[ $1 == terminal ]]; then id=$(apps_terminal_listed)
  else
    id=$(apps_listed_default "$(apps_kind_primary "$1")")
    if [[ -z "$id" ]] || ! apps_path "$id" >/dev/null; then
      id=""
      if command -v xdg-mime >/dev/null; then id=$(xdg-mime query default "$(apps_kind_primary "$1")" 2>/dev/null | head -n 1 | sed 's/;.*//' || true); fi
    fi
  fi
  if [[ -n "$id" ]] && apps_path "$id" >/dev/null; then printf '%s\n' "$id"; return 0; fi
  id=$(apps_takumi_default "$1")
  if [[ -n "$id" ]] && apps_path "$id" >/dev/null; then printf '%s\n' "$id"; return 0; fi
  return 1
}

# Every kind's default at once: kind <tab> id (empty when none).
apps_defaults_all() {
  local k
  for k in $apps_kinds; do printf '%s\t%s\n' "$k" "$(apps_default "$k" 2>/dev/null || true)"; done
}

# apps_set_default <kind> <id>: 0 set · 4 no such app · 5 xdg-utils is missing. The browser goes through
# xdg-settings too, which is what browsers ask when they check whether they are the default.
apps_set_default() {
  local kind=$1 id=${2%.desktop}.desktop f declared primary types t
  f=$(apps_path "$id") || return 4
  if [[ $kind == terminal ]]; then
    mkdir -p "$apps_config"
    { printf '# The terminal for Super+Return and terminal apps, then the others. Written by takumi app default terminal.\n%s\n' "$id"
      if [[ -f "$apps_terminals" ]]; then sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$apps_terminals" | awk -v id="$id" '{ k = $0; sub(/^[+-]/, "", k); sub(/:.*/, "", k) } k != id'; fi
    } > "$apps_terminals.new"
    mv "$apps_terminals.new" "$apps_terminals"
    return 0
  fi
  command -v xdg-mime >/dev/null || return 5
  declared=";$(apps_key "$f" MimeType);"
  primary=$(apps_kind_primary "$kind"); types=$primary
  for t in $(apps_kind_types "$kind"); do
    if [[ "$t" != "$primary" && "$declared" == *";$t;"* ]]; then types+=" $t"; fi
  done
  if [[ $kind == browser ]] && command -v xdg-settings >/dev/null; then xdg-settings set default-web-browser "$id" >/dev/null 2>&1 || true; fi
  # shellcheck disable=SC2086 # one argument per type
  xdg-mime default "$id" $types
}

# --- Web apps -----------------------------------------------------------------------------------------

# apps_slug <name>: "Google Calendar" -> google-calendar.
apps_slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//'; }

# A web address Takumi takes: http or https, a host, and only the characters an address may hold.
apps_url_ok() {
  local re='^https?://[A-Za-z0-9.-]+(:[0-9]+)?([/?#][]A-Za-z0-9._~:/?#[@!&'\''()*+,;=%-]*)?$'
  [[ "$1" =~ $re ]]
}
apps_url_hostport() { local h=${1#*://}; h=${h%%[/?#]*}; printf '%s\n' "$h"; }
apps_url_host() { local h; h=$(apps_url_hostport "$1"); printf '%s\n' "${h%%:*}" | tr '[:upper:]' '[:lower:]'; }
apps_url_origin() { printf '%s://%s\n' "${1%%://*}" "$(apps_url_hostport "$1")"; }
apps_url_path() {  # the path alone, "/" when there is none
  local p=${1#*://}
  p=${p#"$(apps_url_hostport "$1")"}; p=${p%%[?#]*}
  printf '%s\n' "${p:-/}"
}
# apps_url_resolve <href> <base>: a link from a page, made whole.
apps_url_resolve() {
  local h b=${2%%[?#]*} rest
  h=$(printf '%s' "$1" | sed 's/&amp;/\&/g')
  case "$h" in
    "" | data:* | javascript:*) return 1 ;;
    http://* | https://*) printf '%s\n' "$h" ;;
    //*) printf '%s:%s\n' "${b%%://*}" "$h" ;;
    /*) printf '%s%s\n' "$(apps_url_origin "$b")" "$h" ;;
    *) rest=${b#*://}
       if [[ "$rest" == */* ]]; then printf '%s/%s\n' "${b%/*}" "$h"; else printf '%s/%s\n' "$b" "$h"; fi ;;
  esac
}
# Two hosts are the same site when they differ at most by "www.".
apps_same_site() { [[ -n "$1" && ( "$1" == "$2" || "www.$1" == "$2" || "$1" == "www.$2" ) ]]; }

# The browsers with an app mode (--app=), best first: the Chromium family, from Arch or from Flathub. Each
# line: desktop id <tab> the word Chromium starts an app window's Wayland app_id with.
apps_web_browsers() {
  printf '%s\t%s\n' chromium.desktop chrome org.chromium.Chromium.desktop chrome google-chrome.desktop chrome com.google.Chrome.desktop chrome \
    brave-browser.desktop brave com.brave.Browser.desktop brave microsoft-edge.desktop msedge com.microsoft.Edge.desktop msedge \
    vivaldi-stable.desktop vivaldi com.vivaldi.Vivaldi.desktop vivaldi
}
# apps_web_browser: the browser web apps open in, "id <tab> prefix": the default one when it has an app mode,
# else the first of them that is installed. Fails when none is.
apps_web_browser() {
  local def id p all
  all=$(apps_web_browsers)
  def=$(apps_default browser 2>/dev/null || true)
  while IFS=$'\t' read -r id p; do
    if [[ "$id" == "$def" ]]; then printf '%s\t%s\n' "$id" "$p"; return 0; fi
  done <<< "$all"
  while IFS=$'\t' read -r id p; do
    if apps_path "$id" >/dev/null; then printf '%s\t%s\n' "$id" "$p"; return 0; fi
  done <<< "$all"
  return 1
}
# apps_web_appid <prefix> <url>: the Wayland app_id Chromium gives an --app window: the prefix, the host and
# the path with every character a file name cannot hold made "_", and the profile ("Default").
apps_web_appid() {
  printf '%s-%s_%s-Default\n' "$1" "$(apps_url_hostport "$2" | sed 's#["~*/:<>?\| ]#_#g')" "$(apps_url_path "$2" | sed 's#["~*/:<>?\| ]#_#g')"
}

# Every web app made here: slug <tab> name <tab> address.
apps_web_list() {
  local f slug
  for f in "$apps_web_dir"/takumi-web-*.desktop; do
    [[ -f "$f" ]] || continue
    slug=${f##*/takumi-web-}; slug=${slug%.desktop}
    printf '%s\t%s\t%s\n' "$slug" "$(apps_key "$f" Name)" "$(apps_key "$f" X-Takumi-Web)"
  done
}
apps_web_remove() {
  rm -f "$apps_web_dir/takumi-web-$1.desktop" "$apps_icons"/*/apps/"takumi-web-$1".png "$apps_icons"/*/apps/"takumi-web-$1".svg
}

# apps_html_tags <page> <tag>: rel or name <tab> sizes or property <tab> type <tab> href or content, for each
# <link> (tag "link") or <meta> (tag "meta") in a page.
apps_html_tags() {
  tr '\n\r\t' '   ' < "$1" | awk -v want="$2" '
    function attr(tag, lt, name,   v) {
      if (match(lt, "[ ]" name "[ ]*=[ ]*\"[^\"]*\"")) { v = substr(tag, RSTART, RLENGTH); sub(/^[^"]*"/, "", v); sub(/"$/, "", v); return v }
      if (match(lt, "[ ]" name "[ ]*=[ ]*\047[^\047]*\047")) { v = substr(tag, RSTART, RLENGTH); sub(/^[^\047]*\047/, "", v); sub(/\047$/, "", v); return v }
      if (match(lt, "[ ]" name "[ ]*=[ ]*[^ >]+")) { v = substr(tag, RSTART, RLENGTH); sub(/^[^=]*=[ ]*/, "", v); return v }
      return ""
    }
    { s = $0
      while (match(tolower(s), "<" want "[ ][^>]*>")) {
        tag = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH); lt = tolower(tag)
        if (want == "link") print tolower(attr(tag, lt, "rel")) "\t" attr(tag, lt, "sizes") "\t" tolower(attr(tag, lt, "type")) "\t" attr(tag, lt, "href")
        else print tolower(attr(tag, lt, "name")) "\t" tolower(attr(tag, lt, "property")) "\t\t" attr(tag, lt, "content")
      } }'
}
apps_html_text() { sed 's/&amp;/\&/g; s/&#39;/'\''/g; s/&#x27;/'\''/g; s/&quot;/"/g; s/&lt;/</g; s/&gt;/>/g; s/^[[:space:]]*//; s/[[:space:]]*$//'; }

# apps_page_name <page>: a site's own short name: its application-name or og:site_name, else its title cut
# at " - " or " | " when that leaves something short.
apps_page_name() {
  local n t
  n=$(apps_html_tags "$1" meta | awk -F '\t' '!f && ($1 == "application-name" || $2 == "og:site_name") { print $4; f = 1 }' | apps_html_text)
  if [[ -z "$n" ]]; then
    t=$(tr '\n\r' '  ' < "$1" | sed -n 's/.*<[Tt][Ii][Tt][Ll][Ee][^>]*>\([^<]*\)<\/[Tt][Ii][Tt][Ll][Ee]>.*/\1/p' | apps_html_text)
    t=$(printf '%s' "$t" | sed 's/ [-|:] .*//; s/ – .*//; s/ — .*//')
    [[ ${#t} -le 32 ]] && n=$t
  fi
  printf '%s\n' "$n"
}
# apps_host_name <host>: a name from an address when the page has none: web.whatsapp.com -> Whatsapp.
apps_host_name() {
  local h=$1 w
  h=${h#www.}; h=${h#web.}; h=${h#app.}; h=${h#m.}
  w=${h%%.*}
  printf '%s%s\n' "$(printf '%s' "${w:0:1}" | tr '[:lower:]' '[:upper:]')" "${w:1}"
}

# apps_letter_icon <file> <name> <slug>: an icon drawn here, the name's first letter on a colour picked by the
# slug, for a site that gives none.
apps_letter_icon() {
  local letter n
  letter=$(printf '%s' "${2:0:1}" | tr '[:lower:]' '[:upper:]' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  n=$(( $(printf '%s' "$3" | cksum | cut -d' ' -f1) % 8 + 1 ))
  mkdir -p "$(dirname "$1")"
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect x="4" y="4" width="56" height="56" rx="14" fill="%s"/><text x="32" y="43" text-anchor="middle" font-family="Inter, sans-serif" font-size="30" font-weight="600" fill="#ffffff">%s</text></svg>\n' \
    "$(echo '#3f6fb5 #2f8f83 #8a5bb8 #c0573e #4f7d2f #b0446f #36708f #8a6d2c' | cut -d' ' -f"$n")" "${letter:-•}" > "$1"
}

# apps_fetch <url> <file>: one small download (2 MB at most), quiet, eight seconds at most. Prints the address
# it ended at after redirects.
apps_fetch() { curl -q -fsSL --max-time 8 --max-filesize 2000000 -o "$2" -w '%{url_effective}' "$1" 2>/dev/null; }

# The icon links a page offers, best first: apple-touch-icon, then the manifest's icons by size, then PNG and
# SVG icon links by size. One address a line.
apps_icon_links() {
  local page=$1 base=$2 tmp=$3 links man u
  links=$(apps_html_tags "$page" link)
  printf '%s\n' "$links" | awk -F '\t' '$1 ~ /(^| )apple-touch-icon(-precomposed)?( |$)/ { n = 0; if (match($2, /[0-9]+/)) n = substr($2, RSTART, RLENGTH) + 0; print n "\t" $4 }' |
    sort -t "$(printf '\t')" -k1,1nr | cut -f2 | while IFS= read -r u; do apps_url_resolve "$u" "$base" || true; done
  man=$(printf '%s\n' "$links" | awk -F '\t' '!f && $1 ~ /(^| )manifest( |$)/ { print $4; f = 1 }')
  if [[ -n "$man" ]] && man=$(apps_url_resolve "$man" "$base") && man=$(apps_fetch "$man" "$tmp/manifest"); then
    jq -r '.icons // [] | map(select(((.type // "") | test("png|svg")) or ((.src // "") | test("[.](png|svg)($|[?])"))))
      | map(. + {n: (if ((.sizes // "") | test("any")) then 1000 else ([(.sizes // "") | scan("[0-9]+") | tonumber] | max // 0) end)})
      | sort_by(-.n) | .[].src' "$tmp/manifest" 2>/dev/null | while IFS= read -r u; do apps_url_resolve "$u" "$man" || true; done
  fi
  printf '%s\n' "$links" | awk -F '\t' '$1 ~ /(^| )icon( |$)/ && ($3 ~ /png|svg/ || $4 ~ /[.](png|svg)($|[?])/) { n = 0; if ($2 ~ /any/ || $4 ~ /[.]svg/) n = 1000; else if (match($2, /[0-9]+/)) n = substr($2, RSTART, RLENGTH) + 0; print n "\t" $4 }' |
    sort -t "$(printf '\t')" -k1,1nr | cut -f2 | while IFS= read -r u; do apps_url_resolve "$u" "$base" || true; done
}

# apps_web_icon <url> <slug> <name>: puts takumi-web-<slug> in the icon theme and prints that name. The
# site's own icon when the site you asked for gives one, from its own page (never from a sign-in page on
# another site it sent you to, and never from anyone else); otherwise a letter on a colour, drawn here.
apps_web_icon() {
  local url=$1 slug=$2 name=$3 tmp final u kind="" icon="takumi-web-$2"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/takumi-icon.XXXXXX")
  final=$(apps_fetch "$url" "$tmp/page" || true)
  {
    if [[ -s "$tmp/page" ]] && apps_same_site "$(apps_url_host "$url")" "$(apps_url_host "${final:-$url}")"; then
      apps_icon_links "$tmp/page" "${final:-$url}" "$tmp"
    fi
    printf '%s/apple-touch-icon.png\n' "$(apps_url_origin "$url")"
  } | awk '!seen[$0]++' > "$tmp/links"
  while IFS= read -r u; do
    rm -f "$tmp/icon"
    apps_fetch "$u" "$tmp/icon" >/dev/null || continue
    if [[ "$(LC_ALL=C head -c 4 "$tmp/icon" | tail -c 3)" == PNG ]]; then kind=png; break; fi
    LC_ALL=C head -c 4096 "$tmp/icon" > "$tmp/start"
    if LC_ALL=C grep -qi '<svg' "$tmp/start"; then kind=svg; break; fi
  done < "$tmp/links"
  rm -f "$apps_icons"/*/apps/"$icon".png "$apps_icons"/*/apps/"$icon".svg
  case "$kind" in
    png) mkdir -p "$apps_icons/256x256/apps"; cp "$tmp/icon" "$apps_icons/256x256/apps/$icon.png" ;;
    svg) mkdir -p "$apps_icons/scalable/apps"; cp "$tmp/icon" "$apps_icons/scalable/apps/$icon.svg" ;;
    *) apps_letter_icon "$apps_icons/scalable/apps/$icon.svg" "$name" "$slug" ;;
  esac
  rm -rf "$tmp"
  printf '%s\n' "$icon"
}

# apps_web_write <slug> <name> <url> <browser id> <prefix> <icon> <comment>: the web app's entry. The browser
# runs the site as an app (--app), with a window class of its own (--class, which names the window on X11);
# on Wayland Chromium names an app window after its address, so StartupWMClass says that name and the Core
# shows the web app's name and icon for its window.
apps_web_write() {
  local slug=$1 name=$2 url=$3 bid=$4 prefix=$5 icon=$6 comment=$7 f line="" w words
  f=$(apps_path "$bid") || return 1
  words=$(apps_exec_of "$f")
  while IFS= read -r w; do [[ -z "$w" ]] || line+="$(apps_exec_arg "$w") " || return 1; done <<< "$words"
  [[ -n "$line" ]] || return 1
  line+="$(apps_exec_arg "--app=$url") --class=takumi-web-$slug" || return 1
  mkdir -p "$apps_web_dir"
  printf '%s\n' "[Desktop Entry]" "Type=Application" "Name=$name" "Comment=$comment" "Exec=$line" "Icon=$icon" \
    "Categories=Network;" "Keywords=web;app;$(apps_url_host "$url");" "StartupWMClass=$(apps_web_appid "$prefix" "$url")" \
    "StartupNotify=true" "Terminal=false" "X-Takumi-Web=$url" "X-Takumi-Browser=$bid" > "$apps_web_dir/takumi-web-$slug.desktop.new"
  mv "$apps_web_dir/takumi-web-$slug.desktop.new" "$apps_web_dir/takumi-web-$slug.desktop"
}

# --- Removing apps ------------------------------------------------------------------------------------

# Every package in Takumi's own lists, one a line: the lists every update installs, which a removal would
# not outlast.
apps_takumi_packages() {
  local d
  for d in "$apps_here/../install/packages" /usr/share/takumi/packages; do
    ls "$d"/*.txt >/dev/null 2>&1 || continue
    sed 's/#.*//; s/\[.*\]//; s/[[:space:]]//g; /^$/d' "$d"/*.txt
    return 0
  done
}

# Flatpak apps: id <tab> name <tab> user or system.
apps_flatpak_apps() {
  command -v flatpak >/dev/null || return 0
  flatpak list --app --columns=application,name,installation 2>/dev/null |
    awk -F '\t' 'NF >= 2 && $1 != "" { print $1 "\t" $2 "\t" ($3 == "system" ? "system" : "user") }'
}

# Apps installed apart from Takumi: package <tab> desktop id <tab> name. A package someone asked for (pacman
# -Qqe), outside Takumi's lists, that puts an app a person can see among the system's apps. One line a
# package.
apps_pacman_apps() {
  command -v pacman >/dev/null || return 0
  local files=() id f explicit lists list
  list=$(apps_list)
  while IFS=$'\t' read -r id f; do
    case "$f" in "" | "$HOME"/* | */flatpak/*) continue ;; esac
    files+=("$f")
  done <<< "$list"
  [[ ${#files[@]} -gt 0 ]] || return 0
  explicit=" $(pacman -Qqe 2>/dev/null | tr '\n' ' ') "
  lists=" $(apps_takumi_packages | tr '\n' ' ') "
  LC_ALL=C pacman -Qo "${files[@]}" 2>/dev/null | sed -n 's/^.*\/\([^/]*\.desktop\) is owned by \([^ ]*\) .*$/\1	\2/p' |
    EXPLICIT="$explicit" LISTS="$lists" awk -F '\t' '
      NR == FNR { name[$1] = $2; next }
      ($1 in name) && index(ENVIRON["EXPLICIT"], " " $2 " ") && !index(ENVIRON["LISTS"], " " $2 " ") && !seen[$2]++ { print $2 "\t" $1 "\t" name[$1] }' \
      <(apps_table | cut -f1,2) -
}

# --- The Shelf ----------------------------------------------------------------------------------------

# install/shelf.tsv: beside the command that runs (a checkout), else where the installer put it.
apps_shelf_file() {
  local f
  for f in "$apps_here/../install/shelf.tsv" /usr/share/takumi/shelf.tsv; do [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }; done
  return 1
}

# --- Windows in a window ------------------------------------------------------------------------------

apps_windows_name=takumi-windows
apps_windows_disk="$apps_data/takumi/windows"      # Windows' own disk, inside the container's /storage
apps_windows_conf="$apps_state/windows"            # env (only you can read it) and the ready mark
apps_windows_env="$apps_windows_conf/env"
apps_windows_share="$HOME/Windows"
# The image (https://github.com/dockur/windows): Windows on Intel and AMD, Windows on Arm on aarch64.
apps_windows_image() {
  case "$(uname -m)" in x86_64) echo docker.io/dockurr/windows ;; aarch64 | arm64) echo docker.io/dockurr/windows-arm ;; *) return 1 ;; esac
}
apps_windows_exists() { command -v podman >/dev/null && podman container exists "$apps_windows_name" >/dev/null 2>&1; }
apps_windows_running() { [[ "$(podman container inspect --format '{{.State.Running}}' "$apps_windows_name" 2>/dev/null)" == true ]]; }
# FreeRDP 3's clients, best first. Version 3 reads its arguments from stdin, so the password never sits in
# the process list.
apps_freerdp() {
  local b
  for b in xfreerdp3 sdl-freerdp3; do command -v "$b" >/dev/null && { printf '%s\n' "$b"; return 0; }; done
  return 1
}
# apps_windows_rdp <arguments...>: FreeRDP to Windows on 127.0.0.1, every argument and the password on its
# stdin, one a line (/args-from:stdin).
apps_windows_rdp() {
  local bin user pass
  bin=$(apps_freerdp) || return 127
  user=$(sed -n 's/^USERNAME=//p' "$apps_windows_env" 2>/dev/null); pass=$(sed -n 's/^PASSWORD=//p' "$apps_windows_env" 2>/dev/null)
  printf '%s\n' "/v:127.0.0.1:3389" "/u:$user" "/p:$pass" "/cert:ignore" "$@" | "$bin" /args-from:stdin
}
# True once Windows lets the account in: FreeRDP signs in and leaves (+auth-only).
apps_windows_answers() { apps_windows_rdp +auth-only >/dev/null 2>&1; }
# The "Windows" app in the Core: its entry and an icon drawn here.
apps_windows_entry() {
  mkdir -p "$apps_web_dir" "$apps_icons/scalable/apps"
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#5a8fd6" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5.5h16a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1-1.5 1.5H4A1.5 1.5 0 0 1 2.5 16V7A1.5 1.5 0 0 1 4 5.5zM9 20.5h6M12 17.5v3M12 5.5v12M2.5 11.5h19"/></svg>' \
    > "$apps_icons/scalable/apps/$apps_windows_name.svg"
  printf '%s\n' "[Desktop Entry]" "Type=Application" "Name=Windows" "Comment=Windows programs, full screen; it shuts down when you close it" \
    "Exec=takumi app windows" "Icon=$apps_windows_name" "Categories=System;Emulator;" "Keywords=windows;microsoft;exe;office;vm;" \
    "StartupWMClass=$apps_windows_name" "Terminal=false" > "$apps_web_dir/$apps_windows_name.desktop"
}

# --- Coding agents ------------------------------------------------------------------------------------

apps_agents="claude codex opencode"
apps_agent_ok() { [[ -n "$1" && " $apps_agents " == *" $1 "* ]]; }
apps_agent_label() { case "$1" in claude) echo "Claude Code" ;; codex) echo Codex ;; opencode) echo OpenCode ;; esac; }
# apps_agent_bin <agent>: where it is installed: in PATH, or where its own installer puts it.
apps_agent_bin() {
  local b
  b=$(command -v "$1" 2>/dev/null || true)
  if [[ -z "$b" && $1 == claude && -x "$HOME/.local/bin/claude" ]]; then b="$HOME/.local/bin/claude"; fi
  if [[ -z "$b" && $1 == opencode && -x "$HOME/.opencode/bin/opencode" ]]; then b="$HOME/.opencode/bin/opencode"; fi
  [[ -n "$b" ]] || return 1
  printf '%s\n' "$b"
}
# apps_agent_install <agent>: Claude Code from Anthropic's own installer, which puts it in ~/.local/bin and
# needs no password (https://code.claude.com/docs/en/setup); Codex and OpenCode from Arch's packages. Needs
# lib/core.sh, for the password.
apps_agent_install() {
  case "$1" in
    claude) curl -q -fsSL https://claude.ai/install.sh | bash ;;
    # pacman: Codex's files under /usr and its entry in /var/lib/pacman
    codex) core_sudo "Installing Codex needs your password" pacman -S --needed --noconfirm openai-codex ;;
    # pacman: OpenCode's files under /usr and its entry in /var/lib/pacman
    opencode) core_sudo "Installing OpenCode needs your password" pacman -S --needed --noconfirm opencode ;;
    *) return 2 ;;
  esac
}

# --- Rootless containers ------------------------------------------------------------------------------

# True when you have a range of user IDs of your own, which Podman needs to run containers as you.
apps_subids_have() {
  local u; u=$(id -un)
  if getsubids "$u" >/dev/null 2>&1; then return 0; fi
  grep -q "^$u:" /etc/subuid 2>/dev/null
}
# The range to add when you have none: 65536 IDs from 100000, one block per user ID, so no two people overlap.
apps_subids_range() {
  local u f
  u=$(id -u); if (( u < 1000 )); then u=1000; fi
  f=$(( 100000 + (u - 1000) * 65536 ))
  printf '%s-%s\n' "$f" "$(( f + 65535 ))"
}

# --- Open at login -------------------------------------------------------------------------------------

# Apps that open when you log in are XDG autostart entries (the desktop entry spec's autostart folders):
# yours in ~/.config/autostart, the system's in /etc/xdg/autostart (TAKUMI_AUTOSTART_SYSTEM for the tests).
# Turning one on copies its entry into yours; turning it off removes yours, or, for one the system ships,
# writes yours with Hidden=true, which the spec says wins. niri's session starts them
# (xdg-desktop-autostart.target; commands/session/start starts it where niri runs on its own).
apps_login_dir="$apps_config/autostart"
apps_login_system="${TAKUMI_AUTOSTART_SYSTEM:-/etc/xdg/autostart}"

# apps_login_list: every app that opens at login: id <tab> name. The system's own helpers (entries with
# NoDisplay=true, or limited to other desktops by OnlyShowIn) are not apps a person chose and are left out.
apps_login_list() {
  local f id seen=" " hidden show nodisp
  for f in "$apps_login_dir"/*.desktop "$apps_login_system"/*.desktop; do
    [[ -f "$f" ]] || continue
    id=${f##*/}; [[ "$seen" == *" $id "* ]] && continue; seen+="$id "
    hidden=$(apps_key "$f" Hidden); nodisp=$(apps_key "$f" NoDisplay); show=$(apps_key "$f" OnlyShowIn)
    [[ "$hidden" == true || "$nodisp" == true ]] && continue
    [[ -n "$show" && ";$show" != *";niri;"* ]] && continue
    printf '%s\t%s\n' "${id%.desktop}" "$(apps_key "$f" Name)"
  done
}

# apps_login_is <id>: it opens at login.
apps_login_is() { grep -qxF "${1%.desktop}" <<< "$(apps_login_list | cut -f1)"; }

# apps_login_set <id> on|off
apps_login_set() {
  local id=${1%.desktop} f
  mkdir -p "$apps_login_dir"
  if [[ "$2" == on ]]; then
    f=$(apps_path "$id") || return 4
    grep -v -E '^(Hidden|X-GNOME-Autostart-enabled)=' "$f" > "$apps_login_dir/$id.desktop.tmp"
    mv -f "$apps_login_dir/$id.desktop.tmp" "$apps_login_dir/$id.desktop"
  else
    rm -f "$apps_login_dir/$id.desktop"
    if [[ -f "$apps_login_system/$id.desktop" ]]; then
      printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$(apps_key "$apps_login_system/$id.desktop" Name)" > "$apps_login_dir/$id.desktop"
    fi
  fi
}

# apps_find <id or name>: the desktop ID of an app, by its ID or, ignoring case, its name.
apps_find() {
  local want=$1 wl
  if apps_path "$want" >/dev/null 2>&1; then printf '%s\n' "${want%.desktop}"; return 0; fi
  wl=$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')
  # The whole table is read (no early exit), so the writer never meets a closed pipe under pipefail.
  apps_table | W="$wl" awk -F '\t' '!f && tolower($2) == ENVIRON["W"] { sub(/\.desktop$/, "", $1); print $1; f = 1 } END { exit !f }'
}
