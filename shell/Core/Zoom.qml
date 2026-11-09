// Zoom: a magnified strip docked along the top of the screen, a third of its height, showing the screen below
// it larger: the window you are in, followed as the keyboard moves between windows, and moved with Super+Alt
// and the arrows. niri has no zoom of its own, so the shell draws one from the screen's own picture
// (ScreencopyView, live, through wlr-screencopy). Docked rather than over the whole screen, for three reasons:
// a surface that showed the screen over the screen would show itself, smaller and smaller; niri tells no one
// where the pointer is, so a full-screen zoom could not keep what you point at under the pointer; and clicks go
// to the windows where they really are, which only a strip beside them leaves unconfused. The strip reserves its
// band (an exclusive zone, like a panel), so windows move down under it and nothing is hidden; it takes no
// input and no keyboard. shell.qml makes it and answers qs -c takumi ipc call zoom ...; takumi switch zoom and
// the keys in defaults.kdl call that. See docs/accessibility.md.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Look"
import "../Parts"

PanelWindow {
    id: zoom
    required property var niri
    property bool shown: false
    property real level: 2
    readonly property var levels: [1.5, 2, 3, 4, 6, 8]
    // The point it shows, in the screen's own coordinates: the middle of the window you are in, until the
    // arrows move it; the next window you go to leads again.
    property real cx: 0
    property real cy: 0
    property int followed: -1
    property bool panned: false

    readonly property real screenW: screen ? screen.width : 1
    readonly property real screenH: screen ? screen.height : 1
    readonly property real band: Math.round(screenH / 3)
    // What it shows, in the screen's coordinates: never the band itself, which would show itself.
    readonly property real srcW: screenW / level
    readonly property real srcH: band / level
    readonly property real srcX: Math.max(0, Math.min(cx - srcW / 2, screenW - srcW))
    readonly property real srcY: Math.max(band, Math.min(cy - srcH / 2, screenH - srcH))

    visible: shown
    anchors { top: true; left: true; right: true }
    implicitHeight: band
    exclusiveZone: band
    color: Theme.background
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "takumi-zoom"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // No input at all: every press and every key goes to the windows.
    mask: Region {}

    function said() { return shown ? "on " + level : "off"; }
    function turnOn() {
        if (!shown) {
            const s = Quickshell.screens.find(o => o.name === niri.focusedOutput) ?? Quickshell.screens[0];
            if (s) screen = s;
            followed = -1;
            follow();
            shown = true;
        }
        return said();
    }
    function turnOff() { shown = false; return said(); }
    function toggle() { return shown ? turnOff() : turnOn(); }
    // Closer and farther step through the levels; closer turns it on, farther past the first turns it off.
    function closer() {
        if (!shown) return turnOn();
        level = levels.find(l => l > level) ?? levels[levels.length - 1];
        return said();
    }
    function farther() {
        if (!shown) return said();
        const lower = levels.filter(l => l < level);
        if (!lower.length) return turnOff();
        level = lower[lower.length - 1];
        return said();
    }
    // A quarter of what it shows at a time.
    function pan(direction) {
        if (!shown) return said();
        panned = true;   // stays where you moved it until you go to another window
        const dx = direction === "left" ? -1 : direction === "right" ? 1 : 0, dy = direction === "up" ? -1 : direction === "down" ? 1 : 0;
        cx = Math.max(srcW / 2, Math.min(screenW - srcW / 2, srcX + srcW / 2 + dx * srcW / 4));
        cy = Math.max(band + srcH / 2, Math.min(screenH - srcH / 2, srcY + srcH / 2 + dy * srcH / 4));
        return said();
    }
    // The window you are in, on this screen: its middle. With none, the middle of the screen below the band.
    // niri says where a floating window is, not a tiled one: work that out from its column in the strip. The
    // columns are laid side by side with the gap between (defaults.kdl: gaps 10); when they all fit, the strip
    // starts at the left (one column alone sits in the middle, always-center-single-column), and when they do
    // not, niri brings the focused column to the middle (center-focused-column "on-overflow").
    readonly property real gap: 10
    function placeInStrip(w) {
        const p = w.layout?.pos_in_scrolling_layout;
        if (!p) return null;
        const mine = niri.windows.filter(x => x.workspace_id === w.workspace_id && !x.is_floating && x.layout?.pos_in_scrolling_layout);
        const widths = [];
        for (const x of mine) {
            const c = x.layout.pos_in_scrolling_layout[0] - 1;
            widths[c] = Math.max(widths[c] ?? 0, x.layout.tile_size[0]);
        }
        const col = p[0] - 1;
        let before = 0, total = 0, n = 0;
        for (let c = 0; c < widths.length; c++) {
            const cw = widths[c] ?? 0;
            if (c < col) before += cw + gap;
            total += cw; n++;
        }
        total += gap * Math.max(0, n - 1);
        const room = screenW - 2 * gap, own = widths[col] ?? w.layout.tile_size[0];
        const left = n === 1 ? (screenW - own) / 2 : total <= room ? gap + before : (screenW - own) / 2;
        let top = band + gap;
        for (const x of mine)
            if (x.layout.pos_in_scrolling_layout[0] === p[0] && x.layout.pos_in_scrolling_layout[1] < p[1]) top += x.layout.tile_size[1] + gap;
        return [left, top];
    }
    function follow() {
        const w = niri.focusedWindow();
        const ws = w ? niri.workspaces.find(x => x.id === w.workspace_id) : null;
        const pos = w?.layout?.tile_pos_in_workspace_view, size = w?.layout?.tile_size;
        const at = pos ?? (w && size ? placeInStrip(w) : null);
        if (w && ws && screen && ws.output === screen.name && at && size) {
            followed = w.id;
            cx = at[0] + size[0] / 2;
            cy = at[1] + size[1] / 2;
        } else {
            cx = screenW / 2;
            cy = band + (screenH - band) / 2;
        }
    }
    Connections {
        target: zoom.niri
        function onFocusedWindowIdChanged() { if (zoom.shown && zoom.niri.focusedWindowId !== zoom.followed) { zoom.panned = false; zoom.follow(); } }
        // The band pushes the windows down when it opens, and they move when columns open or close.
        function onWindowsChanged() { if (zoom.shown && !zoom.panned && zoom.niri.focusedWindowId === zoom.followed) zoom.follow(); }
    }

    Item {
        anchors.fill: parent
        clip: true
        Accessible.role: Accessible.Graphic
        Accessible.name: "Zoom, " + zoom.level + " times"
        ScreencopyView {
            id: view
            captureSource: zoom.shown ? zoom.screen : null
            live: true
            paintCursor: true
            width: zoom.screenW * zoom.level
            height: zoom.screenH * zoom.level
            x: -zoom.srcX * zoom.level
            y: -zoom.srcY * zoom.level
            Behavior on x { NumberAnimation { duration: Style.glide; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeMove } }
            Behavior on y { NumberAnimation { duration: Style.glide; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeMove } }
        }
        // The edge between the strip and the screen it shows.
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: Style.hairline * 2
            color: Theme.accent
        }
        // How close, in the corner, for a moment after it changes.
        Rectangle {
            id: badge
            anchors { right: parent.right; bottom: parent.bottom; margins: Style.space(12) }
            width: levelText.implicitWidth + Style.space(16); height: Style.space(26); radius: height / 2
            color: Theme.withAlpha(Theme.surface, 0.9)
            opacity: 0
            Label { id: levelText; anchors.centerIn: parent; text: zoom.level + "×"; font.weight: Font.DemiBold }
            SequentialAnimation {
                id: flashBadge
                NumberAnimation { target: badge; property: "opacity"; to: 1; duration: Style.fade }
                PauseAnimation { duration: 900 }
                NumberAnimation { target: badge; property: "opacity"; to: 0; duration: Style.fade }
            }
        }
    }
    onLevelChanged: if (shown) flashBadge.restart()
    onShownChanged: if (shown) flashBadge.restart()
}
