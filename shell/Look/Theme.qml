pragma Singleton
// Colours. Reads the palette takumi theme render writes for the current theme and phase.
// Tints are alphas of the foreground, so kiln (light) and void (black) use the same numbers.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    property color accent:     "#5ad7ff"
    property color background: "#0b0f14"
    property color surface:    "#111821"
    property color foreground: "#d9e2ec"
    property color muted:      "#5c6b7a"
    property color red:        "#ff6b81"
    property color yellow:     "#ffd166"
    property color green:      "#7ee787"
    property color cyan:       "#5ad7ff"
    property color blue:       "#6ea8fe"
    property color magenta:    "#c792ea"
    // A code a phone camera reads (sharing Wi-Fi) is dark on light in every theme and phase, so these
    // two never follow the palette.
    readonly property color codePaper: "#ffffff"
    readonly property color codeInk:   "#14161b"
    property string mode:  "dark"
    property string phase: "day"
    property string name:  "ion"
    property string previewWallpaper: ""
    // Bumped once per applied file, so painters (the Sky) repaint once, not once per colour.
    property int revision: 0

    function tint(alpha) { return Qt.rgba(foreground.r, foreground.g, foreground.b, alpha); }
    function accentTint(alpha) { return Qt.rgba(accent.r, accent.g, accent.b, alpha); }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function hex(c) { const h = v => Math.round(v * 255).toString(16).padStart(2, "0"); return "#" + h(c.r) + h(c.g) + h(c.b); }

    // The login screen runs as the greeter user and reads a copy of your theme (commands/greeter/main).
    readonly property string path: Quickshell.env("TAKUMI_THEME_FILE") || (Quickshell.env("HOME") + "/.local/state/takumi/look/palette.toml")
    readonly property string repoThemesDir: String(Qt.resolvedUrl("../../themes")).replace(/^file:\/\//, "").replace(/\/$/, "")
    property FileView file: FileView {
        path: theme.path
        watchChanges: true
        printErrors: false
        blockLoading: true          // the first frame must already be in the right colours
        onFileChanged: reload()
        onLoaded: theme.apply(text())
    }
    function reload() { previewing = ""; previewWallpaper = ""; file.reload(); }

    // A look at another theme before choosing it: the Palette calls preview(name) while a theme row is
    // selected, and endPreview() when you move on or close. Both the shell colours and the Sky (or the
    // theme's wallpaper image) change live; apps are recoloured only when you choose it (takumi theme set).
    property string previewing: ""
    function preview(targetName) {
        if (!/^[a-z0-9-]+$/.test(targetName) || targetName === previewing) return;
        previewing = targetName;
        peek.command = [
            "sh", "-c",
            't=""; for d in "$HOME/.config/takumi/themes" /usr/share/takumi/themes "$3"; do [ -f "$d/$1/theme.toml" ] && { t="$d/$1"; break; }; done; ' +
            '[ -n "$t" ] || exit 0; ' +
            'bg=""; for cand in "$t/skies/$2".* "$t/skies/default".*; do [ -f "$cand" ] || continue; ' +
            'case "$cand" in *.[Pp][Nn][Gg]|*.[Jj][Pp][Gg]|*.[Jj][Pp][Ee][Gg]|*.[Ww][Ee][Bb][Pp]|*.[Bb][Mm][Pp]) bg=$cand; break ;; esac; done; ' +
            'printf "__TAKUMI_WP__=%s\\n" "$bg"; cat "$t/theme.toml"',
            "_", targetName, theme.phase, theme.repoThemesDir
        ];
        peek.running = true;
    }
    function endPreview() { if (previewing === "") return; previewing = ""; previewWallpaper = ""; file.reload(); }
    property Process peek: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (theme.previewing === "") return;
                const out = {}; let sect = "", wp = "";
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("__TAKUMI_WP__=")) { wp = line.slice(14).trim(); continue; }
                    const s = line.match(/^\[([a-z.]+)\]/);
                    if (s) { sect = s[1]; continue; }
                    const m = line.match(/^([a-z_]+)\s*=\s*"([^"]*)"/);
                    if (!m) continue;
                    if (sect === "palette" && !(m[1] in out)) out[m[1]] = m[2];
                    else if (sect === "phase." + theme.phase) out[m[1]] = m[2];
                    else if (sect === "meta" && m[1] === "mode") out.mode = m[2];
                }
                theme.previewWallpaper = wp;
                // Phase keys win over the palette whichever comes first in the file.
                theme.apply(Object.keys(out).map(k => k + ' = "' + out[k] + '"').join("\n"), true);
            }
        }
    }
    function apply(text, isPreview) {
        const next = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^([a-z_]+)\s*=\s*"([^"]*)"/);
            if (m) next[m[1]] = m[2];
        }
        // The file changed under a preview: choosing the previewed theme ends the preview at once (the Sky
        // plays its opening now); anything else waits for endPreview to reload it.
        if (!isPreview && previewing !== "") {
            if (next.name !== previewing) return;
            previewing = ""; previewWallpaper = "";
        }
        const ok = s => /^#[0-9a-fA-F]{6}$/.test(s ?? "");
        if (ok(next.accent))     accent = next.accent;
        if (ok(next.background)) background = next.background;
        if (ok(next.surface))    surface = next.surface;
        if (ok(next.foreground)) foreground = next.foreground;
        if (ok(next.muted))      muted = next.muted;
        if (ok(next.red))        red = next.red;
        if (ok(next.yellow))     yellow = next.yellow;
        if (ok(next.green))      green = next.green;
        if (ok(next.cyan))       cyan = next.cyan;
        if (ok(next.blue))       blue = next.blue;
        if (ok(next.magenta))    magenta = next.magenta;
        if (next.mode)  mode = next.mode;
        if (next.phase && !isPreview) phase = next.phase;
        if (next.name && !isPreview)  name = next.name;
        revision++;
    }
}
