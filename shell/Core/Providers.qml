// Runs providers for the query, debounced, and merges rows by weighted score. Fast static catalogues
// (apps, commands, keys, themes) are cached once per Core session and filtered synchronously in JS for
// zero-latency typing; dynamic topic providers are gated by query relevance so keystrokes never fan out
// into dozens of redundant processes. A generation counter drops late results. See docs/palette.md.
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

    // In-memory session caches for static catalogues (warmed when the Core opens).
    property var cache: ({ apps: [], commands: [], keys: [], themes: [] })
    property bool cacheReady: false
    readonly property var cachedThemes: (cache.themes ?? []).filter(r => String(r.id ?? "").startsWith("theme:"))

    function fold(s) { return String(s ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase(); }
    function matchesQuery(row, q) {
        if (!q) return true;
        const hay = fold((row.title ?? "") + " " + (row.subtitle ?? "") + " " + (row.keywords ?? "")).replace(/-/g, "");
        const words = fold(q).replace(/-/g, "").split(/\s+/).filter(w => w.length > 0);
        return words.every(w => hay.includes(w));
    }
    function hasAny(l, list) {
        const words = l.split(/\s+/);
        return list.some(k => l.includes(k) || words.some(w => w.length >= 2 && k.startsWith(w)));
    }

    // Dynamic providers gated by domain relevance so ordinary searches stay instant and jitter-free.
    readonly property var builtin: [
        { kind: "App",       weight: 1.0,  appIcons: true, cached: "apps",     cmd: q => ["takumi", "palette", "index", "apps", q] },
        { kind: "Command",   weight: 0.8,  icon: "cmd",    cached: "commands", cmd: q => ["takumi", "palette", "index", "commands", q],
          liveWhen: l => hasAny(l, ["settings", "setting", "preferences", "options", "control panel", "system settings", "system preferences"]) },
        { kind: "Theme",     weight: 0.7,  icon: "sun",    cached: "themes",   cmd: q => ["takumi", "palette", "index", "themes", q] },
        { kind: "Key",       weight: 0.75, icon: "cmd",    cached: "keys",     cmd: q => ["takumi", "palette", "index", "keys", q] },
        { kind: "Calc",      weight: 1.1,  icon: "eq",     cmd: q => ["takumi", "palette", "index", "calc", q],
          accept: (q, l) => /^[0-9\s().+*/%^-]+$/.test(q) && /\d/.test(q) },
        { kind: "Get",       weight: 0.7,  icon: "down",   cmd: q => ["takumi", "palette", "index", "shelf", q],
          accept: (q, l) => q.length >= 2 },
        { kind: "Wi-Fi",     weight: 0.9,  icon: "wifi",   cmd: q => ["takumi", "palette", "index", "wifi", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["wifi", "wi-fi", "wireless", "network", "internet", "share", "hotspot", "hotel", "cafe", "portal", "forget", "hidden", "ssid"]) },
        // Everyday settings, each its own provider: commands/palette/<name> <query> (docs/palette.md).
        { kind: "Bluetooth", weight: 0.9,  icon: "bt",     cmd: q => ["takumi", "palette", "bluetooth", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["bluetooth", "bt", "pair", "headphone", "airpod", "earbud", "speaker", "mouse", "keyboard", "connect", "device"]) },
        { kind: "Sound",     weight: 0.9,  icon: "vol",    cmd: q => ["takumi", "palette", "sound", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["sound", "audio", "volume", "mute", "speaker", "headphone", "mic", "microphone", "input", "output", "studio", "tuning", "media", "player"]) },
        { kind: "Display",   weight: 0.9,  icon: "display", cmd: q => ["takumi", "palette", "display", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["display", "screen", "monitor", "bright", "night", "warm", "scale", "bigger", "smaller", "text", "resolution", "refresh", "hz", "mirror", "projector", "rotate", "zoom"]) },
        { kind: "Power",     weight: 0.9,  icon: "bolt",   cmd: q => ["takumi", "palette", "power", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["power", "battery", "sleep", "suspend", "awake", "caffeine", "lid", "charge", "limit", "profile", "saver", "performance", "balanced", "idle", "shut", "restart", "reboot", "log"]) },
        { kind: "Earlier",   weight: 0.85, icon: "bell",   appIcons: true, cmd: q => ["takumi", "palette", "earlier", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["earlier", "notice", "notification", "message", "missed", "history", "alert", "crash"]) },
        { kind: "Clipboard", weight: 0.95, icon: "edit",   cmd: q => ["takumi", "palette", "clipboard", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["clipboard", "paste", "copied", "copy", "history", "clip"]) },
        { kind: "Emoji",     weight: 0.9,  icon: "cmd",    cmd: q => ["takumi", "palette", "emoji", q],
          accept: (q, l) => q.startsWith(":") || q.length >= 3 },
        { kind: "Doctor",    weight: 0.85, icon: "pulse",  cmd: q => ["takumi", "palette", "doctor", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["doctor", "check", "health", "wrong", "broken", "fix", "repair", "problem", "issue", "trouble", "slow", "update"]) },
        { kind: "Firmware",  weight: 0.8,  icon: "chip",   cmd: q => ["takumi", "palette", "firmware", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["firmware", "bios", "uefi", "fwupd", "update"]) },
        { kind: "Security",  weight: 0.85, icon: "lock",   cmd: q => ["takumi", "palette", "security", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["security", "privacy", "finger", "fingerprint", "biometric", "lock", "encrypt", "disk", "recovery", "secure", "boot", "password", "passphrase", "firewall"]) },
        { kind: "Keyboard",  weight: 0.85, icon: "keyboard", cmd: q => ["takumi", "palette", "keyboards", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["keyboard", "layout", "input", "touchpad", "mouse", "pointer", "scroll", "natural", "repeat", "tap", "harmony", "caps", "backlight", "dictat", "voice"]) },
        { kind: "Language",  weight: 0.85, icon: "globe",  cmd: q => ["takumi", "palette", "language", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["language", "locale", "region", "english", "japanese", "french", "german", "spanish", "chinese", "korean", "translate"]) },
        { kind: "Hardware",  weight: 0.85, icon: "chip",   cmd: q => ["takumi", "palette", "hardware", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["hardware", "about", "computer", "spec", "cpu", "gpu", "ram", "memory", "model", "quirk", "laptop", "thunderbolt", "dock"]) },
        { kind: "Time",      weight: 0.9,  icon: "clock",  cmd: q => ["takumi", "palette", "time", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["time", "clock", "zone", "timezone", "city", "weather", "timer", "remind", "reminder", "alarm", "12", "24", "hour"]) },
        { kind: "Defaults",  weight: 0.85, icon: "globe",  cmd: q => ["takumi", "palette", "defaults", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["default", "browser", "terminal", "editor", "files", "mail", "video", "music", "open with"]) },
        { kind: "Quit",      weight: 0.9,  icon: "cross",  appIcons: true, cmd: q => ["takumi", "palette", "quit", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["quit", "force", "kill", "stuck", "frozen", "restart", "close", "hang"]) },
        { kind: "Remote",    weight: 0.9,  icon: "person", cmd: q => ["takumi", "palette", "remote", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["remote", "help", "share screen", "vnc", "assist"]) },
        { kind: "Reset",     weight: 0.85, icon: "restart", cmd: q => ["takumi", "palette", "settings", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["reset", "restore", "factory", "erase", "wipe", "settings"]) },
        { kind: "Login",     weight: 0.85, icon: "play",   appIcons: true, cmd: q => ["takumi", "palette", "login", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["login", "startup", "autostart", "start at", "open at"]) },
        { kind: "Backup",    weight: 0.85, icon: "history", cmd: q => ["takumi", "palette", "backup", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["backup", "restore", "cloud", "drive", "dropbox", "onedrive", "rclone", "snapshot", "sync"]) },
        { kind: "Phone",     weight: 0.85, icon: "phone",  cmd: q => ["takumi", "palette", "phone", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["phone", "android", "iphone", "nearby", "send", "share", "localsend", "kde"]) },
        { kind: "VPN",       weight: 0.9,  icon: "shield", cmd: q => ["takumi", "palette", "vpn", q],
          accept: (q, l) => q.length >= 2 && hasAny(l, ["vpn", "wireguard", "tailscale", "mullvad", "firewall", "ufw", "ssh", "port", "block", "allow"]) },
        { kind: "Printer",   weight: 0.85, icon: "printer", cmd: q => ["takumi", "palette", "printer", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["print", "printer", "scan", "scanner", "cups", "paper"]) },
        { kind: "Drive",     weight: 0.85, icon: "usb",    cmd: q => ["takumi", "palette", "drives", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["drive", "usb", "eject", "disk", "mount", "unmount", "card", "sd", "format", "stick"]) },
        { kind: "Font",      weight: 0.8,  icon: "type",   cmd: q => ["takumi", "palette", "fonts", q],
          accept: (q, l) => q.length >= 3 && hasAny(l, ["font", "typeface", "mono", "inter", "jetbrains", "fira", "plex", "nerd", "iosevka", "roboto", "hack", "cascadia", "ubuntu"]) },
        { kind: "Yours",     weight: 0.9,  icon: "cmd",    cmd: q => ["sh", "-c", 'for p in "$HOME"/.config/takumi/palette/*; do [ -x "$p" ] && "$p" "$1"; done', "_", q],
          accept: (q, l) => q.length >= 2 }
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

    function warmCache() {
        for (const prov of builtin) {
            if (!prov.cached) continue;
            const key = prov.cached;
            start(prov, prov.cmd(""), -1, r => {
                const next = Object.assign({}, providers.cache);
                next[key] = r;
                providers.cache = next;
                providers.cacheReady = true;
                if (providers.query.trim() !== "") providers.refresh();
            });
        }
    }

    function refresh() {
        generation++;
        const q = query.trim(), gen = generation, l = fold(q);
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
        // Windows: answered from the niri service, no process, with spatial workspace & column badge.
        for (const w of niri.windows) {
            if (!fold((w.title ?? "") + " " + (w.app_id ?? "")).includes(l)) continue;
            const ws = niri.workspaces.find(x => x.id === w.workspace_id);
            const col = w.layout?.pos_in_scrolling_layout ? ("col " + w.layout.pos_in_scrolling_layout[0]) : (w.is_floating ? "floating" : "");
            const loc = [ws ? ("Workspace " + ws.idx) : "", col, w.app_id || ""].filter(s => s).join(" · ");
            first.push({ id: "win:" + w.id, title: w.title || w.app_id, subtitle: loc, appIcon: w.app_id, icon: "globe", kind: "Window", score: 1.0,
                       run: ["niri", "msg", "action", "focus-window", "--id", String(w.id)] });
        }
        // Intent & Agent Cockpit quick jump when searching cockpit / agent / transcript.
        if (hasAny(l, ["cockpit", "agent", "transcript", "mcp"])) {
            first.push({ id: "core:cockpit", title: "Intent Cockpit", subtitle: "Active engine, audited transcript and MCP", icon: "quote", kind: "Setting", score: 0.95,
                       view: "cockpit", run: ["true"] });
        }
        // Instant synchronous results from the cached static catalogues (apps, commands, keys, themes).
        for (const prov of builtin) {
            if (!prov.cached) continue;
            if (prov.liveWhen && prov.liveWhen(l)) continue;
            const cachedRows = cache[prov.cached] ?? [];
            if (cachedRows.length > 0) {
                for (const r of cachedRows) if (matchesQuery(r, q)) first.push(r);
            }
        }
        // A sentence: Intent's row, asked as a conversation in the Core (takumi intent ask, docs/intent.md).
        if (q.includes(" ")) first.push({ id: "intent:" + q, title: q, subtitle: "Ask Intent", icon: "quote", kind: "Intent", score: 0.3, converse: true, run: ["takumi", "intent", "ask", q] });
        acc = first; rows = rank(acc);

        // Dynamic providers: only launch those whose domain matches the query (or static ones not yet cached).
        for (const prov of builtin) {
            if (prov.cached) {
                const needLive = (prov.liveWhen && prov.liveWhen(l)) || (cache[prov.cached] ?? []).length === 0;
                if (!needLive) continue;
            } else if (prov.accept && !prov.accept(q, l)) {
                continue;
            }
            start(prov, prov.cmd(q), gen, r => { acc = acc.concat(r); rows = rank(acc); refreshLater(prov, r, gen); });
        }
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
            if (gen === -1 || gen === generation)
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

    // Boosts: the query starts the title or a word of it (0.5), is one of the search words (0.5) or starts
    // one (0.25 to 0.45, by how much of the word it is: "power" is half of "powerpoint"), or every word of a
    // longer query is in the title, hyphens ignored (0.4: "wifi off"), or the title holds it (0.3). A query
    // that names a row's kind ("power", "bluetooth", "wifi") lifts that kind's rows by 0.35 more, so the
    // word for a subject finds the subject before an app that mentions it.
    // Intent's row is the query itself, so it never takes a boost: it stays the fallback.
    function rank(list) {
        const l = fold(query.trim()), ln = l.replace(/-/g, ""), qw = ln.split(/\s+/).filter(w => w);
        const scored = list.map(r => {
            const t = fold(r.title ?? ""), tn = t.replace(/-/g, ""), words = fold(r.keywords ?? "").split(/\s+/);
            const part = words.reduce((best, w) => w && w.startsWith(l) ? Math.max(best, l.length / w.length) : best, 0);
            const kind = fold(r.kind ?? "").replace(/-/g, "");
            const match = !l || r.kind === "Intent" ? 0
                        : (t.startsWith(l) || t.split(/[\s·]+/).some(w => w.startsWith(l))) ? 0.5
                        : part === 1 ? 0.5
                        : part > 0 ? 0.25 + 0.2 * part
                        : qw.length > 1 && qw.every(w => tn.includes(w)) ? 0.4
                        : t.includes(l) ? 0.3 : 0;
            const boost = match + (ln.length >= 2 && r.kind !== "Intent" && (kind === ln || kind + "s" === ln) ? 0.35 : 0);
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
