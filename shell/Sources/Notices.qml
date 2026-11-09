// The notification server: messages from apps become notices in the Core. Sources/CoreState.qml queues them,
// shows their buttons, groups several from one app and counts them while do not disturb is on (urgent ones
// still show). Every message is also written to ~/.local/state/takumi/notices.jsonl, one JSON object per line,
// which Today and the Palette's "earlier" rows read. See docs/notifications.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: notices
    required property var core          // CoreState
    property bool dnd: false
    onDndChanged: notices.core.quiet = dnd
    property var recent: []             // newest first: { app, icon, summary, body, at }

    property NotificationServer server: NotificationServer {
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
            notices.recent = [{ app: n.appName, icon: n.appIcon, summary: n.summary, body: n.body, at: Date.now() }]
                .concat(notices.recent).slice(0, 50);
            const urgent = n.urgency === NotificationUrgency.Critical;
            if (!n.transient) notices.keep({ ts: Math.floor(Date.now() / 1000), app: n.appName ?? "", icon: notices.iconName(n), summary: n.summary ?? "",
                                             body: String(n.body ?? "").replace(/<[^>]*>/g, ""), urgency: urgent ? "critical" : n.urgency === NotificationUrgency.Low ? "low" : "normal" });
            notices.core.message(n);
        }
    }

    // notify-send -i gives its icon as a picture ("image://icon/<name>"), not as the app's icon: keep the name.
    function iconName(n) {
        const img = String(n.image ?? "");
        return String(n.appIcon || (img.startsWith("image://icon/") ? decodeURIComponent(img.slice(13)) : ""));
    }

    // Super+Alt+Page Down and Page Up (IPC: notices next | previous) go through the messages waiting behind the
    // one on show: next sends it to the back and brings the one behind it; previous brings the last one back.
    // Each keeps a moment on show, as a press on "3 more" does. A flash (Takumi's own notice) is not queued.
    function next() { notices.core.nextNotice(); }
    function previous() {
        const c = notices.core, q = c.queue;
        if (c.flash || q.length < 2) return;
        const last = q[q.length - 1];
        if (last.left < 1500) last.left = 1500;
        c.setQueue([last].concat(q.slice(0, -1)), true);
    }

    // `takumi switch dnd` keeps a flag file; read it at start and whenever it is toggled (IPC).
    property Process probe: Process {
        running: true
        command: ["test", "-e", Quickshell.env("HOME") + "/.local/state/takumi/dnd"]
        onExited: code => notices.dnd = code === 0
    }
    function refreshDnd() { if (!probe.running) probe.running = true; }

    // One line per message, appended; the file is trimmed to its last 200 lines once it passes 400.
    readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/takumi/notices.jsonl"
    property var pending: []
    function keep(entry) { pending = pending.concat([JSON.stringify(entry)]); if (!writer.running) flush(); }
    function flush() {
        if (!pending.length) return;
        const lines = pending.join("\n"); pending = [];
        writer.command = ["sh", "-c", 'f=$1; mkdir -p "${f%/*}"; printf "%s\\n" "$2" >> "$f"; [ "$(wc -l < "$f")" -gt 400 ] && { tail -n 200 "$f" > "$f.new" && mv "$f.new" "$f"; } || true', "_", historyPath, lines];
        writer.running = true;
    }
    property Process writer: Process { onExited: notices.flush() }
}
