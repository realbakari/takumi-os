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
    # Between backticks is code; keyboard shortcuts get the .kbd class while staying valid <code> tags.
    function inline(s,   n, parts, i, out, tok) {
      n = split(esc(s), parts, "`"); out = ""
      for (i = 1; i <= n; i++) {
        if (i % 2) { out = out bold(links(parts[i])) }
        else {
          tok = parts[i]
          if (tok ~ /^(Super|Cmd|Ctrl|Win|Alt|Shift|Esc|Enter|Tab|Return)(\+|$)/ || tok ~ /^[A-Z0-9←→↑↓]$/)
            out = out "<kbd><code>" tok "</code></kbd>"
          else
            out = out "<code>" tok "</code>"
        }
      }
      return out
    }
    function close_all() {
      if (para != "") { print "<p>" inline(para) "</p>"; para = "" }
      if (item != "") { print "<li>" inline(item) "</li>"; item = "" }
      if (list != "") { print "</" list ">"; list = "" }
      if (table) { print "</tbody></table></div>"; table = 0 }
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
    /^\|/ { if (!table) { close_all(); print "<div class=\"table-card\"><table><thead>" cells($0, "th") "</thead><tbody>"; table = 1; next }
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
  local title slug
  title=$(sed -n 's/^# //p' "$1" | head -n 1)
  slug=$(basename "$1" .md)
  cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title:-Takumi} · Takumi guide</title>
<style>
  :root {
    color-scheme: light dark;
    --bg: #f6f1ea; --surface: #ebe4da; --card: rgba(235, 228, 218, 0.72);
    --fg: #26201c; --dim: #6f645b; --line: rgba(38, 32, 28, 0.11);
    --accent: #c0552f; --accent-soft: rgba(192, 85, 47, 0.12);
    --code: rgba(38, 32, 28, 0.065); --kbd-bg: #fffdf9; --shadow: rgba(20, 14, 10, 0.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0b0f14; --surface: #111821; --card: rgba(17, 24, 33, 0.78);
      --fg: #d9e2ec; --dim: #8b99a8; --line: rgba(217, 226, 236, 0.10);
      --accent: #5ad7ff; --accent-soft: rgba(90, 215, 255, 0.14);
      --code: rgba(217, 226, 236, 0.075); --kbd-bg: #17202b; --shadow: rgba(0, 0, 0, 0.42);
    }
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0; background: var(--bg); color: var(--fg);
    font: 16px/1.72 "Inter", system-ui, -apple-system, sans-serif;
    font-variant-numeric: tabular-nums;
    -webkit-font-smoothing: antialiased;
  }
  header {
    position: sticky; top: 0; z-index: 20;
    backdrop-filter: blur(22px) saturate(1.25); -webkit-backdrop-filter: blur(22px) saturate(1.25);
    background: color-mix(in srgb, var(--bg) 82%, transparent);
    border-bottom: 1px solid var(--line);
  }
  .bar {
    max-width: 50rem; margin: 0 auto; padding: 0.75rem 1.5rem;
    display: flex; align-items: center; justify-content: space-between; gap: 1rem;
  }
  .brand { display: inline-flex; align-items: center; gap: 0.65rem; text-decoration: none; color: var(--fg); font-weight: 600; font-size: 0.95rem; letter-spacing: -0.01em; }
  .mark {
    width: 26px; height: 26px; border-radius: 7px; display: inline-flex; align-items: center; justify-content: center;
    background: var(--accent); color: var(--bg); font-weight: 800; font-size: 14px; line-height: 1;
  }
  nav { display: flex; align-items: center; gap: 0.35rem; flex-wrap: wrap; }
  nav a {
    text-decoration: none; color: var(--dim); font-size: 0.85rem; font-weight: 500;
    padding: 0.35rem 0.75rem; border-radius: 999px; transition: background 120ms ease, color 120ms ease;
  }
  nav a:hover { background: var(--code); color: var(--fg); }
  nav a.on { background: var(--accent-soft); color: var(--accent); font-weight: 600; }
  main { max-width: 50rem; margin: 0 auto; padding: 3.25rem 1.5rem 6rem; }
  h1 { font-weight: 350; font-size: clamp(2.1rem, 4vw, 2.75rem); letter-spacing: -0.035em; line-height: 1.1; margin: 0 0 1.25rem; }
  h2 { font-weight: 600; font-size: 1.25rem; letter-spacing: -0.015em; margin: 3rem 0 0.75rem; padding-top: 1.25rem; border-top: 1px solid var(--line); }
  h3 { font-weight: 600; font-size: 1.02rem; margin: 1.8rem 0 0.4rem; color: var(--fg); }
  p { margin: 0 0 1.05rem; color: color-mix(in srgb, var(--fg) 88%, var(--dim)); }
  strong { color: var(--fg); font-weight: 600; }
  a { color: var(--accent); text-underline-offset: 3px; }
  ul, ol { margin: 0 0 1.2rem; padding-left: 1.35rem; }
  li { margin: 0.35rem 0; color: color-mix(in srgb, var(--fg) 88%, var(--dim)); }
  code {
    font: 0.88em "JetBrains Mono", ui-monospace, monospace;
    background: var(--code); padding: 0.14em 0.42em; border-radius: 6px;
  }
  kbd {
    display: inline-block; font: 500 0.8em "JetBrains Mono", ui-monospace, monospace;
    background: var(--kbd-bg); color: var(--fg);
    border: 1px solid var(--line); border-bottom-width: 2px;
    border-radius: 6px; padding: 0.1em 0.45em; vertical-align: 0.04em;
    box-shadow: 0 1px 2px var(--shadow);
  }
  kbd code { background: none; padding: 0; font: inherit; color: inherit; }
  pre {
    margin: 1.25rem 0; border-radius: 14px; background: var(--surface);
    border: 1px solid var(--line); overflow-x: auto; box-shadow: 0 8px 24px var(--shadow);
  }
  pre code { display: block; padding: 1rem 1.2rem; background: none; border-radius: 0; font-size: 0.86rem; line-height: 1.65; }
  .table-card {
    margin: 1.35rem 0 1.6rem; border-radius: 14px; overflow: hidden;
    background: var(--card); border: 1px solid var(--line);
    box-shadow: 0 8px 24px var(--shadow); overflow-x: auto;
  }
  table { border-collapse: collapse; width: 100%; font-size: 0.9rem; }
  thead { background: var(--code); }
  th {
    text-align: left; padding: 0.7rem 0.95rem; font-size: 0.75rem; font-weight: 600;
    letter-spacing: 0.06em; text-transform: uppercase; color: var(--dim);
    border-bottom: 1px solid var(--line);
  }
  td { text-align: left; padding: 0.7rem 0.95rem; border-bottom: 1px solid var(--line); vertical-align: top; }
  tbody tr:last-child td { border-bottom: none; }
  tbody tr:hover { background: var(--code); }
  tbody td:last-child { color: var(--fg); }
  footer {
    max-width: 50rem; margin: 0 auto; padding: 1.5rem 1.5rem 3rem;
    border-top: 1px solid var(--line); font-size: 0.82rem; color: var(--dim);
    display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
  }
</style>
</head>
<body>
<header>
  <div class="bar">
    <a class="brand" href="index.html"><span class="mark">匠</span><span>Takumi Guide</span></a>
    <nav>
      <a href="index.html"$( [[ "$slug" == index ]] && printf ' class="on"' )>Overview</a>
      <a href="your-first-hour.html"$( [[ "$slug" == your-first-hour ]] && printf ' class="on"' )>Your first hour</a>
      <a href="installing.html"$( [[ "$slug" == installing ]] && printf ' class="on"' )>Installing</a>
    </nav>
  </div>
</header>
<main>
HTML
  cat "$1.body.tmp"
  rm -f "$1.body.tmp"
  printf '</main>\n<footer><span>Takumi OS · Press <kbd>Super+Space</kbd> anywhere to open the Core</span><span>Press <kbd>Super+K</kbd> for shortcuts</span></footer>\n</body>\n</html>\n'
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
