// In-Core Sound & Media Deck: output/input device switcher with Bluetooth codec badges, live per-app
// PipeWire stream sliders, and NowPlaying media controls. Esc or Back returns to Quick settings.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

FocusScope {
    id: deck
    required property var core
    required property var poll
    property var niri: null
    property bool active: false
    implicitWidth: Style.soundWidth
    implicitHeight: Math.min(Style.coreSurface, column.implicitHeight + Style.space(32))

    property var audio: ({ outputs: [], inputs: [], streams: [] })
    property int wantAppId: -1
    property int wantAppVol: -1

    onActiveChanged: if (active) { read(); Qt.callLater(() => deck.forceActiveFocus()); }
    function read() { if (!reader.running) reader.running = true; }

    Process {
        id: reader
        command: ["takumi", "audio", "state", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { deck.audio = JSON.parse(this.text); } catch (e) {}
            }
        }
    }
    Timer { id: settle; interval: 450; onTriggered: deck.read() }
    Timer {
        id: appVolTimer; interval: 60
        onTriggered: {
            if (deck.wantAppId >= 0 && deck.wantAppVol >= 0) {
                Quickshell.execDetached(["takumi", "audio", "app", String(deck.wantAppId), String(deck.wantAppVol)]);
                deck.wantAppId = -1; deck.wantAppVol = -1;
                settle.restart();
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
            core.quick(); event.accepted = true;
        } else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            core.search(event.text); event.accepted = true;
        }
    }

    Column {
        id: column
        x: Style.space(16); y: Style.space(16)
        width: parent.width - Style.space(32)
        spacing: Style.space(12)

        Item {
            width: parent.width; height: Style.space(34)
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: Style.space(10)
                Pressable {
                    width: Style.space(30); height: width; radius: width / 2
                    accessibleName: "Back to Quick settings"; raised: true
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                    onClicked: deck.core.quick()
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; rotation: 180 }
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Sound"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
            }
            Pressable {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: moreLbl.implicitWidth + Style.space(18); height: Style.space(26); radius: height / 2
                accessibleName: "All sound settings"
                color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillHover * 2) : Theme.tint(Style.fillTile)
                onClicked: deck.core.search("sound")
                Label { id: moreLbl; anchors.centerIn: parent; text: "Quality & tuning"; font.pixelSize: Style.caption; color: Theme.accent }
            }
        }

        // Outputs
        Column {
            visible: (deck.audio.outputs ?? []).length > 0
            width: parent.width; spacing: Style.space(4)
            Label { micro: true; text: "Output" }
            Repeater {
                model: (deck.audio.outputs ?? []).slice(0, 4)
                delegate: Pressable {
                    id: outDev
                    required property var modelData
                    readonly property bool isCur: !!modelData.default
                    width: parent.width; height: Style.rowHeightCompact
                    radius: Style.rowRadius; raised: isCur
                    accessibleName: (modelData.plain ?? "") + (isCur ? ", active output" : "")
                    color: isCur ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: { Quickshell.execDetached(["takumi", "audio", "output", String(modelData.id)]); settle.restart(); deck.poll.refresh(); }
                    Icon { id: outIcon; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; name: outDev.modelData.glyph || "vol"; size: Style.iconSmall
                           color: outDev.isCur ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.78) }
                    Label {
                        anchors { left: outIcon.right; leftMargin: Style.space(10); right: outMeta.left; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
                        text: outDev.modelData.plain ?? ""; font.weight: outDev.isCur ? Font.DemiBold : Font.Medium
                    }
                    Label {
                        id: outMeta
                        anchors { right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                        text: outDev.modelData.codecWords ? String(outDev.modelData.codecWords).split(" · ")[0] : (outDev.isCur ? (outDev.modelData.percent + "%") : "")
                        font.pixelSize: Style.caption; color: outDev.isCur ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textMicro)
                    }
                }
            }
        }

        // Per-app PipeWire stream sliders
        Column {
            visible: (deck.audio.streams ?? []).length > 0
            width: parent.width; spacing: Style.space(6)
            Label { micro: true; text: "App volumes" }
            Repeater {
                model: (deck.audio.streams ?? []).slice(0, 4)
                delegate: Level {
                    required property var modelData
                    width: parent.width
                    icon: modelData.muted ? "mute" : "vol"
                    iconAction: true
                    label: modelData.app ?? "App"
                    detail: modelData.app ?? "App"
                    value: modelData.percent ?? 100
                    onMoved: v => { deck.wantAppId = modelData.id; deck.wantAppVol = v; if (!appVolTimer.running) appVolTimer.start(); }
                    onIconClicked: { Quickshell.execDetached(["takumi", "audio", "app", String(modelData.id), modelData.muted ? "unmute" : "mute"]); settle.restart(); }
                }
            }
        }

        // Inputs
        Column {
            visible: (deck.audio.inputs ?? []).length > 0
            width: parent.width; spacing: Style.space(4)
            Label { micro: true; text: "Microphone" }
            Repeater {
                model: (deck.audio.inputs ?? []).slice(0, 3)
                delegate: Pressable {
                    id: inDev
                    required property var modelData
                    readonly property bool isCur: !!modelData.default
                    width: parent.width; height: Style.rowHeightCompact
                    radius: Style.rowRadius; raised: isCur
                    accessibleName: (modelData.plain ?? "") + (isCur ? ", active microphone" : "")
                    color: isCur ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: { Quickshell.execDetached(["takumi", "audio", "input", String(modelData.id)]); settle.restart(); deck.poll.refresh(); }
                    Icon { id: inIcon; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; name: inDev.modelData.muted ? "micOff" : "mic"; size: Style.iconSmall
                           color: inDev.isCur ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.78) }
                    Label {
                        anchors { left: inIcon.right; leftMargin: Style.space(10); right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                        text: inDev.modelData.plain ?? ""; font.weight: inDev.isCur ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }

        NowPlaying {
            visible: player !== null
            width: parent.width
            active: deck.active
            niri: deck.niri
            core: deck.core
        }
    }
}
