// The Core: the only shell object. At rest it is a capsule of status at the bottom centre. A notice
// widens it for a moment. Super+Space grows it upward into the Palette; its status marks grow it into
// Quick settings, its clock into Today. When the system needs your password it becomes the question
// (Approval.qml), above everything else. One shape, many states.
// The surface is tall enough for the open state, transparent, and masked to the capsule, so clicks
// elsewhere reach the windows below. See docs/shell.md.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../Look"
import "../Parts"

PanelWindow {
    id: win
    required property var niri
    required property var poll
    required property var core
    required property var approvals
    required property var notices

    required property string output
    readonly property bool approving: approvals.active && core.target() === output
    readonly property bool open: !approving && core.openOn !== "" && core.openOn === output
    readonly property bool noticing: !approving && core.noticeActive && !open && core.target() === output
    readonly property string view: open ? core.view : ""
    onApprovingChanged: if (approving) { Qt.callLater(() => approval.focusField()); trace.play(); }
    onViewChanged: if (open || view !== "") trace.play()
    onOpenChanged: if (open) trace.play()
    // A theme chosen: the Core's light runs in the new accent as the Sky opens (Sky/SkyCanvas.qml).
    Connections { target: Theme; function onNameChanged() { trace.play(); } }
    // Slide away when the focused column on this output fills the strip (maximized or fullscreen).
    readonly property bool hidden: {
        if (open || approving) return false;
        const w = niri.focusedWindow();
        if (!w) return false;
        const ws = niri.workspaces.find(x => x.id === w.workspace_id);
        if (!ws || ws.output !== output) return false;
        const size = w.layout?.tile_size;
        return !!size && size[0] >= width - Style.gap * 2 - 1;
    }

    anchors { left: true; right: true; bottom: true }
    implicitHeight: Style.coreSurface + Style.gap * 3
    exclusiveZone: hidden ? 0 : Style.coreHeight + Style.gap
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "takumi-core"
    WlrLayershell.keyboardFocus: open || approving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: capsule }
    // Frosted glass: niri blurs exactly the capsule's shape behind it. Without a GPU nothing is blurred and
    // the body stays nearly opaque (Style.coreFill).
    BackgroundEffect.blurRegion: Style.glow ? glass : null
    Region { id: glass; item: body; radius: body.radius }

    Item {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.hidden ? -(height + Style.gap * 3) : Style.gap
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Style.slide; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }

        width: Math.min(win.width - Style.gap * 2,
                        win.approving ? approval.implicitWidth : win.view === "quick" ? quick.implicitWidth : win.view === "today" ? today.implicitWidth
                        : win.open ? Style.coreOpenWidth : win.noticing ? notice.implicitWidth : rest.implicitWidth)
        height: win.approving ? approval.implicitHeight : win.view === "quick" ? quick.implicitHeight : win.view === "today" ? today.implicitHeight
              : win.open ? pane.wantedHeight : Style.coreHeight
        Behavior on width  { NumberAnimation { duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.spring } }
        Behavior on height { NumberAnimation { duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.spring } }

        // Light: an accent glow around the capsule while it is open, asking or saying something, breathing
        // while a command works; under it, the shadow that lifts it off the windows.
        readonly property bool lit: win.open || win.approving || win.noticing
        RectangularShadow {
            id: aura
            visible: Style.glow
            anchors.fill: body
            radius: body.radius
            blur: Style.space(56)
            spread: Style.space(1)
            color: Theme.accentTint(Style.auraAlpha)
            opacity: capsule.lit ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: capsule.lit ? Style.enter * 2 : Style.exit } }
            SequentialAnimation on opacity {
                running: win.open && pane.working && Style.continuousMotion; loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: Style.breathe * 1.4; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: Style.breathe * 1.4; easing.type: Easing.InOutSine }
            }
        }
        // Lifted off the windows: a card's elevation at rest, a flyout's while open or asking.
        Elevation {
            anchors.fill: body
            radius: body.radius
            level: capsule.lit ? 32 : 8
        }
        // The contour: a dark hairline just outside the body, so the Core holds its edge over a pale sky
        // or a white window.
        Rectangle {
            anchors.fill: body; anchors.margins: -Style.hairline
            radius: body.radius + Style.hairline
            color: "transparent"
            border.width: Style.hairline; border.color: Qt.rgba(0, 0, 0, Theme.mode === "light" ? 0.10 : 0.38)
        }

        Rectangle {
            id: body
            anchors.fill: parent
            radius: win.open || win.approving ? Style.coreOpenRadius : Style.coreRadius
            Behavior on radius { NumberAnimation { duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeMove } }
            color: Theme.withAlpha(Theme.surface, Style.glow ? (win.open || win.approving ? Style.glassFillOpen : Style.glassFill)
                                                              : (win.open || win.approving ? Style.coreFillOpen : Style.coreFill))
            clip: true
            Behavior on color { ColorAnimation { duration: Style.retint } }

            // Glass: a sheen that fades down from the top. It keeps the body's corners: clip cuts only to the
            // bounding box, so a square sheen showed its corners above the rounded capsule.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.tint(Style.sheen) }
                    GradientStop { position: Math.min(1, Style.space(120) / Math.max(1, body.height)); color: Theme.tint(0) }
                }
            }
            // The sky's colour, faintly, along the top: the Core belongs to the picture behind it, as an
            // opaque material tinted by the desktop does (Mica:
            // https://learn.microsoft.com/windows/apps/design/style/mica), even where nothing can be blurred.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accentTint(Style.skyTint) }
                    GradientStop { position: Math.min(1, Style.space(220) / Math.max(1, body.height)); color: Theme.accentTint(0) }
                }
            }
            Grain { anchors.fill: parent; radius: parent.radius }

            Rest {
                id: rest
                niri: win.niri; poll: win.poll; output: win.output; screenWidth: win.width; core: win.core
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: !win.open && !win.noticing && !win.approving ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: rest.opacity > 0.5 ? 70 : Style.enter } }
                onOpenRequested: win.core.show()
                onSearchRequested: text => win.core.search(text)
                onQuickRequested: win.core.quick()
                onTodayRequested: win.core.today()
            }
            Notice {
                id: notice
                core: win.core
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: win.noticing ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: notice.opacity > 0.5 ? 70 : Style.enter } }
            }
            Approval {
                id: approval
                approvals: win.approvals
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: win.approving ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: win.approving ? Style.enter : 90 } }
            }
            Open {
                id: pane
                niri: win.niri; core: win.core; active: win.open && win.view === ""; output: win.output
                anchors.fill: parent
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: pane.active ? Style.enter : 90 } }
            }
            Quick {
                id: quick
                core: win.core; poll: win.poll
                active: win.view === "quick"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: quick.active ? Style.enter : 90 } }
            }
            Today {
                id: today
                core: win.core; notices: win.notices
                active: win.view === "today"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: today.active ? Style.enter : 90 } }
            }
        }

        // The rim: one hairline of light, brightest at the top, and the accent while the Core is lit.
        Canvas {
            id: rim
            anchors.fill: body
            property real r: body.radius
            property color lightTop: capsule.lit ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.rimTop)
            property color lightMid: Theme.tint(Style.rimMid)
            property color lightLow: Theme.tint(Style.rimLow)
            Behavior on lightTop { ColorAnimation { duration: Style.enter } }
            onRChanged: requestPaint(); onLightTopChanged: requestPaint(); onLightMidChanged: requestPaint()
            onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"), w = width, h = height, rr = Math.min(r, h / 2);
                ctx.reset();
                const g = ctx.createLinearGradient(0, 0, 0, h);
                g.addColorStop(0, lightTop); g.addColorStop(Math.min(0.5, Style.space(28) / Math.max(1, h)), lightMid); g.addColorStop(1, lightLow);
                ctx.strokeStyle = g; ctx.lineWidth = Style.hairline;
                ctx.beginPath(); ctx.roundedRect(0.5, 0.5, w - 1, h - 1, rr, rr); ctx.stroke();
            }
        }
        // Opening: the horizon's light runs out along the top edge (Parts/Trace.qml).
        Trace {
            id: trace
            anchors { left: body.left; right: body.right; top: body.top }
            radius: body.radius
        }
    }

    // A word for what is under the pointer, after a short rest on it: the Core at rest says in a line what
    // a mark means. It sits above the capsule, outside its input mask, so it never takes a click.
    Rectangle {
        id: peek
        readonly property bool want: rest.peekText !== "" && !win.open && !win.noticing && !win.approving && !win.hidden
        property bool shown: false
        onWantChanged: if (want) dwell.restart(); else { dwell.stop(); shown = false; }
        Timer { id: dwell; interval: Style.peekDwell; onTriggered: peek.shown = true }
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: peek.shown ? Style.enter : Style.exit } }
        width: peekLabel.implicitWidth + Style.space(22)
        height: Style.peekHeight
        radius: height / 2
        color: Theme.withAlpha(Theme.surface, Style.coreFill)
        border.width: Style.hairline; border.color: Theme.tint(Style.lineHair)
        Elevation { anchors.fill: parent; radius: parent.radius; level: 16; z: -1 }
        x: Math.max(Style.gap, Math.min(win.width - width - Style.gap, capsule.x + rest.x + rest.peekX - width / 2))
        y: capsule.y - height - Style.space(8)
        Behavior on x { enabled: peek.shown; NumberAnimation { duration: Style.glide; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeMove } }
        Label { id: peekLabel; anchors.centerIn: parent; text: rest.peekText; font.pixelSize: Style.caption }
    }
}
