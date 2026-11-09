// The Core at rest: what you are in, where you are, what is playing, the time, and how the computer is.
// Each part shows only when it has something to say; nothing stands in for an empty place. Every part you
// can press is a segment that lights under the pointer and gives a little when pressed. See docs/shell.md.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import "../Look"
import "../Parts"

Item {
    id: rest
    required property var niri
    required property var poll
    required property string output
    required property real screenWidth
    property var core: null                // for the messages held back while do not disturb is on
    signal openRequested()
    signal searchRequested(string text)
    signal quickRequested()
    signal todayRequested()

    implicitWidth: row.implicitWidth + Style.corePadLeft + Style.corePadRight
    implicitHeight: Style.coreHeight
    width: implicitWidth
    height: implicitHeight

    // Each screen shows its own: the window its workspace is on, that window's app, and its title without
    // the app's name repeated at the end ("… — Mozilla Firefox").
    readonly property var workspace: niri.activeWorkspace(output)
    readonly property var window: workspace && workspace.active_window_id != null
        ? niri.windows.find(w => w.id === workspace.active_window_id) ?? null : null
    readonly property var app: window ? (DesktopEntries.byId(window.app_id ?? "") ?? DesktopEntries.heuristicLookup(window.app_id ?? "")) : null
    // Takumi's own word for an app it ships whose name means nothing to a newcomer.
    readonly property var ownNames: ({ "foot": "Terminal", "footclient": "Terminal" })
    readonly property string appName: ownNames[window?.app_id ?? ""] ?? app?.name ?? window?.app_id ?? ""
    readonly property string title: {
        let t = (window?.title ?? "").trim();
        const cut = Math.max(t.lastIndexOf(" — "), t.lastIndexOf(" - "));
        if (cut > 0 && appName && t.slice(cut + 3).toLowerCase().includes(appName.toLowerCase())) t = t.slice(0, cut);
        return t.toLowerCase() === appName.toLowerCase() ? "" : t;
    }
    readonly property var cols: niri.columnsOn(output)
    // Workspaces worth a number: the one you are on and every one with a window.
    readonly property var spaces: niri.workspacesOn(output).filter(w => w.is_active || w.active_window_id != null)
    // What is playing, or paused with a song still in it.
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    // The network in words, only when something is in the way.
    readonly property string netWords: poll.link === "none" ? "Offline"
        : poll.connectivity === "portal" ? "Sign in"
        : (poll.connectivity === "limited" || poll.connectivity === "none") ? "No internet" : ""
    // The same, all of it in words, for the word above the status marks.
    readonly property string statusWords: {
        const parts = [];
        if (poll.dnd) parts.push("Do not disturb" + (core && core.noticesHeld > 0 ? " · " + core.noticesHeld + " held" : ""));
        if (poll.updateReady) parts.push("Update ready, restart to use it");
        else if (poll.updates > 0) parts.push(poll.updates + (poll.updates === 1 ? " update" : " updates") + " waiting");
        if (poll.micMuted) parts.push("Microphone off");
        if (poll.awake) parts.push("Staying awake");
        if (poll.nightLight) parts.push("Night light");
        if (poll.remote > 0) parts.push(poll.remote > 1 ? "Someone is using this screen" : "Remote help on");
        if (poll.link === "wifi") parts.push("Wi-Fi " + (netWords ? "· " + netWords.toLowerCase() : ["weak", "good", "strong"][Math.max(0, poll.bars - 1)]));
        else if (poll.link === "wired") parts.push("Wired" + (netWords ? " · " + netWords.toLowerCase() : ""));
        else parts.push("Offline");
        if (poll.vpn) parts.push((poll.vpnConnecting ? "Connecting VPN " : "VPN ") + poll.vpn);
        if (poll.battery >= 0) parts.push((poll.charging ? "Charging " : "Battery ") + poll.battery + "%");
        if (poll.volume >= 0) parts.push(poll.muted ? "Muted" : "Sound " + poll.volume + "%");
        return parts.join(" · ");
    }

    // The word above the Core (Core.qml) says what the mark under the pointer means. Leaving a mark keeps
    // its word a moment, so moving along the Core changes the word instead of hiding it.
    property var peekFrom: null
    function hover(item, on) {
        if (on) { peekFrom = item; peekLeave.stop(); }
        else if (peekFrom === item) peekLeave.restart();
    }
    Timer { id: peekLeave; interval: 120; onTriggered: rest.peekFrom = null }
    readonly property string peekText: peekFrom ? (peekFrom.hint ?? "") : ""
    // Mapped again whenever the row's layout moves (the 0 * terms only make the binding listen to them).
    readonly property real peekX: peekFrom ? peekFrom.mapToItem(rest, peekFrom.width / 2, 0).x + 0 * (row.width + peekFrom.x + peekFrom.width) : 0

    component Separator: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1; height: Style.space(16); color: Theme.tint(Style.lineHair)
    }

    Row {
        id: row
        x: Style.corePadLeft
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        // The emblem opens the Core; it lifts a little under the pointer.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.emblemCore; height: Style.emblemCore
            Emblem {
                anchors.centerIn: parent
                size: Style.emblemCore
                scale: emblemArea.pressed ? Style.press : emblemArea.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Style.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }
            }
            MouseArea {
                id: emblemArea
                property string hint: "Search apps, settings and files"
                anchors.fill: parent; anchors.margins: -Style.space(4)
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: rest.openRequested()
                onContainsMouseChanged: rest.hover(emblemArea, containsMouse)
            }
        }

        Item { width: Style.space(4); height: 1 }

        // What you are in: the app and its window's title. A press opens the Core on that app: its windows,
        // and everything else about it.
        Segment {
            id: appSeg
            visible: rest.window !== null
            hint: "Search " + rest.appName
            onHoveredChanged: rest.hover(appSeg, hovered)
            onClicked: rest.searchRequested(rest.appName)
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Style.restAppIcon
                source: rest.app?.icon ? Quickshell.iconPath(rest.app.icon, true) : ""
                visible: source != ""
            }
            Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText; text: rest.appName; font.weight: Font.DemiBold }
            Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText;
                visible: text !== ""
                text: rest.title
                dim: Style.textDim
                width: Math.min(implicitWidth, Math.min(Style.restTitle, rest.screenWidth * 0.2))
            }
        }
        // The strip, when it holds more than one column: a block per column, as wide as the column is,
        // the one you are in lit. A press goes to that window.
        Row {
            visible: rest.window !== null && rest.cols.length > 1
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)
            Repeater {
                model: rest.cols
                delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(Style.space(6), Math.round(modelData.width / Math.max(1, rest.screenWidth) * Style.mapUnit))
                    height: blockArea.containsMouse && !modelData.focused ? Style.space(16) : Style.space(14)
                    radius: Style.space(3)
                    color: modelData.focused ? Theme.accent : Theme.tint(blockArea.containsMouse ? 0.4 : 0.22)
                    Behavior on width { NumberAnimation { duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }
                    Behavior on height { NumberAnimation { duration: Style.quick } }
                    Behavior on color { ColorAnimation { duration: Style.quick } }
                    MouseArea { id: blockArea; anchors.fill: parent; anchors.margins: -Style.space(2); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rest.niri.focusWindow(modelData.windowId) }
                }
            }
        }
        // Nothing open: the way in, in words.
        Segment {
            id: searchSeg
            visible: rest.window === null
            hint: "Search apps, settings and files"
            onHoveredChanged: rest.hover(searchSeg, hovered)
            onClicked: rest.openRequested()
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "search"; size: Style.restIcon }
            Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText; text: "Search"; dim: Style.textDim }
        }

        // Workspaces by number, when there is more than one to go to. The wheel over them goes up and down.
        Row {
            visible: rest.spaces.length > 1
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Style.space(4)
            spacing: Style.space(4)
            WheelHandler {
                property real acc: 0
                onWheel: event => {
                    acc += event.angleDelta.y;
                    if (Math.abs(acc) >= 120) { rest.niri.action([acc > 0 ? "focus-workspace-up" : "focus-workspace-down"]); acc = 0; }
                }
            }
            Repeater {
                model: rest.spaces
                delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.restSlot; height: Style.restSlot; radius: height / 2
                    color: modelData.is_active ? Theme.accent : Theme.tint(slotArea.containsMouse ? Style.fillHover * 3 : 0.07)
                    scale: slotArea.pressed ? Style.press : 1
                    Behavior on color { ColorAnimation { duration: Style.quick } }
                    Behavior on scale { NumberAnimation { duration: Style.quick } }
                    Label {
                        anchors.centerIn: parent
                        text: modelData.name || String(modelData.idx)
                        font.pixelSize: Style.restSmall; font.weight: Font.DemiBold
                        color: modelData.is_active ? Theme.background : Theme.withAlpha(Theme.foreground, Style.textDim)
                    }
                    MouseArea { id: slotArea; anchors.fill: parent; anchors.margins: -Style.space(2); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rest.niri.focusWorkspace(modelData.idx) }
                }
            }
        }

        // What is playing: three bars that move while it plays (still when drawing in software), the play
        // mark while it is paused. A press plays or pauses it.
        Segment {
            id: mediaSeg
            visible: rest.player !== null
            hint: (rest.player?.identity || "Music") + (rest.player?.isPlaying ? " · press to pause" : " · press to play")
            onHoveredChanged: rest.hover(mediaSeg, hovered)
            onClicked: if (rest.player?.canTogglePlaying) rest.player.togglePlaying()
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.restIcon; height: Style.restIcon
                Icon { visible: !rest.player?.isPlaying; name: "play"; size: Style.restIcon; color: Theme.accent }
                Row {
                    visible: !!rest.player?.isPlaying
                    anchors.centerIn: parent
                    height: Style.space(14)
                    spacing: Style.space(2.5)
                    Repeater {
                        model: [0.55, 1.0, 0.7]
                        delegate: Rectangle {
                            required property real modelData
                            required property int index
                            anchors.bottom: parent.bottom
                            width: Style.space(3); radius: width / 2
                            height: parent.height * modelData
                            color: Theme.accent
                            SequentialAnimation on height {
                                running: !!rest.player?.isPlaying && Style.continuousMotion
                                loops: Animation.Infinite
                                NumberAnimation { to: Style.space(14) * (0.25 + 0.2 * index); duration: 260 + index * 90; easing.type: Easing.InOutSine }
                                NumberAnimation { to: Style.space(14) * (1.0 - 0.15 * index); duration: 300 + index * 70; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
            Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText;
                text: [rest.player?.trackTitle, rest.player?.trackArtist].filter(s => s).join(" — ")
                width: Math.min(implicitWidth, Style.restMedia)
            }
        }

        Item { width: Style.space(4); height: 1 }
        Separator {}
        Item { width: Style.space(4); height: 1 }

        // The time. A press opens Today: the month, and what your apps said earlier.
        Segment {
            id: clockSeg
            hint: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
            onHoveredChanged: rest.hover(clockSeg, hovered)
            onClicked: rest.todayRequested()
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Label { text: Qt.formatDateTime(clock.date, "ddd d MMM"); dim: Style.textDim; font.pixelSize: Style.restText; anchors.baseline: time.baseline }
            Label { id: time; anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDateTime(clock.date, "HH:mm"); font.weight: Font.DemiBold; font.pixelSize: Style.restTime }
        }

        Item { width: Style.space(4); height: 1 }
        Separator {}
        Item { width: Style.space(4); height: 1 }

        // Apps that keep running in the background: a press opens one, the right button its menu.
        Repeater {
            model: SystemTray.items
            delegate: Segment {
                id: tray
                required property var modelData
                pad: Style.space(7)
                hint: modelData.tooltipTitle || modelData.title || ""
                onHoveredChanged: rest.hover(tray, hovered)
                onClicked: {
                    if (!modelData.onlyMenu) { modelData.activate(); return; }
                    if (modelData.hasMenu) { const p = tray.mapToItem(null, 0, 0); modelData.display(QsWindow.window, p.x, p.y); }
                }
                onRightClicked: if (modelData.hasMenu) { const p = tray.mapToItem(null, 0, 0); modelData.display(QsWindow.window, p.x, p.y); }
                IconImage { anchors.verticalCenter: parent.verticalCenter; implicitSize: Style.restIcon; source: tray.modelData.icon }
            }
        }
        // A recording in progress: a red mark and how long it has run. A press stops it.
        Segment {
            id: recSeg
            visible: rest.poll.recording
            pad: Style.space(10)
            hint: "Recording the screen · press to stop"
            onHoveredChanged: rest.hover(recSeg, hovered)
            onClicked: Quickshell.execDetached(["takumi", "screen", "record", "stop"])
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(10); height: width; radius: width / 2
                color: Theme.red
                SequentialAnimation on opacity {
                    running: rest.poll.recording && Style.continuousMotion; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: Style.breathe; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Style.breathe; easing.type: Easing.InOutSine }
                }
            }
            Label {
                id: recTime
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Style.restText; color: Theme.red
                property real nowSecs: Date.now() / 1000
                readonly property int secs: Math.max(0, Math.floor(nowSecs - rest.poll.recordingSince))
                text: Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")
                Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: rest.poll.recording; onTriggered: recTime.nowSecs = Date.now() / 1000 }
            }
        }
        // Someone you let in sees this screen (takumi screen remote): a quiet mark while it waits, red while they
        // are connected. A press opens the Core on stopping it.
        Segment {
            id: remoteSeg
            visible: rest.poll.remote > 0
            pad: Style.space(9)
            hint: rest.poll.remote > 1 ? "Someone is seeing and using this screen · press to stop" : "Remote help is on · press to stop"
            onHoveredChanged: rest.hover(remoteSeg, hovered)
            onClicked: rest.searchRequested("stop remote help")
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "person"; size: Style.restIcon
                   color: rest.poll.remote > 1 ? Theme.red : Theme.withAlpha(Theme.foreground, Style.textDim) }
        }
        // Dictation is listening (takumi voice): the microphone in the accent, breathing. A press stops it and
        // types what was said.
        Segment {
            id: dictSeg
            visible: rest.poll.dictating
            pad: Style.space(9)
            hint: "Listening · press, or Super+H, to stop and type it"
            onHoveredChanged: rest.hover(dictSeg, hovered)
            onClicked: Quickshell.execDetached(["takumi", "voice", "stop"])
            Icon {
                id: dictMark
                anchors.verticalCenter: parent.verticalCenter; name: "mic"; size: Style.restIcon; color: Theme.accent
                SequentialAnimation on opacity {
                    running: rest.poll.dictating && Style.continuousMotion; loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: Style.breathe; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Style.breathe; easing.type: Easing.InOutSine }
                    onStopped: dictMark.opacity = 1
                }
            }
        }
        // A timer is running (takumi timer): what is left of the next one. A press opens Today, which lists them.
        Segment {
            id: timerSeg
            visible: timerLeft.secs > 0
            pad: Style.space(9)
            hint: "Timer · rings at " + Qt.formatDateTime(new Date(rest.poll.timerAt * 1000), "HH:mm") + " · press for Today"
            onHoveredChanged: rest.hover(timerSeg, hovered)
            onClicked: rest.todayRequested()
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: Style.restIcon; color: Theme.withAlpha(Theme.foreground, Style.textDim) }
            Label {
                id: timerLeft
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Style.restText; dim: Style.textDim
                property real nowSecs: Date.now() / 1000
                readonly property int secs: rest.poll.timerAt > 0 ? Math.max(0, Math.ceil(rest.poll.timerAt - nowSecs)) : 0
                text: secs >= 3600 ? Math.floor(secs / 3600) + ":" + String(Math.floor(secs % 3600 / 60)).padStart(2, "0") + " h"
                                   : Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")
                Timer { interval: 1000; repeat: true; triggeredOnStart: true; running: rest.poll.timerAt > 0; onTriggered: timerLeft.nowSecs = Date.now() / 1000 }
            }
        }
        // Privacy: while an app records the microphone or takes the camera, its mark shows in the accent.
        // Dictation's own listening has its mark above.
        Segment {
            id: privacySeg
            visible: rest.poll.cameraInUse || (rest.poll.micInUse && !rest.poll.dictating)
            pad: Style.space(8)
            hint: rest.poll.cameraInUse && rest.poll.micInUse ? "Camera and microphone in use" : rest.poll.cameraInUse ? "Camera in use" : "Microphone in use"
            onHoveredChanged: rest.hover(privacySeg, hovered)
            onClicked: rest.searchRequested("microphone")
            Icon { visible: rest.poll.cameraInUse; anchors.verticalCenter: parent.verticalCenter; name: "video"; size: Style.restIcon; color: Theme.accent }
            Icon { visible: rest.poll.micInUse && !rest.poll.dictating; anchors.verticalCenter: parent.verticalCenter; name: "mic"; size: Style.restIcon; color: Theme.accent }
        }
        // A USB drive or card is open: a press offers to eject it.
        Segment {
            id: driveSeg
            visible: rest.poll.driveOpen !== ""
            pad: Style.space(9)
            hint: rest.poll.driveOpen + " is open · press to eject it"
            onHoveredChanged: rest.hover(driveSeg, hovered)
            onClicked: rest.searchRequested("eject")
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "usb"; size: Style.restIcon; color: Theme.withAlpha(Theme.foreground, Style.textDim) }
        }
        // The keyboard layout, when there is more than one to type in: a press goes to the next.
        Segment {
            id: layoutSeg
            visible: rest.niri.layouts.length > 1
            pad: Style.space(9)
            hint: rest.niri.layout + " · press for the next layout"
            onHoveredChanged: rest.hover(layoutSeg, hovered)
            onClicked: rest.niri.nextLayout()
            Label { anchors.verticalCenter: parent.verticalCenter; text: rest.niri.layoutShort(rest.niri.layout); font.pixelSize: Style.restSmall; font.weight: Font.DemiBold; dim: Style.textDim }
        }
        // How the computer is: the network (in words when something is in the way, in the accent when a
        // sign-in page or a broken network stands in the way), the battery and the sound, together one door
        // to Quick settings. The wheel over them turns the sound up or down.
        Segment {
            id: status
            pad: Style.space(10)
            hint: rest.statusWords
            onHoveredChanged: rest.hover(status, hovered)
            onClicked: rest.quickRequested()
            onRightClicked: rest.quickRequested()
            readonly property color tone: rest.poll.attention ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim)
            // Updates are waiting, or one is ready: a small dot in the accent at the door's corner.
            Rectangle {
                parent: status
                visible: rest.poll.updates > 0 || rest.poll.updateReady
                width: Style.space(6); height: width; radius: width / 2
                color: Theme.accent
                x: status.width - width - Style.space(3); y: Style.space(5)
                z: 2
            }
            // The modes you turned on, each a quiet mark while it lasts.
            Icon { visible: rest.poll.dnd; anchors.verticalCenter: parent.verticalCenter; name: "bellOff"; size: Style.restIcon }
            Label {   // messages held back while do not disturb is on
                visible: rest.poll.dnd && !!rest.core && rest.core.noticesHeld > 0
                anchors.verticalCenter: parent.verticalCenter
                text: rest.core ? rest.core.noticesHeld : ""
                font.pixelSize: Style.restSmall; font.weight: Font.DemiBold; dim: Style.textDim
            }
            Icon {    // the microphone is muted: in the accent while an app is trying to listen
                visible: rest.poll.micMuted; anchors.verticalCenter: parent.verticalCenter; name: "micOff"; size: Style.restIcon
                color: rest.poll.micInUse ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim)
            }
            Icon {    // the internet goes through a VPN; it breathes while it connects
                id: vpnMark
                visible: rest.poll.vpn !== ""; anchors.verticalCenter: parent.verticalCenter; name: "shield"; size: Style.restIcon
                color: Theme.withAlpha(Theme.foreground, Style.textDim)
                SequentialAnimation on opacity {
                    running: rest.poll.vpnConnecting && Style.continuousMotion; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: Style.breathe; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Style.breathe; easing.type: Easing.InOutSine }
                    onStopped: vpnMark.opacity = 1
                }
            }
            Icon { visible: rest.poll.awake; anchors.verticalCenter: parent.verticalCenter; name: "cup"; size: Style.restIcon }
            Icon { visible: rest.poll.nightLight; anchors.verticalCenter: parent.verticalCenter; name: "moon"; size: Style.restIcon }
            WheelHandler {
                property real acc: 0
                onWheel: event => {
                    acc += event.angleDelta.y;
                    while (Math.abs(acc) >= 120) { Quickshell.execDetached(["takumi", "audio", "volume", ["down", "up"][acc > 0 ? 1 : 0]]); acc -= acc > 0 ? 120 : -120; }
                }
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.restIcon; height: Style.restIcon
                SignalIcon { visible: rest.poll.link === "wifi"; bars: rest.poll.bars; size: Style.restIcon; color: status.tone }
                Icon { visible: rest.poll.link !== "wifi"; name: rest.poll.link === "wired" ? "wired" : "wifiOff"; size: Style.restIcon; color: status.tone }
            }
            Label { anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText; visible: text !== ""; text: rest.netWords; color: status.tone }
            // The battery: drawn, not a glyph; its fill the colour of the state.
            Item {
                visible: rest.poll.battery >= 0
                width: Style.space(23); height: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; anchors.rightMargin: 2; radius: Style.space(3.5); color: "transparent"; border.width: 1; border.color: Theme.tint(Style.textDim) }
                Rectangle { x: parent.width - 2; y: parent.height / 2 - 2.5; width: 2; height: 5; radius: 1; color: Theme.tint(Style.textDim) }
                Rectangle {
                    x: 2; y: 2; height: parent.height - 4
                    width: Math.max(1, (parent.width - 6) * Math.min(1, rest.poll.battery / 100))
                    radius: 2
                    color: rest.poll.charging ? Theme.accent : rest.poll.battery <= 15 ? Theme.red : Theme.tint(0.7)
                    Behavior on width { NumberAnimation { duration: Style.enter } }
                }
            }
            Label {
                id: batteryText
                visible: rest.poll.battery >= 0
                anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Style.restText
                text: rest.poll.battery + "%"; dim: Style.textDim
                // Measured against the widest value so the capsule never shifts as it changes.
                TextMetrics { id: widest; font: batteryText.font; text: "100%" }
                width: widest.width
            }
            Icon {
                visible: rest.poll.volume >= 0
                anchors.verticalCenter: parent.verticalCenter
                name: rest.poll.muted || rest.poll.volume === 0 ? "mute" : "vol"; size: Style.restIcon
            }
        }
    }
}
