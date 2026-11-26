// Intent & Agent Cockpit: surfaces the active assistant engine/model, recent audited Intent transcript
// entries (~/.local/state/takumi/intent/transcript.jsonl), and direct setup/ask actions inside the Core.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

FocusScope {
    id: cockpit
    required property var core
    property bool active: false
    implicitWidth: Style.cockpitWidth
    implicitHeight: Math.min(Style.coreSurface, column.implicitHeight + Style.space(32))

    property string engine: ""
    property string modelName: ""
    property var entries: []

    onActiveChanged: if (active) { cfg.reload(); loadTranscript(); Qt.callLater(() => cockpit.forceActiveFocus()); }

    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/takumi/intent.toml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            const e = t.match(/^engine\s*=\s*"([^"]*)"/m);
            const m = t.match(/^model\s*=\s*"([^"]*)"/m);
            cockpit.engine = e ? e[1] : "";
            cockpit.modelName = m ? m[1] : "";
        }
    }
    function loadTranscript() { if (!reader.running) reader.running = true; }
    Process {
        id: reader
        command: ["sh", "-c", 'f="$HOME/.local/state/takumi/intent/transcript.jsonl"; [ -f "$f" ] && tail -n 6 "$f" || true']
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (!line.trim()) continue;
                    try { out.unshift(JSON.parse(line)); } catch (e) {}
                }
                cockpit.entries = out;
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { core.close(); event.accepted = true; }
        else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            core.search(event.text); event.accepted = true;
        }
    }

    Column {
        id: column
        x: Style.space(18); y: Style.space(16)
        width: parent.width - Style.space(36)
        spacing: Style.space(14)

        Item {
            width: parent.width; height: Style.space(38)
            Column {
                anchors { left: parent.left; right: cfgBtn.left; rightMargin: Style.space(10); verticalCenter: parent.verticalCenter }
                spacing: Style.space(2)
                Label { width: parent.width; text: "Intent Cockpit"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
                Label {
                    width: parent.width
                    font.pixelSize: Style.caption; dim: Style.textDim
                    text: cockpit.engine
                        ? (cockpit.engine.charAt(0).toUpperCase() + cockpit.engine.slice(1) + (cockpit.modelName ? " · " + cockpit.modelName : "") + " · Typed commands only")
                        : "Not configured · Nothing leaves this computer until you choose an engine"
                }
            }
            Pressable {
                id: cfgBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: cfgLbl.implicitWidth + Style.space(18); height: Style.space(28); radius: height / 2
                raised: true; accessibleName: "Configure assistant engine"
                color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                onClicked: cockpit.core.search("assistant")
                Label { id: cfgLbl; anchors.centerIn: parent; text: cockpit.engine ? "Switch engine" : "Set up"; font.pixelSize: Style.caption; color: Theme.accent }
            }
        }

        // Audited transcript entries
        Column {
            width: parent.width; spacing: Style.space(6)
            Label { micro: true; text: "Recent activity" }
            Label {
                visible: cockpit.entries.length === 0
                text: "No Intent actions recorded yet. Press Super+Space and type a sentence."
                font.pixelSize: Style.caption; dim: Style.textFaint
                wrapMode: Text.WordWrap; width: parent.width
            }
            Repeater {
                model: cockpit.entries
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: Style.rowHeight
                    radius: Style.rowRadius
                    color: Theme.tint(Style.fillTile)
                    Bevel { radius: parent.radius }
                    Icon { id: ic; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter; name: "quote"; size: Style.iconSmall; color: Theme.accent }
                    Column {
                        anchors { left: ic.right; leftMargin: Style.space(10); right: badge.left; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
                        spacing: Style.space(2)
                        Label { width: parent.width; text: modelData.request || modelData.prompt || "Action"; font.weight: Font.DemiBold }
                        Label {
                            width: parent.width; font.pixelSize: Style.caption; dim: Style.textDim; font.family: Style.monoFamily
                            text: Array.isArray(modelData.commands) ? modelData.commands.join(" · ") : (modelData.line || modelData.command || "")
                            visible: text !== ""
                        }
                    }
                    Label {
                        id: badge
                        anchors { right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                        micro: true
                        text: modelData.status || "Done"
                        color: modelData.status === "declined" ? Theme.yellow : modelData.status === "error" ? Theme.red : Theme.accent
                    }
                }
            }
        }

        Row {
            width: parent.width; spacing: Style.tileGap
            Repeater {
                model: [
                    { icon: "quote", label: "Ask Intent", action: "open" },
                    { icon: "shield", label: "MCP server", action: "mcp" },
                    { icon: "pulse", label: "Doctor", action: "doctor" }
                ]
                delegate: Pressable {
                    required property var modelData
                    width: (parent.width - Style.tileGap * 2) / 3; height: Style.space(42)
                    radius: Style.tileRadius; raised: true; accessibleName: modelData.label
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: {
                        if (modelData.action === "open") cockpit.core.show();
                        else cockpit.core.search(modelData.action);
                    }
                    Row {
                        anchors.centerIn: parent; spacing: Style.space(6)
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; size: Style.iconSmall; color: Theme.accent }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.pixelSize: Style.caption }
                    }
                }
            }
        }
    }
}
