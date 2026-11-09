// The open Core: the Palette. Results stack upward from the field, best match nearest your hands.
// It is only as tall as what it holds. Keyboard: Up/Down, Enter, Alt+1..9, Esc clears then closes.
// Two moments borrow it. A conversation: a row marked converse runs its command here, the Core draws
// what the command says (lib/core.sh: ask, secret, confirm, note, wrong, done) and types the answers
// back on its stdin, so a password or a yes never reaches the providers or a command line. A card
// (sharing a network) takes the rows' place. Apps can be browsed too: the empty Palette has a row of the
// apps you open most (Down from the nearest row reaches it), and "apps" shows every app as a grid (AppGrid).
// A row with a `search` (Settings and its topics) types those words into the field instead of running.
// See docs/shell.md and docs/palette.md.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

Item {
    id: pane
    required property var niri
    required property var core
    required property string output
    property bool active: false

    // The conversation: { row, step: null | { kind: "ask" | "secret" | "confirm", prompt, deadline }, note,
    // tone, done, lastLine, ended }. While step is set the command waits for an answer; a deadline (ms
    // since the epoch) is when a timed confirm stops taking one.
    property var talk: null
    property var queued: null              // a row chosen while the last command is still ending
    readonly property bool working: !!talk && !talk.step && !talk.ended
    property bool reveal: false            // show the secret as it is typed
    // A card in place of the rows: { kicker, title, detail, secretLabel, secret, qr }.
    property var card: null
    property bool cardReveal: false
    // The row you moved to keeps its place when the same query's rows update (a fresh Wi-Fi scan).
    property string pinnedId: ""
    // The first rows after the Core opens come in one after another; later updates just appear.
    property bool opening: false
    Timer { id: openingDone; interval: 450; onTriggered: pane.opening = false }

    // Every app, for the row on the empty Palette and the grid "apps" shows: the App provider's own rows
    // (commands/palette/index apps), read again each time the Core opens, so a new app is there at once.
    property var apps: []
    Process {
        id: appsReader
        command: ["takumi", "palette", "index", "apps", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) { if (!line) continue; try { out.push(JSON.parse(line)); } catch (e) {} }
                out.sort((a, b) => String(a.title).localeCompare(String(b.title)));
                pane.apps = out;
            }
        }
    }
    // The everyday apps lead until your own use says otherwise.
    readonly property var everyday: ["firefox", "org.gnome.Nautilus", "foot", "org.gnome.TextEditor", "libreoffice-writer", "io.github.celluloid_player.Celluloid"]
    readonly property var stripApps: {
        const h = providers.history, pick = id => { const i = everyday.indexOf(String(id).replace(/^app:/, "")); return i < 0 ? 99 : i; };
        const most = apps.slice().sort((a, b) => ((h[b.id] ?? 0) - (h[a.id] ?? 0)) || (pick(a.id) - pick(b.id)));
        return most.slice(0, Style.appColumns - 1).concat([{ id: "apps:all", title: "All apps", glyph: "apps" }]);
    }
    readonly property bool browsing: !talk && !card && ["apps", "all apps", "applications", "my apps"].includes(field.text.trim().toLowerCase())
    readonly property bool showStrip: !talk && !card && field.text === "" && apps.length > 0
    property int stripIndex: -1            // a tile in the row of apps is current, not a row
    // What the Palette starts runs in its own scope in app.slice, not inside the shell's service: systemd-oomd
    // can then stop that one app when memory runs out, and never the shell (docs/tuning.md).
    function launch(argv) {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice", "--"].concat(argv));
    }
    function openApp(app) {
        if (!app) return;
        if (app.id === "apps:all") { field.text = "apps"; return; }
        providers.remember(app.id);
        launch(app.run);
        pane.core.close();
    }

    readonly property var shownRows: talk ? [Object.assign({}, talk.row, { subtitle: talkLine(), tone: talk.tone, risk: 0 })] : grouped(providers.rows)
    // Rows in groups, each under its name: for a search, the best match, then every kind together, the kind
    // with the better row first; for the empty Palette, the groups the providers gave. Results stack upward,
    // so a group's name comes after its rows in this list and shows above them. Names are not selectable.
    readonly property var sectionNames: ({
        App: "Apps", Command: "Commands", Setting: "Settings", Theme: "Themes", Calc: "Answer", Key: "Keys",
        Get: "Get apps", "Wi-Fi": "Wi-Fi networks", Bluetooth: "Bluetooth", Sound: "Sound", Display: "Displays",
        Power: "Power", Earlier: "Earlier today", Clipboard: "Clipboard", Emoji: "Emoji", Doctor: "Health",
        Firmware: "Firmware", Security: "Security", Keyboard: "Keyboards", Language: "Language", Yours: "Yours",
        Hardware: "This computer", Time: "Time", Reminder: "Reminders", Timer: "Timers", Weather: "Weather",
        Update: "Updates", Defaults: "Default apps", Reader: "Accessibility", Backup: "Backups", Phone: "Your phone",
        Nearby: "Nearby", VPN: "VPN", Firewall: "Firewall", Printer: "Printers", Scanner: "Scanners", Drive: "Drives",
        Font: "Fonts", Window: "Open windows", Intent: "Ask", Start: "Start here", Find: "Find your way", Topic: "Settings"
    })
    function grouped(rows) {
        if (rows.length < 2) return rows;
        const name = r => sectionNames[r.kind] ?? (r.kind || "More");
        const head = t => ({ header: true, id: "section:" + t, title: t });
        const out = [];
        let rest = rows;
        if (field.text.trim() !== "") {
            out.push(Object.assign({}, rows[0], { kindShown: true }), head("Best match"));
            rest = rows.slice(1);
        }
        const order = [], byName = {};
        for (const r of rest) { const n = name(r); if (!(n in byName)) { byName[n] = []; order.push(n); } byName[n].push(r); }
        for (const n of order) { for (const r of byName[n]) out.push(Object.assign({}, r, { kindShown: false })); out.push(head(n)); }
        return out;
    }
    readonly property int sectionCount: shownRows.filter(r => r.header).length
    property int secondsLeft: 0
    function talkLine() {
        const t = talk;
        if (t.note) return t.note;
        if (t.ended) return "That did not work";
        if (!t.step) return "Working…";
        if (t.step.kind !== "confirm") return "Type it, then press Enter";
        return t.step.deadline ? t.step.prompt + " · Goes back in " + secondsLeft + " s" : t.step.prompt;
    }
    Timer {
        id: countdown
        interval: 250; repeat: true
        running: !!pane.talk && !!pane.talk.step && !!pane.talk.step.deadline
        onTriggered: {
            const left = Math.ceil((pane.talk.step.deadline - Date.now()) / 1000);
            pane.secondsLeft = Math.max(0, left);
            if (left <= 0) pane.talk = Object.assign({}, pane.talk, { step: null });   // the command moves on by itself
        }
    }

    // As tall as what it holds: exactly the rows, the plan and the field, or the card and the field. Only
    // the empty state, which shows a hint, keeps the minimum height.
    property int talkRowHeight: Style.rowHeight   // the conversation's row grows with its words
    readonly property bool searching: field.text.trim() !== ""
    function rowHeightOf(r) {
        if (r.header) return Style.sectionHeight;
        const detailed = searching || r.id === armed || r.tone === "busy" || r.tone === "error";
        return detailed ? Style.rowHeight : Style.rowHeightCompact;
    }
    readonly property int wantedHeight: {
        if (card) return Math.min(Style.coreOpenMax, Style.space(16) + cardView.implicitHeight + Style.field + Style.gap);
        if (browsing) return Math.min(Style.coreOpenMax, Style.space(16) + browseHead.height + Math.max(1, Math.ceil(apps.length / Style.appColumns)) * Style.appCell + Style.field + Style.gap);
        const n = list.count, plan = planRow.visible, stripHeight = showStrip ? Style.appCell + Style.space(6) : 0;
        if (n === 0) return Math.max(Style.coreOpenMin, Style.space(16) + stripHeight + (emptyHint.visible ? emptyHint.implicitHeight + Style.space(36) : 0) + Style.field + Style.gap);
        const rowsHeight = talk ? talkRowHeight + Style.rowGap
                         : shownRows.reduce((sum, r) => sum + pane.rowHeightOf(r) + Style.rowGap, 0);
        const h = Style.space(16) + rowsHeight + stripHeight + (plan ? Style.planRow : 0) + Style.field + Style.gap;
        return Math.min(Style.coreOpenMax, h);
    }

    Providers { id: providers; niri: pane.niri; query: field.text }

    // A row above risk tier 0 asks first, in place: the first Enter arms it, the second runs it.
    property string armed: ""
    // Holding Alt shows each row's Alt+number; the rest of the time the rows carry no key hints.
    property bool altHeld: false

    // A theme row that stays selected for a moment shows its theme on the shell and the Sky
    // (Theme.preview); moving to another row or closing puts yours back, unless you chose it.
    property bool keepPreview: false
    Timer {
        id: previewDwell; interval: 350
        onTriggered: { const r = pane.shownRows[list.currentIndex]; if (pane.active && r && String(r.id).startsWith("theme:")) Theme.preview(String(r.id).slice(6)); }
    }
    Timer { id: previewSafety; interval: 5000; onTriggered: Theme.endPreview() }
    function previewCheck() {
        const r = shownRows[list.currentIndex];
        if (active && !talk && r && String(r.id).startsWith("theme:")) previewDwell.restart();
        else { previewDwell.stop(); Theme.endPreview(); }
    }

    onActiveChanged: {
        if (active) {
            opening = true; openingDone.restart();
            field.text = pane.core.query; pane.core.query = "";
            providers.refresh();
            armed = ""; card = null; pinnedId = ""; altHeld = false; stripIndex = -1;
            appsReader.running = true;
            if (!talker.running) { talk = null; answer.text = ""; }
            list.currentIndex = 0;
            Qt.callLater(() => (pane.talk ? answer : field).forceActiveFocus());
        } else {
            card = null;
            if (!talker.running) { talk = null; answer.text = ""; }
            previewDwell.stop();
            if (keepPreview) { keepPreview = false; previewSafety.restart(); } else Theme.endPreview();
        }
    }
    Connections { target: list; function onCurrentIndexChanged() { pane.armed = ""; pane.previewCheck(); } }
    Connections {
        target: providers
        function onRowsChanged() {
            Qt.callLater(pane.previewCheck);
            if (!pane.pinnedId) return;
            const i = pane.shownRows.findIndex(r => r.id === pane.pinnedId);
            if (i >= 0) Qt.callLater(() => { list.currentIndex = i; });
        }
    }
    function move(i) {
        // A group's name is passed over, in the direction of travel.
        const step = i < list.currentIndex ? -1 : 1;
        i = Math.max(0, Math.min(list.count - 1, i));
        while (shownRows[i] && shownRows[i].header) i += step;
        if (i < 0 || i >= list.count) return;
        list.currentIndex = i;
        pinnedId = shownRows[list.currentIndex]?.id ?? "";
    }

    function nth(n) {   // the index of the nth row that is not a group's name
        for (let i = 0, seen = 0; i < shownRows.length; i++) if (!shownRows[i].header && seen++ === n) return i;
        return -1;
    }
    function run(i, keepOpen) {
        if (talk) { talkEnter(); return; }
        const row = shownRows[i];
        if (row && row.header) return;
        if (!row) { if (field.text.trim()) runIntent(field.text.trim()); return; }
        if (row.search) { providers.remember(row.id); field.text = row.search; field.cursorPosition = field.text.length; list.currentIndex = 0; return; }
        if (row.converse) { beginTalk(row); return; }
        if (row.card) { openCard(row); return; }
        if (row.interactive || row.terminal) {
            providers.remember(row.id); inTerminal(row.run); pane.core.close(); return;
        }
        if ((row.risk ?? 0) > 0 && armed !== row.id) { armed = row.id; return; }
        armed = "";
        providers.remember(row.id);
        if (String(row.id).startsWith("theme:")) keepPreview = true;   // the new theme takes over from the preview
        launch(row.run);
        if (!keepOpen) pane.core.close();
    }
    // A sentence nothing matched goes to Intent, as a conversation here (takumi intent ask, docs/intent.md).
    function runIntent(q) { beginTalk({ id: "intent:" + q, title: q, subtitle: "Ask Intent", icon: "quote", kind: "Intent", converse: true, run: ["takumi", "intent", "ask", q] }); }
    // Anything that may ask a question runs where the user can see it answer.
    function inTerminal(argv) {
        const quoted = argv.map(a => "'" + String(a).replace(/'/g, "'\\''") + "'").join(" ");
        launch(["foot", "-e", "sh", "-c", quoted + "; echo; read -p 'Enter to close' _"]);
    }

    // A conversation. The command runs with TAKUMI_CORE=1 and its stdin open; its stdout is read a line
    // at a time. One at a time: a row chosen while the last command is still ending starts after it.
    function beginTalk(row) {
        if (talker.running) { queued = row; return; }
        talk = { row: row, step: null, note: "", tone: "busy", done: "", lastLine: "", ended: false };
        reveal = false; answer.text = "";
        talker.command = row.run;
        talker.running = true;
        Qt.callLater(() => answer.forceActiveFocus());
    }
    function heard(line) {
        const t = talk;
        if (!t) return;
        const sp = line.indexOf(" "), word = sp < 0 ? line : line.slice(0, sp);
        let rest = sp < 0 ? "" : line.slice(sp + 1);
        switch (word) {
        case "ask": case "secret": case "confirm": {
            let deadline = 0;
            const timed = word === "confirm" ? rest.match(/^(\d+) (.*)$/) : null;   // "confirm 10 Keep this?"
            if (timed) { deadline = Date.now() + Number(timed[1]) * 1000; rest = timed[2]; secondsLeft = Number(timed[1]); }
            t.step = { kind: word, prompt: rest, deadline: deadline, shown: Date.now() };
            if (t.tone !== "error") { t.note = ""; t.tone = ""; }
            if (!active) pane.core.openOn = pane.output;   // a question deserves the screen back
            Qt.callLater(() => answer.forceActiveFocus());
            break;
        }
        case "note": t.step = null; t.note = rest; t.tone = "busy"; break;
        case "wrong": t.step = null; t.note = rest; t.tone = "error"; shake.restart(); break;
        case "done": t.step = null; t.done = rest; break;
        case "card": t.step = null; try { t.card = JSON.parse(rest); } catch (e) { t.note = "That did not work"; } break;
        default: t.step = null; t.note = line;
        }
        t.lastLine = line;
        talk = Object.assign({}, t);
    }
    // The answer leaves the field the moment it is sent, so a secret is never on screen while the
    // command works, and a wrong one is typed again from an empty field.
    function reply(text) {
        if (!talk || !talk.step) return;
        talker.write(text + "\n");
        answer.text = "";
        // A "no" is a choice, not a failure: if the command then stops, it ends calmly, not in red.
        talk = Object.assign({}, talk, { step: null, note: "", tone: "busy", declined: talk.step.kind === "confirm" && text === "no" });
    }
    function talkEnter() {
        const t = talk;
        if (t.ended) { beginTalk(t.row); return; }
        if (!t.step) return;
        // A question that just appeared ignores Enter for a moment: the Enter that started the command,
        // pressed twice, must not also answer it.
        if (Date.now() - (t.step.shown ?? 0) < Style.answerGuard) return;
        reply(t.step.kind === "confirm" ? "yes" : answer.text);
    }
    // Esc: a typed answer is cleared first; at an empty question or while the command works, it is stopped.
    // Closing the Core another way (a click outside, Super+Space) lets the command finish; a notice then
    // says how it ended, and a question brings the Core back.
    function talkEscape() {
        const t = talk;
        if (t.ended) { leaveTalk(); return; }
        if (t.step && t.step.kind === "confirm") { reply("no"); return; }
        if (t.step && answer.text) { answer.text = ""; return; }
        stopTalk();
    }
    function stopTalk() { if (talker.running) { talker.signal(15); killer.start(); } leaveTalk(); }
    Timer { id: killer; interval: 2000; onTriggered: if (talker.running) talker.signal(9) }
    function leaveTalk() { talk = null; answer.text = ""; reveal = false; field.forceActiveFocus(); }
    function talkEnded(code) {
        killer.stop();
        const next = queued; queued = null;
        if (next) Qt.callLater(() => beginTalk(next));
        const t = talk;
        if (!t) return;
        const ok = t.done !== "" || code === 0;
        // A conversation that ends on a card (a code to keep) leaves it open in place of the rows.
        if (ok && t.card) {
            providers.remember(t.row.id);
            talk = null; answer.text = ""; cardReveal = false;
            if (!active) pane.core.openOn = pane.output;
            card = t.card;
            Qt.callLater(() => field.forceActiveFocus());
            return;
        }
        if (ok) {
            providers.remember(t.row.id);
            // The last sentence stays long enough to read: two seconds, and more for a longer one.
            if (t.done) pane.core.announce(t.row.icon ?? "cmd", t.done, "", Math.min(8, Math.max(2, Math.round(t.done.length / 18))));
            talk = null; answer.text = "";
            if (active) pane.core.close();
            return;
        }
        const spoke = /^(ask|secret|confirm|note|wrong|done) /.test(t.lastLine);
        const said = t.lastLine && !spoke ? t.lastLine : (t.note || "That did not work");
        if (!active) { pane.core.notice(t.row.icon ?? "cmd", t.row.title, said, -1); talk = null; return; }
        talk = Object.assign({}, t, { step: null, note: said, tone: t.declined ? "" : "error", ended: true });
    }
    Process {
        id: talker
        environment: ({ TAKUMI_CORE: "1" })
        stdinEnabled: true
        stdout: SplitParser { onRead: line => pane.heard(line) }
        // What a command says on stderr (a missing library, a usage error) is what a failure shows.
        stderr: SplitParser { onRead: line => { if (pane.talk && line.trim()) pane.talk = Object.assign({}, pane.talk, { lastLine: line.trim() }); } }
        onExited: (exitCode, exitStatus) => pane.talkEnded(exitCode)
    }

    // A card's report goes to the clipboard through wl-copy's standard input, never its arguments.
    function copyCard() {
        copier.environment = { TAKUMI_COPY: String(pane.card.copy) };
        copier.running = true;
        cardView.copied = true;
    }
    Process { id: copier; command: ["sh", "-c", 'printf "%s" "$TAKUMI_COPY" | wl-copy >/dev/null 2>&1'] }
    function openCard(row) {
        card = { kicker: "", title: row.title, detail: "One moment…", secretLabel: "", secret: "", qr: [] };
        cardReveal = false;
        cardProc.running = false;          // a card still being read gives way to this one
        cardProc.command = row.run;
        cardProc.running = true;
    }
    Process {
        id: cardProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!pane.card) return;
                try { pane.card = JSON.parse(this.text); }
                catch (e) { pane.card = Object.assign({}, pane.card, { detail: "That did not work" }); }
            }
        }
    }

    ListView {
        id: list
        visible: !pane.card && !pane.browsing
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: pane.showStrip ? strip.top : planRow.top }
        anchors.margins: Style.space(10)
        anchors.bottomMargin: Style.space(6)
        verticalLayoutDirection: ListView.BottomToTop
        spacing: Style.rowGap
        clip: true
        model: pane.shownRows
        currentIndex: 0
        // One selection that glides from row to row: the accent's tint and a rail.
        highlight: Rectangle {
            radius: Style.rowRadius
            visible: pane.stripIndex < 0
            color: Theme.tint(Style.fillCurrent)
            Rectangle { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 2; height: Math.max(Style.space(14), parent.height - Style.space(24)); radius: 1; color: Theme.accent }
        }
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Style.glide
        highlightMoveVelocity: -1
        highlightResizeDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        delegate: ResultRow {
            width: list.width
            wrap: !!pane.talk
            onHeightChanged: if (pane.talk) pane.talkRowHeight = height
            Component.onCompleted: if (pane.talk) pane.talkRowHeight = height
            entering: pane.opening
            compact: !pane.searching
            current: index === list.currentIndex && pane.stripIndex < 0
            ordinal: pane.shownRows.slice(0, index).filter(r => !r.header).length
            armed: modelData.id === pane.armed
            showKey: pane.altHeld
            query: pane.talk ? "" : field.text
            onActivated: pane.talk ? pane.talkEnter() : pane.run(index, false)
        }
    }

    // The apps you open most, between the rows and the field; the last tile opens the grid of every app.
    AppGrid {
        id: strip
        visible: pane.showStrip
        anchors { left: parent.left; right: parent.right; bottom: planRow.top; leftMargin: Style.space(10); rightMargin: Style.space(10); bottomMargin: Style.space(6) }
        height: visible ? Style.appCell : 0
        interactive: false
        apps: pane.stripApps
        entering: pane.opening
        selecting: pane.stripIndex >= 0
        currentIndex: pane.stripIndex
        onOpened: app => pane.openApp(app)
    }

    // "apps": every app, A to Z, in a grid that scrolls. Typing on finds one by name instead.
    Item {
        id: browseHead
        visible: pane.browsing
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Style.space(22); rightMargin: Style.space(22) }
        height: Style.space(34)
        Label {
            anchors { left: parent.left; bottom: parent.bottom; bottomMargin: Style.space(4) }
            micro: true; text: "All apps · " + pane.apps.length; color: Theme.accent
        }
        Label {
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: Style.space(4) }
            font.pixelSize: Style.caption; dim: Style.textFaint; text: "Type an app's name to get a new one"
        }
    }
    AppGrid {
        id: browse
        visible: pane.browsing
        anchors { left: parent.left; right: parent.right; top: browseHead.bottom; bottom: fieldBox.top; leftMargin: Style.space(10); rightMargin: Style.space(10); bottomMargin: Style.space(6) }
        apps: pane.browsing ? pane.apps : []
        entering: true
        onOpened: app => pane.openApp(app)
        onAppsChanged: currentIndex = apps.length ? 0 : -1
    }

    Card {
        id: cardView
        visible: !!pane.card
        info: pane.card
        reveal: pane.cardReveal
        anchors { left: parent.left; right: parent.right; bottom: fieldBox.top; margins: Style.space(10) }
        height: implicitHeight
    }

    // No rows: what to do now. With nothing typed the row of apps is the answer, so this shows only when
    // that row is not there, or a search found nothing; the Palette grows to hold it (wantedHeight).
    Column {
        id: emptyHint
        anchors.centerIn: list
        visible: list.count === 0 && !pane.card && !pane.browsing && (pane.searching || !pane.showStrip)
        spacing: Style.space(6)
        Label { anchors.horizontalCenter: parent.horizontalCenter; dim: 0.72; width: Math.min(implicitWidth, pane.width - Style.space(48))
            text: pane.searching ? "No matches for “" + field.text.trim() + "”" : "Type an app, a setting or a question" }
        Label { anchors.horizontalCenter: parent.horizontalCenter; dim: Style.textFaint; font.pixelSize: Style.caption
            text: pane.searching ? "Press Enter to ask Intent instead" : "Try “wifi”, “theme” or “keys”" }
    }

    // Intent's plan, shown before you press Enter: the exact commands it would run.
    Row {
        id: planRow
        anchors.bottom: fieldBox.top
        anchors.left: parent.left
        anchors.leftMargin: Style.space(18)
        height: visible ? Style.planRow : 0
        visible: providers.plan.length > 0 && !pane.talk && !pane.card
        spacing: Style.space(6)
        Label { micro: true; text: "Will run"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Repeater {
            model: providers.plan
            delegate: Rectangle {
                required property var modelData
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                width: chip.implicitWidth + Style.space(16); height: Style.space(22)
                radius: Style.space(6); color: "transparent"
                border.width: 1; border.color: Theme.accentTint(0.45)
                Label { id: chip; anchors.centerIn: parent; text: modelData; font.family: Style.monoFamily; font.weight: Font.Normal; font.pixelSize: Style.space(11) }
            }
        }
    }

    Rectangle {
        id: fieldBox
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Style.space(10) }
        height: Style.field
        radius: Style.fieldRadius
        color: Theme.tint(Style.fillField)
        border.width: pane.talk && pane.talk.tone === "error" ? 1 : 0
        border.color: Theme.red
        transform: Translate { id: shakeX }
        Bevel { radius: parent.radius; visible: parent.border.width === 0; down: true }

        Emblem { id: mark; visible: !pane.talk; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; size: Style.space(18) }
        Icon {
            visible: !!pane.talk
            x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; size: Style.space(18)
            name: pane.talk && pane.talk.step && pane.talk.step.kind === "secret" ? "lock" : (pane.talk ? pane.talk.row.icon ?? "cmd" : "cmd")
            color: Theme.accent
        }

        TextInput {
            id: field
            visible: !pane.talk
            anchors { left: mark.right; leftMargin: Style.space(12); right: esc.left; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
            color: Theme.foreground
            font.family: Style.uiFamily; font.pixelSize: Style.title; font.weight: Font.Medium; font.letterSpacing: -0.2
            selectionColor: Theme.accentTint(0.35)
            selectedTextColor: Theme.foreground
            cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: field.cursorVisible }
            clip: true
            onTextChanged: { pane.armed = ""; pane.pinnedId = ""; pane.card = null; pane.stripIndex = -1; }
            Label { anchors.fill: parent; text: "Search, or ask anything"; dim: Style.textFaint; visible: !field.text; font.pixelSize: Style.title }
            Keys.onReleased: event => { if (event.key === Qt.Key_Alt) pane.altHeld = false; }
            onActiveFocusChanged: if (!activeFocus) pane.altHeld = false
            Keys.onPressed: event => {
                const alt = event.modifiers & Qt.AltModifier, ctrl = event.modifiers & Qt.ControlModifier;
                if (event.key === Qt.Key_Alt) { pane.altHeld = true; return; }
                switch (event.key) {
                case Qt.Key_Escape: if (pane.card) pane.card = null; else if (field.text) field.text = ""; else pane.core.close(); break;
                case Qt.Key_Up:                                                                  // results stack upward
                    if (pane.browsing) browse.moveCurrentIndexUp();
                    else if (pane.stripIndex >= 0) pane.stripIndex = -1;
                    else if (!pane.card) pane.move(list.currentIndex + 1);
                    break;
                case Qt.Key_Down:
                    if (pane.browsing) browse.moveCurrentIndexDown();
                    else if (pane.showStrip && pane.stripIndex < 0 && list.currentIndex <= 0) pane.stripIndex = 0;   // from the nearest row to the apps
                    else if (!pane.card && pane.stripIndex < 0) pane.move(list.currentIndex - 1);
                    break;
                case Qt.Key_Left:
                    if (pane.browsing) browse.moveCurrentIndexLeft();
                    else if (pane.stripIndex >= 0) pane.stripIndex = Math.max(0, pane.stripIndex - 1);
                    else return;
                    break;
                case Qt.Key_Right:
                    if (pane.browsing) browse.moveCurrentIndexRight();
                    else if (pane.stripIndex >= 0) pane.stripIndex = Math.min(strip.count - 1, pane.stripIndex + 1);
                    else return;
                    break;
                case Qt.Key_PageUp: if (!pane.card) pane.move(list.currentIndex + 6); break;
                case Qt.Key_PageDown: if (!pane.card) pane.move(list.currentIndex - 6); break;
                case Qt.Key_Return: case Qt.Key_Enter:
                    if (pane.card && pane.card.copy && !pane.card.secret) pane.copyCard();
                    else if (pane.card) pane.cardReveal = !pane.cardReveal;
                    else if (pane.browsing) pane.openApp(pane.apps[browse.currentIndex]);
                    else if (pane.stripIndex >= 0) pane.openApp(pane.stripApps[pane.stripIndex]);
                    else pane.run(list.currentIndex, ctrl);
                    break;
                case Qt.Key_U: if (!ctrl) return; field.text = ""; break;
                default:
                    if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !pane.card) { pane.run(pane.nth(event.key - Qt.Key_1), false); break; }
                    return;
                }
                event.accepted = true;
            }
        }

        // The conversation's field: an answer, a secret shown as dots unless you choose Show, or, for a
        // yes-or-no question, just the keys to press.
        TextInput {
            id: answer
            visible: !!pane.talk
            readonly property bool typing: !!pane.talk && !!pane.talk.step && pane.talk.step.kind !== "confirm"
            anchors { left: mark.right; leftMargin: Style.space(12); right: esc.left; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
            echoMode: pane.talk && pane.talk.step && pane.talk.step.kind === "secret" && !pane.reveal ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            readOnly: !typing
            color: Theme.foreground
            font.family: pane.reveal ? Style.monoFamily : Style.uiFamily
            font.pixelSize: Style.title; font.weight: Font.Medium
            selectionColor: Theme.accentTint(0.35)
            selectedTextColor: Theme.foreground
            cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: answer.cursorVisible && answer.typing }
            clip: true
            onTextChanged: if (pane.talk && pane.talk.tone === "error" && pane.talk.step) pane.talk = Object.assign({}, pane.talk, { tone: "", note: "" })
            Label {
                anchors.fill: parent; dim: Style.textFaint; visible: !answer.text; font.pixelSize: Style.title
                text: {
                    const t = pane.talk;
                    if (!t) return "";
                    if (t.ended) return t.declined ? "Press Enter to start again" : "Press Enter to try again";
                    if (!t.step) return t.note || "Working…";
                    return t.step.kind === "confirm" ? "Enter for yes · Esc for no" : t.step.prompt;
                }
            }
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape: pane.talkEscape(); break;
                case Qt.Key_Return: case Qt.Key_Enter: pane.talkEnter(); break;
                default: return;
                }
                event.accepted = true;
            }
        }

        Rectangle {
            id: esc
            readonly property bool showHide: !!pane.talk && !!pane.talk.step && pane.talk.step.kind === "secret"
            anchors { right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
            width: escLabel.implicitWidth + Style.space(12); height: Style.space(20)
            radius: Style.space(5); color: "transparent"
            border.width: 1; border.color: esc.showHide ? Theme.accentTint(0.45) : Theme.tint(0.16)
            Label { id: escLabel; anchors.centerIn: parent; micro: true; font.pixelSize: Style.space(10)
                text: esc.showHide ? (pane.reveal ? "Hide" : "Show") : "Esc"; color: esc.showHide ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textMicro) }
            MouseArea {
                anchors.fill: parent; anchors.margins: -Style.space(6)
                enabled: esc.showHide; cursorShape: Qt.PointingHandCursor
                onClicked: { pane.reveal = !pane.reveal; answer.forceActiveFocus(); }
            }
        }

        // Working: a short line sweeps along the bottom of the field.
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: parent.radius; rightMargin: parent.radius }
            height: 2; clip: true
            visible: pane.working
            Rectangle {
                id: sweepBar
                width: parent.width * 0.28; height: 2; radius: 1; color: Theme.accent
                x: Style.continuousMotion ? -width : 0
                NumberAnimation on x {
                    running: pane.working && Style.continuousMotion; loops: Animation.Infinite
                    from: -sweepBar.width; to: sweepBar.parent.width; duration: Style.sweep; easing.type: Easing.InOutQuad
                }
            }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 50 }
        NumberAnimation { target: shakeX; property: "x"; to: 8; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: -5; duration: 60 }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
    }
}
