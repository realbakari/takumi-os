// Runs every provider for the query, debounced, and merges rows by weighted score. A generation counter
// drops results from a query the user has typed past. A title match beats a description match.
// Intent's plan for a sentence is fetched (debounced) with `takumi intent --plan`. A row that
// carries `refresh` (seconds) has its provider run again that often while it is on show, so a list of
// networks or devices updates in place (Open.qml keeps your selection on the same row).
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"

QtObject {
    id: providers
    required property var niri
    property string query: ""
    property var rows: []
    property var acc: []                   // this query's rows so far, before ranking
    property var plan: []
    property int generation: 0

    readonly property var builtin: [
        { kind: "App",     weight: 1.0, appIcons: true, cmd: q => ["takumi", "palette", "index", "apps", q] },
        { kind: "Command", weight: 0.8, icon: "cmd",    cmd: q => ["takumi", "palette", "index", "commands", q] },
        { kind: "Theme",   weight: 0.7, icon: "sun",    cmd: q => ["takumi", "palette", "index", "themes", q] },
        { kind: "Calc",    weight: 1.1, icon: "eq",     cmd: q => ["takumi", "palette", "index", "calc", q] },
        { kind: "Key",     weight: 0.75, icon: "cmd",   cmd: q => ["takumi", "palette", "index", "keys", q] },
        { kind: "Get",     weight: 0.7, icon: "down",   cmd: q => ["takumi", "palette", "index", "shelf", q] },
        { kind: "Wi-Fi",   weight: 0.9, icon: "wifi",   cmd: q => ["takumi", "palette", "index", "wifi", q] },
        // Everyday settings, each its own provider: commands/palette/<name> <query> (docs/palette.md).
        { kind: "Bluetooth", weight: 0.9, icon: "bt",      cmd: q => ["takumi", "palette", "bluetooth", q] },
        { kind: "Sound",     weight: 0.9, icon: "vol",     cmd: q => ["takumi", "palette", "sound", q] },
        { kind: "Display",   weight: 0.9, icon: "display", cmd: q => ["takumi", "palette", "display", q] },
        { kind: "Power",     weight: 0.9, icon: "bolt",    cmd: q => ["takumi", "palette", "power", q] },
        { kind: "Earlier",   weight: 0.85, icon: "bell",   appIcons: true, cmd: q => ["takumi", "palette", "earlier", q] },
        { kind: "Clipboard", weight: 0.95, icon: "edit",   cmd: q => ["takumi", "palette", "clipboard", q] },
        { kind: "Emoji",     weight: 0.9,  icon: "cmd",    cmd: q => ["takumi", "palette", "emoji", q] },
        { kind: "Doctor",    weight: 0.85, icon: "pulse",  cmd: q => ["takumi", "palette", "doctor", q] },
        { kind: "Firmware",  weight: 0.8, icon: "chip",    cmd: q => ["takumi", "palette", "firmware", q] },
        { kind: "Security",  weight: 0.85, icon: "lock",   cmd: q => ["takumi", "palette", "security", q] },
        { kind: "Keyboard",  weight: 0.85, icon: "keyboard", cmd: q => ["takumi", "palette", "keyboards", q] },
        { kind: "Language",  weight: 0.85, icon: "globe",  cmd: q => ["takumi", "palette", "language", q] },
        { kind: "Hardware",  weight: 0.85, icon: "chip",   cmd: q => ["takumi", "palette", "hardware", q] },
        { kind: "Time",      weight: 0.9,  icon: "clock",  cmd: q => ["takumi", "palette", "time", q] },
        { kind: "Defaults",  weight: 0.85, icon: "globe",  cmd: q => ["takumi", "palette", "defaults", q] },
        { kind: "Quit",      weight: 0.9,  icon: "cross",  appIcons: true, cmd: q => ["takumi", "palette", "quit", q] },
        { kind: "Remote",    weight: 0.9,  icon: "person", cmd: q => ["takumi", "palette", "remote", q] },
        { kind: "Reset",     weight: 0.85, icon: "restart", cmd: q => ["takumi", "palette", "settings", q] },
        { kind: "Login",     weight: 0.85, icon: "play",   appIcons: true, cmd: q => ["takumi", "palette", "login", q] },
        { kind: "Backup",    weight: 0.85, icon: "history", cmd: q => ["takumi", "palette", "backup", q] },
        { kind: "Phone",     weight: 0.85, icon: "phone",  cmd: q => ["takumi", "palette", "phone", q] },
        { kind: "VPN",       weight: 0.9,  icon: "shield", cmd: q => ["takumi", "palette", "vpn", q] },
        { kind: "Printer",   weight: 0.85, icon: "printer", cmd: q => ["takumi", "palette", "printer", q] },
        { kind: "Drive",     weight: 0.85, icon: "usb",    cmd: q => ["takumi", "palette", "drives", q] },
        { kind: "Font",      weight: 0.8,  icon: "type",   cmd: q => ["takumi", "palette", "fonts", q] },
        { kind: "Yours",   weight: 0.9, icon: "cmd",    cmd: q => ["sh", "-c", 'for p in "$HOME"/.config/takumi/palette/*; do [ -x "$p" ] && "$p" "$1"; done', "_", q] }
    ]

    property var history: ({})
    readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/takumi/palette/history"

    property Timer debounce: Timer { interval: 40; onTriggered: providers.refresh() }
    property Timer planTimer: Timer { interval: 600; onTriggered: providers.fetchPlan() }
    onQueryChanged: {
        debounce.restart();
        plan = [];
        if (Style.intentPreview && query.trim().split(/\s+/).length >= 3) planTimer.restart(); else planTimer.stop();
    }

    function refresh() {
        generation++;
        const q = query.trim(), gen = generation, l = q.toLowerCase();
        // Empty: the first week's "Start here" rows, if any, and what apps said today.
        if (q === "") {
            rows = []; acc = [];
            const keep = r => { acc = acc.concat(r); rows = rank(acc); };
            start({ kind: "Start", weight: 1.0, icon: "cmd" }, ["takumi", "palette", "index", "start", ""], gen, keep);
            start({ kind: "Earlier", weight: 0.85, icon: "bell", appIcons: true }, ["takumi", "palette", "earlier", ""], gen, keep);
            return;
        }
        // ":" before words asks for emoji and nothing else (commands/palette/emoji).
        if (q.startsWith(":")) {
            acc = []; rows = [];
            const prov = builtin.find(p => p.kind === "Emoji");
            if (prov) start(prov, prov.cmd(q), gen, r => { acc = r; rows = rank(acc); });
            return;
        }
        let first = [];
        // Windows: answered from the niri service, no process.
        for (const w of niri.windows) {
            if (!((w.title ?? "") + " " + (w.app_id ?? "")).toLowerCase().includes(l)) continue;
            first.push({ id: "win:" + w.id, title: w.title || w.app_id, subtitle: w.app_id, appIcon: w.app_id, icon: "globe", kind: "Window", score: 1.0,
                       run: ["niri", "msg", "action", "focus-window", "--id", String(w.id)] });
        }
        // A sentence: Intent's row, asked as a conversation in the Core (takumi intent ask, docs/intent.md).
        if (q.includes(" ")) first.push({ id: "intent:" + q, title: q, subtitle: "Ask Intent", icon: "quote", kind: "Intent", score: 0.3, converse: true, run: ["takumi", "intent", "ask", q] });
        acc = first; rows = rank(acc);
        for (const prov of builtin) start(prov, prov.cmd(q), gen, r => { acc = acc.concat(r); rows = rank(acc); refreshLater(prov, r, gen); });
    }

    // A provider whose rows ask for it runs again after the shortest `refresh` among them, as long as the
    // query has not changed; its new rows replace its old ones in place.
    function refreshLater(prov, r, gen) {
        const secs = Math.min(...r.map(x => Number(x.refresh) || Infinity));
        if (!isFinite(secs) || secs <= 0) return;
        const t = refreshTimer.createObject(providers, { interval: secs * 1000, kind: prov.kind, gen: gen });
        t.start();
    }
    property Component refreshTimer: Component {
        Timer {
            property string kind; property int gen
            onTriggered: { if (gen === providers.generation) providers.rerun(kind, gen); destroy(); }
        }
    }
    function rerun(kind, gen) {
        const prov = builtin.find(p => p.kind === kind), q = query.trim();
        if (!prov || q === "") return;
        start(prov, prov.cmd(q), gen, r => { acc = acc.filter(x => x.provider !== kind).concat(r); rows = rank(acc); refreshLater(prov, r, gen); });
    }

    function start(prov, cmd, gen, done) {
        const proc = procComponent.createObject(providers, { command: cmd });
        proc.exited.connect(() => {
            if (gen === generation)
                done(proc.buf.map(r => Object.assign({}, r, {
                    provider: prov.kind,
                    kind: r.kind ?? prov.kind,
                    terminal: r.terminal ?? false,
                    icon: r.glyph ?? prov.icon ?? "cmd",
                    appIcon: prov.appIcons ? (r.icon ?? "") : "",
                    score: (r.score ?? 0.5) * prov.weight
                })));
            proc.destroy();
        });
        proc.running = true;
    }
    property Component procComponent: Component {
        Process { property var buf: []; stdout: SplitParser { onRead: line => { try { buf.push(JSON.parse(line)); } catch (e) {} } } }
    }

    // Boosts: the query starts the title or a word of it (0.5), starts a search word (0.45), or every word
    // of a longer query is in the title, hyphens ignored (0.4: "wifi off"), or the title holds it (0.3).
    // Intent's row is the query itself, so it never takes a boost: it stays the fallback.
    function rank(list) {
        const l = query.trim().toLowerCase(), qw = l.replace(/-/g, "").split(/\s+/).filter(w => w);
        const scored = list.map(r => {
            const t = (r.title ?? "").toLowerCase(), tn = t.replace(/-/g, ""), words = (r.keywords ?? "").toLowerCase().split(/\s+/);
            const boost = !l || r.kind === "Intent" ? 0
                        : (t.startsWith(l) || t.split(/[\s·]+/).some(w => w.startsWith(l))) ? 0.5
                        : words.some(w => w && w.startsWith(l)) ? 0.45
                        : qw.length > 1 && qw.every(w => tn.includes(w)) ? 0.4
                        : t.includes(l) ? 0.3 : 0;
            // A steady row keeps its provider's order: the network you are on stays first, however often
            // you picked another.
            return Object.assign({}, r, { score: r.score + boost + (r.steady ? 0 : (history[r.id] ?? 0) * 0.05) });
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, 40);
    }

    function fetchPlan() {
        planProc.running = false;
        planProc.gen = generation;
        planProc.command = ["takumi", "intent", "--plan", query.trim()];
        planProc.running = true;
    }
    property Process planProc: Process {
        property int gen: 0
        stdout: StdioCollector {
            onStreamFinished: {
                if (providers.planProc.gen !== providers.generation) return;
                try { const p = JSON.parse(this.text); if (Array.isArray(p)) providers.plan = p.map(String).slice(0, 4); } catch (e) {}
            }
        }
    }

    function remember(id) {
        history[id] = (history[id] ?? 0) + 1;
        saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"', "_", historyPath, id];
        saver.running = true;
    }
    property Process saver: Process {}
    property Process loader: Process {
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null | sort | uniq -c', "_", providers.historyPath]
        stdout: SplitParser { onRead: line => { const m = line.trim().match(/^(\d+) (.*)$/); if (m) providers.history[m[2]] = Number(m[1]); } }
    }
}
