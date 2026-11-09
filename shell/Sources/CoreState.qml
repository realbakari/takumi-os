// The Core's shared state: which screen it is open on, which open shape it takes (the Palette, Quick
// settings or Today), and the notices it shows. One instance in shell.qml; every screen's Core binds to it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../Look"

QtObject {
    id: state
    required property var niri
    property string openOn: ""             // output name, or "" when closed
    property string query: ""              // what the field starts with when it opens (a topic: "wifi", "power")
    property string view: ""               // "" the Palette, "quick" Quick settings, "today" the date

    function target() { return niri.focusedOutput || (Quickshell.screens.length ? Quickshell.screens[0].name : ""); }
    function toggle() { if (openOn) openOn = ""; else { view = ""; openOn = target(); } }
    function show() { view = ""; openOn = target(); }
    function close() { openOn = ""; }
    function search(text) { query = text || ""; view = ""; openOn = target(); }
    // Quick settings and Today: pressing the same door again closes the Core, like the key that opened it.
    function open_(shape) { if (openOn && view === shape) { openOn = ""; return; } view = shape; openOn = target(); }
    function quick() { open_("quick"); }
    function today() { open_("today"); }

    // Notices (docs/notifications.md). Two kinds share the capsule. Takumi's own is a flash (volume, a theme,
    // a command that ran, a screenshot): the newest replaces the last and it leaves after a moment. Messages
    // from apps (Sources/Notices.qml hands them over) wait in a queue, newest first. One shows at a time with
    // "3 more" for the rest; several from one app are one entry with their number on its icon; each shows for
    // five seconds, eight when it has buttons, and an urgent one stays until it is put away. A flash shows over
    // the queue, which comes back after it. Nothing counts down while the Core is open or the pointer rests on
    // the notice. While do not disturb is on (quiet), messages are only counted, urgent ones aside, and turning
    // it off says how many came in.
    property var flash: null               // { icon, title, detail, value, image, thumb, open, code, actions: [{ id, text, run }], act }
    property var queue: []                 // [{ key, image, urgent, left, items: [{ n, summary, body, code, actions: [{ id, text }], at }] }]
    property bool quiet: false             // do not disturb (Notices.qml keeps it)
    property int noticesHeld: 0            // messages that came in while it was quiet
    property var heldFrom: []              // the apps they came from, newest first
    property bool noticeHovered: false     // the pointer rests on the notice
    property int noticeSerial: 0           // counts each different notice that shows: a screen reader speaks it
    property double ticked: 0

    readonly property var head: queue.length ? queue[0] : null
    readonly property var headItem: head ? head.items[0] : null
    readonly property bool noticeActive: flash !== null || head !== null
    readonly property string noticeIcon: flash ? flash.icon : "bell"
    readonly property string noticeTitle: flash ? flash.title : headItem ? (live(headItem, "summary") || head.key) : ""
    readonly property string noticeDetail: flash ? flash.detail : headItem ? firstLine(live(headItem, "body")) : ""
    readonly property int noticeValue: flash ? flash.value : -1                    // 0..100 draws a meter; -1 draws none
    readonly property string noticeImage: flash ? flash.image : head ? head.image : ""   // an app's icon, or a picture
    readonly property bool noticeThumb: flash ? flash.thumb : false                // noticeImage is a screenshot, not an icon
    readonly property string noticeOpen: flash ? flash.open : ""                   // a file or link a press opens
    readonly property string noticeCode: flash ? flash.code : headItem ? headItem.code : ""   // a one-time code to copy
    readonly property var noticeSource: flash ? null : headItem ? headItem.n : null           // the app's notification
    readonly property var noticeActions: (flash ? flash.actions : headItem ? headItem.actions : []).filter(a => a.id !== "default" && a.text !== "").slice(0, 3)
    readonly property int noticeGroup: !flash && head ? head.items.length : 1      // messages in the entry on show
    readonly property int noticeMore: !flash && head ? queue.length - 1 : 0        // other entries waiting behind it

    // Takumi's own notices: the calls every command, key and surface already makes.
    function notice(icon, title, detail, value) { showFlash({ icon: icon, title: title, detail: detail, value: value }, Style.noticeHold); }
    // Something worth reading (what happened to an update) stays longer.
    function announce(icon, title, detail, seconds) { showFlash({ icon: icon, title: title, detail: detail }, Math.max(2, seconds) * 1000); }
    // A notice that offers to open what it is about: a recording, a link read from a code.
    function offer(icon, title, detail, open, seconds) { showFlash({ icon: icon, title: title, detail: detail, open: open }, Math.max(2, seconds) * 1000); }
    // niri saved a screenshot: show it, a press away from opening. Buttons for it go in actions as
    // { id, text, run }: pressing one runs its command.
    function shot(path) {
        if (!path) { showFlash({ icon: "shot", title: "Screenshot copied", detail: "Paste it anywhere" }, 3000); return; }
        showFlash({ icon: "shot", title: "Screenshot copied", detail: "Saved in Pictures · press to open", open: path, thumb: true,
                    image: "file://" + path.split("/").map(encodeURIComponent).join("/"),
                    actions: [{ id: "markup", text: "Mark up", run: ["takumi", "screen", "markup", path] }] }, 6000);
    }
    function showFlash(f, ms) {
        const icon = f.icon || "cmd", title = f.title || "", detail = f.detail || "";
        const same = flash !== null && flash.icon === icon && flash.title === title && flash.detail === detail;
        flash = { icon: icon, title: title, detail: detail, value: f.value ?? -1, image: f.image || "", thumb: !!f.thumb,
                  open: f.open || "", code: f.code || "", actions: f.actions || [], act: f.act || null };
        if (!same) noticeSerial += 1;
        flashTimer.interval = ms;
        if (noticeHovered) flashTimer.stop(); else flashTimer.restart();
    }
    function endFlash() { flashTimer.stop(); flash = null; if (!queue.length) noticeHovered = false; }

    // A message from an app (Notices.qml): queued, or only counted while it is quiet. One never shown is still
    // in Today and in the Palette's earlier rows.
    function message(n) {
        if (!n) return;
        const urgent = n.urgency === NotificationUrgency.Critical;
        const app = appOf(n);
        if (quiet && !urgent) {
            if (!n.transient) { noticesHeld += 1; heldFrom = [app].concat(heldFrom.filter(a => a !== app)).slice(0, 6); }
            closeMessage(n, "expire");
            return;
        }
        const actions = listOf(n.actions).map(a => ({ id: String(a.identifier ?? ""), text: plain(a.text) }));
        const item = { n: n, summary: String(n.summary ?? ""), body: String(n.body ?? ""), code: codeIn(n), actions: actions, at: Date.now() };
        const left = urgent ? Infinity : actions.some(a => a.id !== "default" && a.text !== "") ? 8000 : 5000;
        const old = queue.find(e => e.key === app) ?? null;
        const entry = old ? { key: app, image: iconOf(n) || old.image, urgent: old.urgent || urgent, left: Math.max(old.left, left), items: [item].concat(old.items).slice(0, 20) }
                          : { key: app, image: iconOf(n), urgent: urgent, left: left, items: [item] };
        n.closed.connect(() => state.forget(n));
        let next = [entry].concat(queue.filter(e => e !== old));
        // A dozen apps at once: the oldest ordinary ones make room.
        const spill = next.filter((e, k) => k >= 12 && !e.urgent);
        if (spill.length) next = next.filter(e => spill.indexOf(e) < 0);
        setQueue(next, false);
        noticeSerial += 1;
        for (const e of spill) for (const i of e.items) closeMessage(i.n, "expire");
    }
    // The app took its message back, or it was answered or put away: it leaves the queue.
    function forget(n) {
        let changed = false;
        const next = [];
        for (const e of queue) {
            const items = e.items.filter(i => i.n !== n);
            if (items.length !== e.items.length) changed = true;
            if (items.length) next.push(items.length === e.items.length ? e : Object.assign({}, e, { items: items }));
        }
        if (changed) setQueue(next, true);
    }
    function setQueue(next, speak) {
        const before = queue.length ? queue[0] : null;
        queue = next;
        if (speak && next.length && next[0] !== before) noticeSerial += 1;
        if (!flash && !next.length) noticeHovered = false;
    }
    // Takes an entry off the queue and closes what it holds, all but the one whose action is running (the app
    // closes that one itself).
    function drop(e, keep) {
        setQueue(queue.filter(x => x !== e), true);
        for (const i of e.items) if (i.n !== keep) closeMessage(i.n, "dismiss");
    }
    function closeMessage(n, how) { try { if (how === "expire") n.expire(); else n.dismiss(); } catch (err) {} }
    function action(item, id) {
        try { return listOf(item.n.actions).find(x => x.identifier === id) ?? null; } catch (err) { return null; }
    }
    // Five seconds each, counted only while the message is on show.
    function tick() {
        const now = Date.now(), spent = now - ticked;
        ticked = now;
        const h = queue.length ? queue[0] : null;
        if (!h) return;
        h.left -= spent;
        // An entry that waited a minute behind others is old news and goes, unless it is urgent.
        const done = queue.filter((e, k) => !e.urgent && (k === 0 ? e.left <= 0 : now - e.items[0].at > 60000));
        if (!done.length) return;
        setQueue(queue.filter(e => done.indexOf(e) < 0), true);
        for (const e of done) for (const i of e.items) closeMessage(i.n, "expire");
    }

    // A press on the notice: a flash opens what it is about; a message runs its app's default action (the app
    // comes forward) or, with none, is put away.
    function activateNotice() {
        if (flash) {
            const f = flash;
            endFlash();
            if (f.act) f.act();
            else if (f.open) Quickshell.execDetached(["gio", "open", f.open]);
            return;
        }
        const e = head;
        if (!e) return;
        const a = action(e.items[0], "default");
        drop(e, a ? e.items[0].n : null);
        if (a) a.invoke();
    }
    // The key for the notice on show (Super+Shift+Space): copy its code when it has one, else what a press does.
    function actNotice() {
        if (flash) { if (flash.code) copyCode(); else activateNotice(); return; }
        if (!head) return;
        if (head.items[0].code) copyCode(); else activateNotice();
    }
    // One of the notice's buttons: the app's own action, or a flash's command.
    function invokeNoticeAction(id) {
        if (flash) {
            const fa = flash.actions.find(x => x.id === id) ?? null;
            endFlash();
            if (fa && fa.run) Quickshell.execDetached(fa.run);
            return;
        }
        const e = head;
        if (!e) return;
        const a = action(e.items[0], id);
        drop(e, a ? e.items[0].n : null);
        if (a) a.invoke();
    }
    // "3 more": the next one comes forward and this one waits at the back.
    function nextNotice() {
        if (flash || queue.length < 2) return;
        const h = queue[0];
        if (h.left < 1500) h.left = 1500;
        setQueue(queue.slice(1).concat([h]), true);
    }
    // The right button puts the notice on show away.
    function dismissNotice() { if (flash) endFlash(); else if (head) drop(head, null); }
    // The key that puts every notice away (Super+Escape), the ones do not disturb is counting included.
    function clearNotices() {
        const all = queue;
        endFlash();
        setQueue([], false);
        noticesHeld = 0;
        heldFrom = [];
        for (const e of all) for (const i of e.items) closeMessage(i.n, "dismiss");
    }
    // The pointer resting on a notice keeps it; leaving lets it go a moment later.
    function holdNotice(on) {
        if (!noticeActive) { noticeHovered = false; return; }
        noticeHovered = on;
        if (flash) { if (on) flashTimer.stop(); else { flashTimer.interval = 1500; flashTimer.restart(); } }
        else if (!on && head && head.left < 1500) head.left = 1500;
    }
    // "Your code is 482913": copied through wl-copy's input, never on a command line, and the message is done.
    function copyCode() {
        const code = flash ? flash.code : head ? head.items[0].code : "";
        if (!code) return;
        if (flash) endFlash(); else drop(head, null);
        copier.running = false;
        copier.environment = { TAKUMI_COPY: code };
        copier.running = true;
        showFlash({ icon: "check", title: "Copied " + code }, 1500);
    }
    // Do not disturb went off: one notice says how many came in, and a press lists them.
    onQuietChanged: {
        if (quiet || noticesHeld === 0) return;
        const count = noticesHeld, from = heldFrom;
        noticesHeld = 0;
        heldFrom = [];
        showFlash({ icon: "bell", title: count === 1 ? "A message came in" : count + " messages came in",
                    detail: "From " + inWords(from) + " · press to see them", act: () => state.search("earlier") }, 6000);
    }

    function listOf(l) { const out = []; if (l) for (let k = 0; k < l.length; k++) out.push(l[k]); return out; }
    function appOf(n) { return String(n.appName || n.desktopEntry || "An app"); }
    function iconOf(n) {
        // A name the icon theme does not have draws a checkerboard, so it is skipped: then the app's own
        // icon, a picture, or Takumi's bell.
        const named = name => name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name, true) : "";
        const i = String(n.appIcon ?? "");
        if (i.startsWith("/") || i.includes("://")) return i;
        const d = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        // notify-send -i also sends the name as a picture, which reads "image://icon/<name>".
        const img = String(n.image ?? "");
        const pic = img.startsWith("image://icon/") ? named(decodeURIComponent(img.slice(13))) : img;
        return named(i) || (d ? named(d.icon) : "") || pic;
    }
    // What a message says now: an app may rewrite a message it already sent (a download's progress).
    function live(item, field) {
        let v;
        try { v = item.n ? item.n[field] : undefined; } catch (err) { v = undefined; }
        return String(v ?? item[field] ?? "");
    }
    function plain(text) {
        return String(text ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&");
    }
    function firstLine(text) { return plain(text).split("\n").map(s => s.trim()).find(s => s !== "") ?? ""; }
    // A 4 to 8 digit code beside words that say it is one.
    function codeIn(n) {
        const text = plain(String(n.summary ?? "") + " " + String(n.body ?? ""));
        const m = /(code|verif|passcode|one-time|otp|pin|login|sign.?in)/i.test(text) ? text.match(/\b(\d{4,8})\b/) : null;
        return m ? m[1] : "";
    }
    function inWords(names) {
        if (!names.length) return "your apps";
        if (names.length === 1) return names[0];
        return names.slice(0, -1).join(", ") + " and " + names[names.length - 1];
    }

    property Timer flashTimer: Timer { interval: Style.noticeHold; onTriggered: state.endFlash() }
    property Timer ticker: Timer {
        interval: 250
        repeat: true
        running: state.queue.length > 0 && state.flash === null && state.openOn === "" && !state.noticeHovered
        onRunningChanged: state.ticked = Date.now()
        onTriggered: state.tick()
    }
    property Process copier: Process { command: ["sh", "-c", "printf %s \"$TAKUMI_COPY\" | wl-copy"] }
}
