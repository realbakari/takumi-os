// The face the Lock and the login screen share: the emblem, the time, the date, one field, whose computer
// it is. Typing goes straight to the field; Enter or the field's arrow submits; a failure shakes the field and outlines it red;
// Caps Lock says so under it. On the Lock, the bottom of the screen holds what is playing, the keyboard
// layout (a press goes to the next, so the password is typed in the right one) and the battery. On the login
// screen, the bottom left holds Restart and Shut down.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
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
    property string avatarPath: ""
    // The login screen hides its emblem while the boot splash's tile flies onto it (Parts/Arrival.qml).
    property bool emblemShown: true
    property real reveal: 1
    readonly property alias emblem: mark
    signal submitted(string secret)
    function submit() { if (!busy && typed.length) { const s = typed; typed = ""; submitted(s); } }
    // The login screen offers to restart or shut down: nobody is logged in, so nothing is open to lose.
    property bool canStop: false
    signal stopRequested(string how)       // "restart" or "off"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Resolve user profile picture: TAKUMI_AVATAR (greeter), ~/.config/takumi/avatar, ~/.face, or AccountsService.
    Process {
        id: avatarProbe
        running: true
        command: [
            "sh", "-c",
            'for p in "${TAKUMI_AVATAR:-}" "$HOME/.config/takumi/avatar" "$HOME/.face" "/var/lib/takumi/greeter/avatar" "/var/lib/AccountsService/icons/$1"; do ' +
            '[ -n "$p" ] && [ -r "$p" ] && [ -s "$p" ] && { printf "%s" "$p"; exit 0; }; done',
            "_", face.user || Quickshell.env("USER") || ""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                face.avatarPath = p ? ("file://" + p) : "";
            }
        }
    }
    onUserChanged: if (user && !avatarProbe.running) avatarProbe.running = true

    // Arriving: the corner marks draw out from each corner and the great 匠 comes up behind (0 to 1).
    property real frame: 0
    NumberAnimation on frame { from: 0; to: 1; duration: Style.duration(900); easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }

    // 匠, as tall as most of the screen, as a faint shade behind everything. One glyph of text, not a path:
    // its strokes overlap, and a path draws their outlines crossing (stray boxes) or leaves holes where they meet.
    Text {
        id: ghost
        readonly property real size: Math.min(face.height * 0.86, face.width * 0.62)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -size * 0.09   // the glyph sits low in its line: centre the ink, not the line
        text: "匠"
        font.family: Style.cjkFamily
        font.pixelSize: size
        font.weight: Font.Black
        color: Theme.foreground
        opacity: Style.lockGhost * face.frame * face.reveal
        scale: 0.96 + 0.04 * face.frame
        renderType: Text.QtRendering
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
            Item {
                // Centre the digits themselves on the vertical axis; AM/PM hangs optically to the right.
                anchors.horizontalCenter: parent.horizontalCenter
                width: bigTime.implicitWidth
                height: bigTime.implicitHeight
                Label {
                    id: bigTime
                    readonly property real size: Math.min(Style.space(150), face.height * 0.15)
                    text: Style.formatLockTime(clock.date)
                    font.pixelSize: size
                    font.weight: Font.Light
                    font.letterSpacing: size * Style.displayTracking
                    elide: Text.ElideNone
                }
                Label {
                    id: ampm
                    visible: Style.formatMeridiem(clock.date) !== ""
                    anchors { left: bigTime.right; leftMargin: Style.space(8); baseline: bigTime.baseline }
                    text: Style.formatMeridiem(clock.date)
                    font.pixelSize: Style.heading
                    font.weight: Font.Medium
                    dim: Style.textDim
                    elide: Text.ElideNone
                }
            }
            Item { width: 1; height: Style.space(10) }
            // The date belongs to the clock: close under it, large enough to read from across a room.
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "dddd d MMMM"); font.pixelSize: Style.title; dim: Style.textDim; elide: Text.ElideNone }
            // A wider gap: the time and date above, whose computer it is and its field below.
            Item { width: 1; height: Style.space(44) }
            // Circular profile picture (or sculpted monogram when no photo is set yet).
            Item {
                id: avatarWrap
                anchors.horizontalCenter: parent.horizontalCenter
                width: Style.lockAvatar; height: Style.lockAvatar
                // Drawn live only: the shadow kept for computers without 3D is a rounded square (Elevation.qml).
                Elevation { visible: Style.glow; anchors.fill: parent; radius: width / 2; level: 16 }
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: Theme.withAlpha(Theme.surface, Style.lockGlass)
                    border.width: Style.hairline
                    border.color: face.failed ? Theme.red : face.typed.length > 0 ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.rimTop)
                    Behavior on border.color { ColorAnimation { duration: Style.quick } }
                    Label {
                        visible: !avatarCanvas.loaded
                        anchors.centerIn: parent
                        text: face.user ? face.user.charAt(0).toUpperCase() : "匠"
                        font.pixelSize: Style.space(26); font.weight: Font.Light
                        color: Theme.withAlpha(Theme.foreground, 0.88)
                        elide: Text.ElideNone
                    }
                    Canvas {
                        id: avatarCanvas
                        anchors.fill: parent
                        anchors.margins: Style.hairline
                        property bool loaded: false
                        property string src: face.avatarPath
                        onSrcChanged: { loaded = false; if (src !== "") loadImage(src); else requestPaint(); }
                        Component.onCompleted: if (src !== "") loadImage(src)
                        onImageLoaded: { loaded = isImageLoaded(src); requestPaint(); }
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (!loaded || !src || !isImageLoaded(src)) return;
                            ctx.save();
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2);
                            ctx.closePath();
                            ctx.clip();
                            ctx.drawImage(src, 0, 0, width, height);
                            ctx.restore();
                        }
                    }
                }
            }
            Item { width: 1; height: Style.space(12) }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.capsOn ? "Caps Lock is on" : face.user
                font.pixelSize: Style.subtitle; font.weight: Font.Medium
                color: face.capsOn ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.88)
            }
            Item { width: 1; height: Style.space(16) }
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
                    Repeater { model: Math.min(face.typed.length, Style.lockDots)
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
                // For a hand on the pointer or a finger on the screen: the same as Enter.
                Rectangle {
                    id: go
                    visible: opacity > 0
                    opacity: face.typed.length > 0 && !face.busy ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Style.fade } }
                    anchors { right: parent.right; rightMargin: Style.space(5); verticalCenter: parent.verticalCenter }
                    width: parent.height - Style.space(10); height: width; radius: width / 2
                    color: goArea.pressed ? Theme.accentTint(0.9) : Theme.accent
                    scale: goArea.pressed ? Style.press : 1
                    Accessible.role: Accessible.Button
                    Accessible.name: "Unlock"
                    Accessible.onPressAction: face.submit()
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; color: Theme.background }
                    MouseArea { id: goArea; anchors.fill: parent; anchors.margins: -Style.space(5); cursorShape: Qt.PointingHandCursor; onClicked: face.submit() }
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
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) face.submit();
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

    // Bottom left, on the login screen: restart and shut down, said in words.
    Row {
        visible: face.canStop
        opacity: face.reveal * face.frame
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: Style.space(40); bottomMargin: Style.space(30) }
        spacing: Style.space(8)
        Repeater {
            model: [{ how: "restart", icon: "restart", label: "Restart" }, { how: "off", icon: "power", label: "Shut down" }]
            delegate: Pressable {
                id: stop
                required property var modelData
                width: stopRow.implicitWidth + Style.space(26); height: Style.space(34); radius: height / 2
                accessibleName: modelData.label; raised: true
                color: pressed ? Theme.withAlpha(Theme.surface, 0.9) : Theme.withAlpha(Theme.surface, hovered ? 0.75 : Style.lockGlass)
                onClicked: face.stopRequested(modelData.how)
                Row {
                    id: stopRow
                    anchors.centerIn: parent
                    spacing: Style.space(7)
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: stop.modelData.icon; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: stop.modelData.label; font.pixelSize: Style.caption; dim: 0.85; elide: Text.ElideNone }
                }
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
