// The face the Lock and the login screen share: the emblem, the time, the date, one field, whose computer
// it is. Typing goes straight to the field; Enter submits; a failure shakes the field and outlines it red;
// Caps Lock says so under it. On the Lock, the bottom of the screen holds what is playing, the keyboard
// layout (a press goes to the next, so the password is typed in the right one) and the battery.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import "../Look"

Item {
    id: face
    property string user: ""
    property var poll: null               // the Lock passes these; the login screen has neither
    property var niri: null
    property bool capsOn: false           // seen from what typing produces: a capital without Shift
    readonly property var player: poll ? (Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values.find(p => (p.trackTitle ?? "") !== "") ?? null) : null
    property bool busy: false
    property bool failed: false
    property string failText: ""           // what to say instead of "Try again" (the Lock: "Locked for 2 minutes")
    property bool fingerOn: false          // the sensor is listening (the Lock only)
    property bool fingerMissed: false      // that finger was not known
    property bool fingerDone: false        // three wrong fingers: only the password now
    property string hint: fingerOn ? "Touch the sensor or type your password" : "Type your password"
    property string typed: ""
    // The login screen hides its emblem while the boot splash's tile flies onto it (Parts/Arrival.qml).
    property bool emblemShown: true
    property real reveal: 1
    readonly property alias emblem: mark
    signal submitted(string secret)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Arriving: the corner marks draw out from each corner and the great 匠 comes up behind (0 to 1).
    property real frame: 0
    NumberAnimation on frame { from: 0; to: 1; duration: Style.duration(900); easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }

    // 匠, as tall as most of the screen, drawn as its outline only, faintly, behind everything.
    Shape {
        id: ghost
        readonly property real size: Math.min(face.height * 0.86, face.width * 0.62)
        anchors.centerIn: parent
        width: size; height: size
        opacity: face.frame * face.reveal
        scale: 0.96 + 0.04 * face.frame
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.tint(Style.lockGhost)
            strokeWidth: Style.hairline * 1.2
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathText {
                x: 0; y: ghost.size * 0.03
                text: "匠"
                font.family: Style.cjkFamily
                font.pixelSize: ghost.size
                font.weight: Font.Black
            }
        }
    }

    // A thin mark at each corner of the screen, like the corners of a viewfinder.
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool east: index % 2 === 1
            readonly property bool south: index >= 2
            readonly property real arm: Style.space(34) * face.frame
            x: east ? face.width - Style.space(24) - width : Style.space(24)
            y: south ? face.height - Style.space(24) - height : Style.space(24)
            width: Style.space(34); height: Style.space(34)
            opacity: face.reveal
            Rectangle { x: parent.east ? parent.width - width : 0; y: parent.south ? parent.height - height : 0
                        width: parent.arm; height: Style.hairline * 1.5; color: Theme.tint(Style.lockCorner) }
            Rectangle { x: parent.east ? parent.width - width : 0; y: parent.south ? parent.height - height : 0
                        width: Style.hairline * 1.5; height: parent.arm; color: Theme.tint(Style.lockCorner) }
        }
    }

    // Top left, inside its corner mark: how this computer is connected (the Lock only).
    Row {
        visible: !!face.poll
        opacity: face.reveal * face.frame
        anchors { left: parent.left; top: parent.top; leftMargin: Style.space(40); topMargin: Style.space(36) }
        spacing: Style.space(8)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(6); height: width; radius: width / 2
            color: !face.poll || face.poll.link === "none" ? Theme.tint(0.35) : face.poll.attention ? Theme.red : Theme.accent
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            micro: true
            text: !face.poll ? "" : face.poll.link === "none" ? "Offline"
                : (face.poll.link === "wifi" ? "Wi-Fi" : "Wired") + (face.poll.attention ? " · no internet" : "")
                  + (face.poll.vpn ? " · through " + face.poll.vpn : "")
        }
    }

    Column {
        anchors.centerIn: parent
        Emblem {
            id: mark
            size: Style.emblemLock
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: face.emblemShown ? 1 : 0
        }
        Item { width: 1; height: Style.space(26) }
        // Everything but the emblem: while the login screen arrives from the boot splash it waits, then
        // comes up with a small rise (reveal 0 to 1).
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: face.reveal
            transform: Translate { y: (1 - face.reveal) * Style.space(12) }
            Label {
                readonly property real size: Math.min(Style.space(150), face.height * 0.15)
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: size
                font.weight: Font.Light
                font.letterSpacing: size * Style.displayTracking
                elide: Text.ElideNone
            }
            Item { width: 1; height: Style.space(16) }
            Label { anchors.horizontalCenter: parent.horizontalCenter; micro: true; text: Qt.formatDateTime(clock.date, "dddd d MMMM") }
            Item { width: 1; height: Style.space(44) }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.lockField; height: Style.space(44)
            // Glass with the accent's light under it while you type; red when it was wrong.
            RectangularShadow {
                visible: Style.glow
                anchors.fill: field
                radius: field.radius; blur: Style.space(36)
                color: face.failed ? Theme.withAlpha(Theme.red, Style.auraAlpha) : Theme.accentTint(Style.auraAlpha)
                opacity: face.typed.length > 0 || face.failed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.enter } }
            }
            Rectangle {
                id: field
                anchors.fill: parent
                radius: height / 2
                color: Theme.withAlpha(Theme.surface, Style.lockGlass)
                border.width: 1
                border.color: face.failed ? Theme.red : face.typed.length > 0 ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.rimTop)
                Behavior on border.color { ColorAnimation { duration: Style.quick } }
                transform: Translate { id: shakeX }
                Row {
                    visible: face.typed.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(20)
                    spacing: Style.space(10)
                    Repeater { model: Math.min(face.typed.length, 16)
                        delegate: Rectangle {
                            width: Style.space(7); height: width; radius: width / 2; color: Theme.foreground; opacity: 0.9
                            scale: 0.3
                            Component.onCompleted: pop.start()
                            NumberAnimation on scale { id: pop; running: false; to: 1; duration: Style.enter; easing.type: Easing.OutBack }
                        } }
                }
                Label {
                    visible: face.typed.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(20)
                    text: face.busy ? "Checking…" : face.failed ? (face.failText || "Try again") : face.hint
                    dim: Style.textFaint; font.pixelSize: Style.space(12)
                }
            }
            }
            Item { width: 1; height: Style.space(14) }
            // The finger: a quiet mark while the sensor listens; a wrong finger shakes it and turns it red.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: face.fingerOn || face.fingerMissed
                width: Style.space(40); height: visible ? Style.space(48) : 0
                Icon {
                    id: fingerMark
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "finger"; size: Style.space(26)
                    color: face.fingerMissed ? Theme.red : Theme.withAlpha(Theme.foreground, Style.textDim)
                    Behavior on color { ColorAnimation { duration: Style.quick } }
                    transform: Translate { id: fingerShakeX }
                }
                Label {
                    anchors { top: fingerMark.bottom; topMargin: Style.space(4); horizontalCenter: parent.horizontalCenter }
                    visible: face.fingerMissed
                    text: "Not recognised"; font.pixelSize: Style.caption; color: Theme.red
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter; micro: true
                text: face.capsOn ? "Caps Lock is on" : face.user
                color: face.capsOn ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textMicro)
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
    onFailedChanged: if (failed) shake.restart()
    SequentialAnimation {
        id: fingerShake
        NumberAnimation { target: fingerShakeX; property: "x"; to: -6; duration: 50 }
        NumberAnimation { target: fingerShakeX; property: "x"; to: 6; duration: 70 }
        NumberAnimation { target: fingerShakeX; property: "x"; to: 0; duration: 60 }
    }
    onFingerMissedChanged: if (fingerMissed) fingerShake.restart()

    Item {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (!face.busy && face.typed.length) { const s = face.typed; face.typed = ""; face.submitted(s); }
            }
            else if (event.key === Qt.Key_Backspace) face.typed = face.typed.slice(0, -1);
            else if (event.key === Qt.Key_Escape) face.typed = "";
            else if (event.text && !face.busy) {
                const t = event.text;
                if (t.length === 1 && t.toLowerCase() !== t.toUpperCase())
                    face.capsOn = (t === t.toUpperCase()) !== ((event.modifiers & Qt.ShiftModifier) !== 0);
                face.typed += t;
            }
            event.accepted = true;
        }
    }

    // What is playing, with a way to pause it, without unlocking.
    Rectangle {
        visible: face.player !== null
        opacity: face.reveal
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Style.space(28) }
        width: media.implicitWidth + Style.space(28); height: Style.space(38); radius: height / 2
        color: Theme.withAlpha(Theme.surface, Style.lockGlass)
        border.width: Style.hairline; border.color: Theme.tint(Style.lineHair)
        Row {
            id: media
            anchors.centerIn: parent
            spacing: Style.space(10)
            Label { anchors.verticalCenter: parent.verticalCenter; text: face.player?.trackTitle ?? ""; font.weight: Font.DemiBold; width: Math.min(implicitWidth, Style.space(260)) }
            Label { anchors.verticalCenter: parent.verticalCenter; text: face.player?.trackArtist ?? ""; dim: Style.textDim; visible: text !== ""; width: Math.min(implicitWidth, Style.space(200)) }
            Item {
                width: Style.space(22); height: width
                anchors.verticalCenter: parent.verticalCenter
                Icon { anchors.centerIn: parent; name: face.player?.isPlaying ? "pause" : "play"; size: Style.iconSmall; color: Theme.foreground }
                MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor
                    onClicked: if (face.player?.canTogglePlaying) face.player.togglePlaying() }
            }
        }
    }

    // The keyboard layout and the battery.
    Row {
        opacity: face.reveal
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: Style.space(40); bottomMargin: Style.space(34) }
        spacing: Style.space(16)
        Rectangle {
            visible: !!face.niri && face.niri.layouts.length > 1
            anchors.verticalCenter: parent.verticalCenter
            width: code.implicitWidth + Style.space(16); height: Style.space(24); radius: Style.space(6)
            color: "transparent"; border.width: Style.hairline; border.color: Theme.tint(0.2)
            Label { id: code; anchors.centerIn: parent; text: face.niri ? face.niri.layoutShort(face.niri.layout) : ""; font.pixelSize: Style.caption; font.weight: Font.DemiBold; dim: Style.textDim }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: face.niri.nextLayout() }
        }
        Row {
            visible: !!face.poll && face.poll.battery >= 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Item {
                width: Style.space(23); height: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; anchors.rightMargin: 2; radius: Style.space(3.5); color: "transparent"; border.width: 1; border.color: Theme.tint(Style.textDim) }
                Rectangle { x: parent.width - 2; y: parent.height / 2 - 2.5; width: 2; height: 5; radius: 1; color: Theme.tint(Style.textDim) }
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4; radius: 2
                    width: Math.max(1, (parent.width - 6) * Math.min(1, (face.poll?.battery ?? 0) / 100))
                    color: face.poll?.charging ? Theme.accent : (face.poll?.battery ?? 100) <= 15 ? Theme.red : Theme.tint(0.7)
                }
            }
            Label { anchors.verticalCenter: parent.verticalCenter; text: (face.poll?.battery ?? 0) + "%"; font.pixelSize: Style.caption; dim: Style.textDim }
        }
    }
}
