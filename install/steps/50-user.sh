#!/usr/bin/env bash
set -euo pipefail
# The installing user's home is set up the way every home is: by its migrations, the first of which copies
# the settings Takumi ships (docs/migrations.md). Other accounts get the same at their first login.
takumi migrate

# The guide (guide/*.md), for the Palette's Help row: each page as HTML the browser opens with nothing more
# installed, at /usr/share/takumi/guide (README.md is index.html). Only what the guide uses is understood:
# headings, paragraphs, lists, tables, fenced code, `code`, **bold** and links; a link to another page of the
# guide goes to its HTML, one outside it (docs/) stays as words.
guide_html() {   # <page.md>: the page as HTML on stdout
  awk '
    function esc(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
    function links(s,   out, t, u) {
      out = ""
      while (match(s, /\[[^]]*\]\([^)]*\)/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2); u = t; sub(/\]\(.*/, "", t); sub(/^[^]]*\]\(/, "", u)
        out = out substr(s, 1, RSTART - 1)
        if (u ~ /^https?:/) out = out "<a href=\"" u "\">" t "</a>"
        else if (u ~ /^[a-z0-9-]+\.md(#.*)?$/) { sub(/\.md/, ".html", u); sub(/^README\.html/, "index.html", u); out = out "<a href=\"" u "\">" t "</a>" }
        else out = out t
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }
    function bold(s,   out) {
      out = ""
      while (match(s, /\*\*[^*]+\*\*/)) { out = out substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>"; s = substr(s, RSTART + RLENGTH) }
      return out s
    }
    # Between backticks is code, kept as it is; the rest gets links and bold.
    function inline(s,   n, parts, i, out) {
      n = split(esc(s), parts, "`"); out = ""
      for (i = 1; i <= n; i++) out = out ((i % 2) ? bold(links(parts[i])) : "<code>" parts[i] "</code>")
      return out
    }
    function close_all() {
      if (para != "") { print "<p>" inline(para) "</p>"; para = "" }
      if (item != "") { print "<li>" inline(item) "</li>"; item = "" }
      if (list != "") { print "</" list ">"; list = "" }
      if (table) { print "</tbody></table>"; table = 0 }
    }
    function cells(s, tag,   n, c, i, out) {
      sub(/^\|/, "", s); sub(/\|[ \t]*$/, "", s); n = split(s, c, "|"); out = "<tr>"
      for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t]+$/, "", c[i]); out = out "<" tag ">" inline(c[i]) "</" tag ">" }
      return out "</tr>"
    }
    fence { if ($0 ~ /^```/) { print "</code></pre>"; fence = 0 } else print esc($0); next }
    /^```/ { close_all(); print "<pre><code>"; fence = 1; next }
    /^#+ / { close_all(); n = index($0, " ") - 1; h = substr($0, n + 2); if (title == "") title = h
             id = tolower(h); gsub(/[^a-z0-9 -]/, "", id); gsub(/ /, "-", id)   # what a link to #the-heading finds
             print "<h" n " id=\"" id "\">" inline(h) "</h" n ">"; next }
    /^\|/ { if (!table) { close_all(); print "<table><thead>" cells($0, "th") "</thead><tbody>"; table = 1; next }
            if ($0 ~ /^\|[ \t:|-]+$/) next
            print cells($0, "td"); next }
    /^[-*] / || /^[0-9]+\. / {
      want = ($0 ~ /^[0-9]/) ? "ol" : "ul"
      if (para != "") close_all()
      if (item != "") { print "<li>" inline(item) "</li>"; item = "" }
      if (list != want) { if (list != "") print "</" list ">"; print "<" want ">"; list = want }
      item = $0; sub(/^([-*]|[0-9]+\.) /, "", item); next }
    /^[ \t]*$/ { close_all(); next }
    { line = $0; sub(/^[ \t]+/, "", line)
      if (item != "") item = item " " line; else para = (para == "" ? line : para " " line) }
    END { close_all() }
  ' "$1" > "$1.body.tmp"
  local title
  title=$(sed -n 's/^# //p' "$1" | head -n 1)
  cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title:-Takumi} · Takumi guide</title>
<style>
  :root { color-scheme: light dark; --bg: #f6f7f9; --fg: #1b2129; --dim: #5b6573; --line: #dde1e6; --accent: #0a84c6; --code: #eceff3; }
  @media (prefers-color-scheme: dark) { :root { --bg: #0b0f14; --fg: #d9e2ec; --dim: #8b97a6; --line: #1f2833; --accent: #5ad7ff; --code: #151c25; } }
  body { margin: 0; background: var(--bg); color: var(--fg); font: 17px/1.6 Inter, system-ui, sans-serif; }
  main { max-width: 44rem; margin: 0 auto; padding: 3rem 1.25rem 5rem; }
  h1 { font-weight: 300; font-size: 2.2rem; letter-spacing: -0.02em; margin: 0 0 1.5rem; }
  h2 { font-weight: 500; font-size: 1.3rem; margin: 2.4rem 0 0.6rem; }
  a { color: var(--accent); }
  code { font: 0.9em "JetBrains Mono", ui-monospace, monospace; background: var(--code); padding: 0.1em 0.35em; border-radius: 4px; }
  pre code { display: block; padding: 0.8rem 1rem; overflow-x: auto; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; font-size: 0.92rem; display: block; overflow-x: auto; }
  th, td { text-align: left; padding: 0.45rem 0.7rem; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { color: var(--dim); font-weight: 500; }
  nav { margin-bottom: 2rem; font-size: 0.9rem; } nav a { text-decoration: none; }
</style>
</head>
<body>
<main>
<nav><a href="index.html">Takumi guide</a></nav>
HTML
  cat "$1.body.tmp"
  rm -f "$1.body.tmp"
  printf '</main>\n</body>\n</html>\n'
}
out=$(mktemp -d)
for md in "$TAKUMI_PATH"/guide/*.md; do
  name=$(basename "$md" .md); [[ "$name" == README ]] && name=index
  cp "$md" "$out/$name.md"
  guide_html "$out/$name.md" > "$out/$name.html"
  rm -f "$out/$name.md"
done
chmod 755 "$out"; chmod 644 "$out"/*.html   # mktemp's folder is the user's alone; the guide is everyone's
sudo install -d /usr/share/takumi/guide
sudo rsync -a --delete "$out/" /usr/share/takumi/guide/   # /usr/share/takumi/guide/*.html
rm -rf "$out"
