// Native shortcut cheat sheet inside the Core (Super+K or Super+Shift+/). Grouped by how Takumi works:
// the Core, the Strip, Harmony (Mac-style app keys), capture and system. Esc closes; typing anything opens
// the Palette with what you typed. See docs/shell.md and docs/harmony-keys.md.
import QtQuick
import "../Look"
import "../Parts"

FocusScope {
    id: sheet
    required property var core
    property bool active: false
    implicitWidth: Style.keysWidth
    implicitHeight: Math.min(Style.coreSurface, column.implicitHeight + Style.space(32))

    onActiveChanged: if (active) Qt.callLater(() => sheet.forceActiveFocus())

    readonly property var groups: [
        {
            name: "The Core",
            items: [
                { k: "Super Space", d: "Open Palette" },
                { k: "Super I", d: "Quick settings" },
                { k: "Super K", d: "Shortcut sheet" },
                { k: "Super P", d: "Clipboard history" },
                { k: "Super .", d: "Emoji & symbols" },
                { k: "Super Shift Space", d: "Act on notice" },
                { k: "Super Esc", d: "Clear notices" }
            ]
        },
        {
            name: "The Strip",
            items: [
                { k: "Super ← →", d: "Move along strip" },
                { k: "Super ↑ ↓", d: "Column or workspace" },
                { k: "Super 1…9", d: "Go to workspace" },
                { k: "Super R", d: "Cycle column width" },
                { k: "Super M", d: "Maximize column" },
                { k: "Super O", d: "Overview" },
                { k: "Super Tab", d: "Recent windows" },
                { k: "Super Ctrl ↑", d: "Float window" }
            ]
        },
        {
            name: "Harmony (every app)",
            items: [
                { k: "Super C · V · X", d: "Copy, paste, cut" },
                { k: "Super Z · Shift Z", d: "Undo, redo" },
                { k: "Super A · S · F", d: "Select all, save, find" },
                { k: "Super W · T · N", d: "Close tab, new tab, window" },
                { k: "Super Q", d: "Close window" }
            ]
        },
        {
            name: "Apps, capture & sound",
            items: [
                { k: "Super Return", d: "Terminal" },
                { k: "Super B · E", d: "Browser, Files" },
                { k: "Super Shift 3 · 4 · 5", d: "Screen, area, window shot" },
                { k: "Super Shift 6 · 7", d: "Record · Shot & mark up" },
                { k: "Super H", d: "Voice dictation" },
                { k: "Super L", d: "Lock screen" },
                { k: "Shift Mute · Alt Mute", d: "Next output · Mute mic" }
            ]
        }
    ]

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { core.close(); event.accepted = true; }
        else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            core.search(event.text);
            event.accepted = true;
        }
    }

    Column {
        id: column
        x: Style.space(18); y: Style.space(16)
        width: parent.width - Style.space(36)
        spacing: Style.space(14)

        Item {
            width: parent.width; height: Style.space(36)
            Column {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: Style.space(2)
                Label { text: "Keys"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
                Label { text: "Super works like Command in every app · Type anything to search"; font.pixelSize: Style.caption; dim: Style.textDim }
            }
            Pressable {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: searchLbl.implicitWidth + Style.space(20); height: Style.space(30); radius: height / 2
                raised: true; accessibleName: "Search all shortcuts"
                color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.11) : Theme.tint(0.06)
                onClicked: sheet.core.search("keys")
                Label { id: searchLbl; anchors.centerIn: parent; text: "Search all"; font.pixelSize: Style.caption; color: Theme.accent }
            }
        }

        Grid {
            width: parent.width
            columns: 2
            columnSpacing: Style.space(18)
            rowSpacing: Style.space(14)
            readonly property real colW: (width - columnSpacing) / 2

            Repeater {
                model: sheet.groups
                delegate: Column {
                    required property var modelData
                    width: parent.colW
                    spacing: Style.space(5)
                    Label { micro: true; text: modelData.name; color: Theme.accent }
                    Repeater {
                        model: modelData.items
                        delegate: Item {
                            required property var modelData
                            width: parent.width; height: Style.space(24)
                            Label {
                                anchors { left: parent.left; right: keyPill.left; rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
                                text: modelData.d
                                font.pixelSize: Style.caption; dim: Style.textDim
                            }
                            Rectangle {
                                id: keyPill
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: keyText.implicitWidth + Style.space(12); height: Style.space(20)
                                radius: Style.space(5)
                                color: Theme.tint(Style.fillField)
                                border.width: Style.hairline; border.color: Theme.tint(Style.lineHair)
                                Label {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.k
                                    font.family: Style.monoFamily; font.pixelSize: Style.micro; font.weight: Font.Medium
                                    color: Theme.foreground
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
