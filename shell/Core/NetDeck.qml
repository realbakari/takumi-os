// In-Core Network & Bluetooth Deck: live Wi-Fi signal list, one-click Share QR, VPN badge, and paired
// Bluetooth devices with connect/disconnect toggles. Esc or Back returns to Quick settings.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

FocusScope {
    id: net
    required property var core
    required property var poll
    property bool active: false
    implicitWidth: Style.netWidth
    implicitHeight: Math.min(Style.coreSurface, column.implicitHeight + Style.space(32))

    property var wifiRows: []
    property var btRows: []

    onActiveChanged: if (active) { refreshAll(); Qt.callLater(() => net.forceActiveFocus()); }
    function refreshAll() {
        if (!wifiProc.running) { wifiProc.buf = []; wifiProc.running = true; }
        if (!btProc.running) { btProc.buf = []; btProc.running = true; }
    }

    Process {
        id: wifiProc
        property var buf: []
        command: ["takumi", "palette", "index", "wifi", "wifi"]
        stdout: SplitParser { onRead: line => { try { wifiProc.buf.push(JSON.parse(line)); } catch (e) {} } }
        onExited: net.wifiRows = wifiProc.buf.filter(r => String(r.id ?? "").startsWith("wifi:") && r.id !== "wifi:off" && r.id !== "wifi:hidden").slice(0, 5)
    }
    Process {
        id: btProc
        property var buf: []
        command: ["takumi", "palette", "bluetooth", "bluetooth"]
        stdout: SplitParser { onRead: line => { try { btProc.buf.push(JSON.parse(line)); } catch (e) {} } }
        onExited: net.btRows = btProc.buf.filter(r => r.kind === "Bluetooth" && r.id !== "bt:off" && r.id !== "bt:on").slice(0, 4)
    }
    Timer { id: settle; interval: 800; onTriggered: { net.refreshAll(); net.poll.refresh(); } }

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
                    onClicked: net.core.quick()
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; rotation: 180 }
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Connections"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Style.space(6)
                Pressable {
                    visible: net.poll.link === "wifi"
                    width: qrLbl.implicitWidth + Style.space(16); height: Style.space(26); radius: height / 2
                    accessibleName: "Share Wi-Fi QR code"
                    color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.accentTint(0.24) : Theme.accentTint(0.14)
                    onClicked: net.core.search("share wifi")
                    Label { id: qrLbl; anchors.centerIn: parent; text: "Share QR"; font.pixelSize: Style.caption; color: Theme.accent }
                }
                Pressable {
                    width: vpnLbl.implicitWidth + Style.space(16); height: Style.space(26); radius: height / 2
                    accessibleName: "VPN settings"
                    color: net.poll.vpn !== "" ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillHover * 2) : Theme.tint(Style.fillTile)
                    onClicked: net.core.search("vpn")
                    Label { id: vpnLbl; anchors.centerIn: parent; text: net.poll.vpn !== "" ? net.poll.vpn : "VPN"; font.pixelSize: Style.caption
                        color: net.poll.vpn !== "" ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim) }
                }
            }
        }

        // Wi-Fi networks
        Column {
            visible: net.wifiRows.length > 0
            width: parent.width; spacing: Style.space(4)
            Label { micro: true; text: "Wi-Fi" }
            Repeater {
                model: net.wifiRows
                delegate: Pressable {
                    id: wRow
                    required property var modelData
                    readonly property bool none: modelData.id === "wifi:none"   // no Wi-Fi card: a line of words, not a network
                    readonly property bool isOn: !none && String(modelData.subtitle ?? "").startsWith("Connected")
                    width: parent.width; height: Style.rowHeight
                    radius: Style.rowRadius; raised: isOn
                    accessibleName: (modelData.title ?? "") + ". " + (modelData.subtitle ?? "")
                    color: isOn ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: if (!wRow.none) net.core.search(wRow.isOn ? "share wifi" : (wRow.modelData.title ?? "wifi"))
                    Item {
                        id: sig; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter
                        width: Style.iconSmall; height: Style.iconSmall
                        SignalIcon {
                            visible: !wRow.none
                            bars: wRow.modelData.bars ?? 3; size: Style.iconSmall
                            color: wRow.isOn ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.78)
                        }
                        Icon { visible: wRow.none; name: "wired"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.78) }
                    }
                    Column {
                        anchors { left: sig.right; leftMargin: Style.space(10); right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                        Label { width: parent.width; text: wRow.modelData.title ?? ""; font.weight: wRow.isOn ? Font.DemiBold : Font.Medium }
                        Label { width: parent.width; text: wRow.modelData.subtitle ?? ""; font.pixelSize: Style.caption; dim: Style.textDim }
                    }
                }
            }
        }

        // Bluetooth devices
        Column {
            visible: net.btRows.length > 0
            width: parent.width; spacing: Style.space(4)
            Label { micro: true; text: "Bluetooth" }
            Repeater {
                model: net.btRows
                delegate: Pressable {
                    id: bRow
                    required property var modelData
                    readonly property bool isOn: String(modelData.subtitle ?? "").startsWith("Connected")
                    width: parent.width; height: Style.rowHeight
                    radius: Style.rowRadius; raised: isOn
                    accessibleName: (modelData.title ?? "") + ". " + (modelData.subtitle ?? "")
                    color: isOn ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: {
                        if (bRow.modelData.converse) net.core.search("bluetooth");
                        else if (bRow.modelData.run) { Quickshell.execDetached(bRow.modelData.run); settle.restart(); }
                    }
                    Icon {
                        id: bIc; x: Style.space(12); anchors.verticalCenter: parent.verticalCenter
                        name: bRow.modelData.glyph || "bt"; size: Style.iconSmall
                        color: bRow.isOn ? Theme.accent : Theme.withAlpha(Theme.foreground, 0.78)
                    }
                    Column {
                        anchors { left: bIc.right; leftMargin: Style.space(10); right: parent.right; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                        Label { width: parent.width; text: bRow.modelData.title ?? ""; font.weight: bRow.isOn ? Font.DemiBold : Font.Medium }
                        Label { width: parent.width; text: bRow.modelData.subtitle ?? ""; font.pixelSize: Style.caption; dim: Style.textDim }
                    }
                }
            }
        }
    }
}
