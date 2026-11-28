// Quick settings: the Core grown into the switches people reach for most, as two rows of discs (the
// network, Bluetooth, do not disturb, the night light, staying awake, the microphone, the power mode, the
// look), two levels (the sound, and the screen's brightness where it has a backlight) and, while a song
// plays, what is playing (NowPlaying). A press on a disc switches it; a press on its words opens the
// Palette on that topic for the rest (networks, devices, schedules). The power button turns the switches
// into the four ways to stop. Typing anything opens the Palette with what you typed. State comes from
// `takumi switch state`; a press shows its result at once and the next read confirms it. See docs/shell.md.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

FocusScope {
    id: quick
    required property var core
    required property var poll
    property var niri: null
    property bool active: false
    implicitWidth: Style.quickWidth
    implicitHeight: column.implicitHeight + Style.space(32)

    property var st: ({})
    property real changedAt: 0             // a read that started before the last press is out of date
    property real readAt: 0
    property bool stopping: false          // the four ways to stop, in place of the tiles
    property string armed: ""              // a way to stop waiting for its second press

    onActiveChanged: {
        stopping = false; armed = "";
        if (active) {
            read(); Qt.callLater(() => quick.forceActiveFocus());
            for (let i = 0; i < tiles.children.length; i++) {
                const t = tiles.children[i];
                if (t.arrive) { t.order = Math.floor(i / Style.switchColumns) + i % Style.switchColumns; t.arrive(); }
            }
        }
    }
    Timer { interval: 3000; repeat: true; running: quick.active; onTriggered: if (Date.now() - quick.changedAt > 1500) quick.read() }
    Timer { id: settle; interval: 1200; onTriggered: quick.read() }

    function read() { if (!reader.running) { readAt = Date.now(); reader.running = true; } }
    Process {
        id: reader
        command: ["takumi", "switch", "state"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (quick.readAt < quick.changedAt) return;
                try { quick.st = JSON.parse(this.text); } catch (e) {}
            }
        }
    }
    // Show the change at once, run the command, read the real state a moment later.
    function change(patch, argv) {
        st = Object.assign({}, st, patch);
        changedAt = Date.now();
        Quickshell.execDetached(argv);
        settle.restart();
    }

    readonly property var profileNames: ({ "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" })
    function nextProfile() {
        const order = ["balanced", "power-saver", "performance"].filter(p => (st.profiles ?? []).includes(p));
        if (!order.length) return "";
        return order[(order.indexOf(st.profile) + 1) % order.length];
    }
    function inHour() { const d = new Date(Date.now() + 3600 * 1000); return Qt.formatTime(d, "HH:mm"); }
    function duration(m) { const h = Math.floor(m / 60), r = m % 60; return h > 0 ? h + " h" + (r ? " " + r + " min" : "") : r + " min"; }
    readonly property string powerWords: {
        const b = poll.battery;
        if (b < 0) return "";
        if (poll.charging) return "Charging · " + b + "%";
        if (st.charge === "full") return "Full · plugged in";
        return b + "%" + ((st.left ?? -1) > 0 ? " · about " + duration(st.left) + " left" : " on battery");
    }

    // The sound and brightness follow a drag at most every 60 ms.
    property int wantVolume: -1
    property int wantBright: -1
    Timer {
        id: levelTimer; interval: 60
        onTriggered: {
            if (quick.wantVolume >= 0) {
                Quickshell.execDetached(["sh", "-c", 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "$1%"', "_", String(quick.wantVolume)]);
                quick.wantVolume = -1; pollSoon.restart();
            }
            if (quick.wantBright >= 0) {
                Quickshell.execDetached(["brightnessctl", "-q", "set", quick.wantBright + "%"]);
                quick.st = Object.assign({}, quick.st, { brightness: quick.wantBright }); quick.wantBright = -1;
            }
        }
    }
    Timer { id: pollSoon; interval: 150; onTriggered: quick.poll.refresh() }
    // Capture starts once the Core has closed, so the Core is not in the picture.
    property var captureArgv: []
    function capture(argv) { captureArgv = argv; core.close(); captureTimer.restart(); }
    Timer { id: captureTimer; interval: 350; onTriggered: Quickshell.execDetached(quick.captureArgv) }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (stopping) { stopping = false; armed = ""; } else core.close();
            event.accepted = true;
        } else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            core.search(event.text);
            event.accepted = true;
        }
    }

    Column {
        id: column
        x: Style.space(16); y: Style.space(16)
        width: parent.width - Style.space(32)
        spacing: Style.space(14)

        // What the computer is running on, then the cockpit, lock and power buttons.
        Item {
            width: parent.width; height: Style.space(38)
            Column {
                anchors { left: parent.left; right: headActions.left; rightMargin: Style.space(10); verticalCenter: parent.verticalCenter }
                spacing: Style.space(2)
                Label { width: parent.width; text: quick.stopping ? "Stop for now" : "Quick settings"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
                Label { width: parent.width; text: quick.stopping ? "Open apps are asked to close first" : quick.powerWords; visible: text !== ""; font.pixelSize: Style.caption; dim: Style.textDim }
            }
            Row {
                id: headActions
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Style.space(6)
                Pressable {
                    width: Style.space(36); height: width; radius: width / 2
                    accessibleName: "Intent Cockpit"; raised: true
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                    onClicked: quick.core.cockpit()
                    Icon { anchors.centerIn: parent; name: "quote"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
                }
                Pressable {
                    width: Style.space(36); height: width; radius: width / 2
                    accessibleName: "Lock"; raised: true
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                    onClicked: { Quickshell.execDetached(["takumi", "lock"]); quick.core.close(); }
                    Icon { anchors.centerIn: parent; name: "lock"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
                }
                Pressable {
                    width: Style.space(36); height: width; radius: width / 2
                    accessibleName: quick.stopping ? "Back to Quick settings" : "Sleep, restart, shut down or log out"; raised: true
                    color: quick.stopping ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                    onClicked: { quick.stopping = !quick.stopping; quick.armed = ""; }
                    Icon { anchors.centerIn: parent; name: quick.stopping ? "cross" : "power"; size: Style.iconSmall; color: quick.stopping ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.85) }
                }
            }
        }

        Grid {
            id: tiles
            visible: !quick.stopping
            columns: Style.switchColumns
            columnSpacing: Style.space(4); rowSpacing: Style.space(12)
            readonly property real cell: (width - columnSpacing * (columns - 1)) / columns
            width: parent.width

            Tile {
                width: parent.cell
                // A computer with no Wi-Fi card on a cable: the tile is the network, and a press opens Connections.
                readonly property bool cabled: quick.st.wifi === "" && quick.poll.link === "wired"
                icon: cabled ? "wired" : quick.st.wifi === "off" ? "wifiOff" : "wifi"; label: cabled ? "Network" : "Wi-Fi"
                available: quick.st.wifi !== "" || cabled
                on: cabled || quick.st.wifi === "on"
                detail: cabled ? "Wired" : quick.st.wifi === undefined ? "" : !available ? "Not available" : quick.st.wifi === "off" ? "Off" : (quick.st.ssid || "Not connected")
                more: true
                onToggled: cabled ? quick.core.network() : quick.change({ wifi: on ? "off" : "on", ssid: on ? "" : quick.st.ssid }, ["takumi", "switch", "wifi"])
                onMoreRequested: quick.core.network()
            }
            Tile {
                width: parent.cell
                icon: "bt"; label: "Bluetooth"
                available: quick.st.bt !== ""
                on: quick.st.bt === "on"
                detail: quick.st.bt === undefined ? "" : !available ? "Not available" : quick.st.bt === "off" ? "Off"
                      : (quick.st.btCount ?? 0) > 1 ? quick.st.btDevice + " and " + (quick.st.btCount - 1) + " more" : (quick.st.btDevice || "On")
                more: available
                onToggled: quick.change({ bt: on ? "off" : "on" }, ["takumi", "switch", "bluetooth"])
                onMoreRequested: quick.core.network()
            }
            Tile {
                width: parent.cell
                icon: quick.st.dnd ? "bellOff" : "bell"; label: "Do not disturb"
                on: quick.st.dnd === true
                detail: quick.st.dnd === undefined ? "" : !on ? "Off"
                      : (quick.core.noticesHeld ?? 0) > 0 ? quick.core.noticesHeld + " held" : "Urgent only"
                onToggled: quick.change({ dnd: !on }, ["takumi", "switch", "dnd"])
            }
            Tile {
                width: parent.cell
                icon: "moon"; label: "Night light"
                on: quick.st.night === true
                detail: quick.st.night === undefined ? "" : !on ? "Off" : quick.st.nightMode === "schedule" ? "Dusk to dawn" : "All day"
                more: true
                onToggled: quick.change({ night: !on, nightMode: on ? "off" : "on" }, ["takumi", "switch", "nightlight"])
                onMoreRequested: quick.core.search("night light")
            }
            Tile {
                width: parent.cell
                icon: "cup"; label: "Stay awake"
                on: !!quick.st.awake
                detail: quick.st.awake === undefined ? "" : on ? "Until " + quick.st.awake : "Off"
                more: true
                onToggled: quick.change({ awake: on ? "" : quick.inHour() }, on ? ["takumi", "power", "awake", "stop"] : ["takumi", "power", "awake", "60"])
                onMoreRequested: quick.core.search("power")
            }
            Tile {
                width: parent.cell
                icon: quick.poll.micMuted ? "micOff" : "mic"; label: "Microphone"
                on: !quick.poll.micMuted
                detail: quick.poll.micMuted ? "Muted" : quick.poll.micInUse ? "In use" : "On"
                more: true
                onToggled: { Quickshell.execDetached(["takumi", "audio", "mic", "toggle"]); pollSoon.restart(); }
                onMoreRequested: quick.core.search("microphone")
            }
            Tile {
                width: parent.cell
                icon: quick.st.profile === "power-saver" ? "leaf" : "bolt"; label: "Power mode"
                available: quick.st.profiles === undefined || quick.st.profiles.length > 0
                on: !!quick.st.profile && quick.st.profile !== "balanced"
                detail: quick.st.profiles === undefined ? "" : !available ? "Not available" : (quick.profileNames[quick.st.profile] ?? "")
                more: available
                onToggled: { const p = quick.nextProfile(); if (p) quick.change({ profile: p }, ["takumi", "power", "profile", p]); }
                onMoreRequested: quick.core.search("power")
            }
            Tile {
                width: parent.cell
                icon: "sun"; label: "Look"
                on: false
                detail: (Theme.name ? Theme.name.charAt(0).toUpperCase() + Theme.name.slice(1) : "Ion") + " · " + Theme.phase
                more: true
                onToggled: quick.core.search("theme")
                onMoreRequested: quick.core.search("theme")
            }
            // Mirroring to a projector, when more than one screen is attached.
            Tile {
                visible: (quick.st.screens ?? 1) > 1
                width: parent.cell
                icon: "display"; label: "Mirror"
                on: quick.st.mirror === "on"
                detail: on ? "This screen" : "Off"
                more: true
                onToggled: quick.change({ mirror: on ? "off" : "on" }, ["takumi", "display", "mirror", "toggle"])
                onMoreRequested: quick.core.display()
            }
        }

        Column {
            visible: !quick.stopping
            width: parent.width
            spacing: Style.tileGap
            Row {
                width: parent.width
                visible: quick.poll.volume >= 0
                spacing: Style.tileGap
                Level {
                    width: parent.width - soundMore.width - parent.spacing
                    icon: quick.poll.muted || quick.poll.volume === 0 ? "mute" : "vol"
                    iconAction: true
                    label: "Volume"
                    value: quick.poll.volume
                    detail: quick.poll.muted ? "Muted" : (quick.st.output ?? "")
                    onMoved: v => { quick.wantVolume = v; if (!levelTimer.running) levelTimer.start(); }
                    onIconClicked: { Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]); pollSoon.restart(); }
                }
                Pressable {
                    id: soundMore
                    width: Style.levelHeight; height: Style.levelHeight; radius: height / 2
                    accessibleName: "Sound outputs and app volumes"; raised: true
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: quick.core.sound()
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, Style.textDim) }
                }
            }
            Level {
                width: parent.width
                visible: (quick.st.brightness ?? -1) >= 0
                icon: "sun"
                label: "Brightness"
                value: quick.st.brightness ?? 0
                onMoved: v => { quick.wantBright = v; if (!levelTimer.running) levelTimer.start(); }
            }
        }

        // What is playing, while something has a song in it.
        NowPlaying {
            visible: !quick.stopping && player !== null
            width: parent.width
            active: quick.active
            niri: quick.niri
            core: quick.core
        }

        // The four ways to stop. The three that close your apps ask for a second press.
        Column {
            visible: quick.stopping
            width: parent.width
            spacing: Style.rowGap
            Repeater {
                model: [
                    { id: "sleep",   icon: "moon",    title: "Sleep",     detail: "Lock, then sleep; everything stays open", run: ["takumi", "power", "sleep"],   asks: false },
                    { id: "restart", icon: "restart", title: "Restart",   detail: "Close every app and start again",           run: ["takumi", "power", "restart"], asks: true },
                    { id: "off",     icon: "power",   title: "Shut down", detail: "Close every app and turn off",              run: ["takumi", "power", "off"],     asks: true },
                    { id: "logout",  icon: "logout",  title: "Log out",   detail: "Close every app and end the session",       run: ["takumi", "power", "logout"],  asks: true }
                ]
                delegate: Pressable {
                    id: way
                    required property var modelData
                    readonly property bool isArmed: quick.armed === modelData.id
                    width: parent.width; height: Style.rowHeight
                    accessibleName: modelData.title + ". " + (isArmed ? "Press again to " + modelData.title.toLowerCase() : modelData.detail)
                    activeFocusOnTab: true
                    selected: isArmed || activeFocus
                    onClicked: way.go()
                    Keys.onPressed: event => { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { way.go(); event.accepted = true; } }
                    function go() {
                        if (modelData.asks && !isArmed) { quick.armed = modelData.id; return; }
                        quick.armed = ""; quick.core.close();
                        Quickshell.execDetached(modelData.run);
                    }
                    Rectangle {
                        x: Style.space(10); anchors.verticalCenter: parent.verticalCenter
                        width: Style.iconSlot; height: width; radius: Style.slotRadius
                        color: way.isArmed ? Theme.accentTint(Style.fillSlotCurrent) : Theme.tint(0.06)
                        Icon { anchors.centerIn: parent; name: way.modelData.icon; color: way.isArmed ? Theme.accent : Theme.tint(0.72) }
                    }
                    Column {
                        x: Style.space(10) + Style.iconSlot + Style.space(12)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - Style.space(12)
                        Label { width: parent.width; text: way.modelData.title; font.pixelSize: Style.subtitle }
                        Label {
                            width: parent.width; font.pixelSize: Style.caption
                            text: way.isArmed ? "Press again to " + way.modelData.title.toLowerCase() : way.modelData.detail
                            color: way.isArmed ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.55)
                        }
                    }
                }
            }
        }

        // Capture: a screenshot, a recording (Stop while one runs), a colour, the words in an area.
        Row {
            visible: !quick.stopping
            width: parent.width
            spacing: Style.tileGap
            Repeater {
                model: [
                    { icon: "shot",  label: "Screenshot", run: ["takumi", "screen", "shot"] },
                    { icon: "video", label: quick.poll.recording ? "Stop" : "Record", run: ["takumi", "screen", "record"] },
                    { icon: "drop",  label: "Colour", run: ["takumi", "screen", "colour"] },
                    { icon: "quote", label: "Text", run: ["takumi", "screen", "text"] }
                ]
                delegate: Pressable {
                    id: cap
                    required property var modelData
                    readonly property bool stop: modelData.label === "Stop"
                    // A capsule, as the levels above it are: the panel is discs and capsules throughout.
                    // Each as wide as its word asks: "Screenshot" is longer than "Text".
                    readonly property real share: (modelData.label.length + 6) / shares
                    readonly property real shares: ["Screenshot", quick.poll.recording ? "Stop" : "Record", "Colour", "Text"].reduce((n, w) => n + w.length + 6, 0)
                    width: (parent.width - Style.tileGap * 3) * share; height: Style.space(38)
                    radius: height / 2
                    accessibleName: stop ? "Stop recording" : modelData.label; raised: true
                    activeFocusOnTab: true
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: stop ? Quickshell.execDetached(["takumi", "screen", "record", "stop"]) : quick.capture(modelData.run)
                    Keys.onPressed: event => { if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { cap.clicked(); event.accepted = true; } }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -Style.space(3); radius: parent.radius + Style.space(3)
                        color: "transparent"; border.width: 2; border.color: Theme.accentTint(0.7); visible: cap.activeFocus
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: Style.space(5)
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: cap.modelData.icon; size: Style.iconSmall; color: cap.stop ? Theme.red : Theme.withAlpha(Theme.foreground, 0.85) }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: cap.modelData.label; font.pixelSize: Style.caption; elide: Text.ElideNone; color: cap.stop ? Theme.red : Theme.withAlpha(Theme.foreground, Style.textDim) }
                    }
                }
            }
        }

    }
}
