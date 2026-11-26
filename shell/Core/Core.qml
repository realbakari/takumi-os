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
    onOpenChanged: {
        if (open) { focusPriming = true; focusPrimeTimer.restart(); trace.play(); }
        else { focusPriming = false; focusPrimeTimer.stop(); }
    }
    // Brief Exclusive -> OnDemand focus prime: grabs keyboard cleanly on summon without trapping clicks
    // across multi-monitor setups; password approvals stay Exclusive for security.
    property bool focusPriming: false
    Timer { id: focusPrimeTimer; interval: 120; onTriggered: win.focusPriming = false }
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
        return !!size && size[0] >= width - Style.niriGap * 2 - 1;
    }

    anchors { left: true; right: true; bottom: true }
    implicitHeight: Style.coreSurface + Style.gap * 3
    exclusiveZone: hidden ? 0 : Style.coreHeight + Style.gap
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "takumi-core"
    WlrLayershell.keyboardFocus: approving || focusPriming ? WlrKeyboardFocus.Exclusive : open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
                        win.approving ? approval.implicitWidth : win.view === "quick" ? quick.implicitWidth
                        : win.view === "today" ? today.implicitWidth : win.view === "keys" ? keysSheet.implicitWidth
                        : win.view === "sound" ? soundDeck.implicitWidth : win.view === "display" ? displayDeck.implicitWidth
                        : win.view === "network" ? netDeck.implicitWidth : win.view === "cockpit" ? cockpitView.implicitWidth
                        : win.open ? Style.coreOpenWidth : win.noticing ? notice.implicitWidth : rest.implicitWidth)
        height: win.approving ? approval.implicitHeight : win.view === "quick" ? quick.implicitHeight
              : win.view === "today" ? today.implicitHeight : win.view === "keys" ? keysSheet.implicitHeight
              : win.view === "sound" ? soundDeck.implicitHeight : win.view === "display" ? displayDeck.implicitHeight
              : win.view === "network" ? netDeck.implicitHeight : win.view === "cockpit" ? cockpitView.implicitHeight
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
                core: win.core; poll: win.poll; niri: win.niri
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
            KeysSheet {
                id: keysSheet
                core: win.core
                active: win.view === "keys"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: keysSheet.active ? Style.enter : 90 } }
            }
            SoundDeck {
                id: soundDeck
                core: win.core; poll: win.poll; niri: win.niri
                active: win.view === "sound"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: soundDeck.active ? Style.enter : 90 } }
            }
            DisplayDeck {
                id: displayDeck
                core: win.core
                active: win.view === "display"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: displayDeck.active ? Style.enter : 90 } }
            }
            NetDeck {
                id: netDeck
                core: win.core; poll: win.poll
                active: win.view === "network"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: netDeck.active ? Style.enter : 90 } }
            }
            Cockpit {
                id: cockpitView
                core: win.core
                active: win.view === "cockpit"
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth; height: implicitHeight
                opacity: active ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: cockpitView.active ? Style.enter : 90 } }
            }
        }

        // GPU Scene Graph optical rim: replaces imperative 2D Canvas so 120Hz spring morphs do zero CPU repaints.
        Item {
            id: rim
            anchors.fill: body
            readonly property color lightTop: capsule.lit ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.rimTop)
            readonly property color lightMid: capsule.lit ? Theme.accentTint(0.22) : Theme.tint(Style.rimMid)
            Rectangle {
                anchors.fill: parent
                radius: body.radius
                color: "transparent"
                border.width: Style.hairline
                border.color: rim.lightMid
                Behavior on border.color { ColorAnimation { duration: Style.enter } }
            }
            // Upper horizon catch along the top edge.
            Rectangle {
                readonly property real inset: Math.min(body.radius * 0.7, parent.width * 0.2)
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: inset; rightMargin: inset }
                height: Style.hairline
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.25; color: rim.lightTop }
                    GradientStop { position: 0.75; color: rim.lightTop }
                    GradientStop { position: 1.0; color: "transparent" }
                }
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
