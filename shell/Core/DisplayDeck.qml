// Spatial Display Studio inside the Core: shows scaled interactive monitor rectangles positioned from
// niri's live layout, with inline scale, rotate, refresh-rate, arrangement and mirror controls backed by
// `takumi display`. Esc or Back returns to Quick settings. See docs/display.md.
import QtQuick
import Quickshell
import Quickshell.Io
import "../Look"
import "../Parts"

FocusScope {
    id: studio
    required property var core
    property bool active: false
    implicitWidth: Style.displayWidth
    implicitHeight: Math.min(Style.coreSurface, column.implicitHeight + Style.space(32))

    property var outputs: []
    property int selectedIndex: 0
    readonly property var selectedOut: outputs[selectedIndex] ?? outputs[0] ?? null

    onActiveChanged: if (active) { read(); Qt.callLater(() => studio.forceActiveFocus()); }
    function read() { if (!reader.running) reader.running = true; }

    Process {
        id: reader
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(this.text);
                    const list = Object.values(raw).filter(o => o && o.logical).map(o => {
                        const mode = (o.modes ?? [])[o.current_mode ?? 0] ?? null;
                        return {
                            name: o.name ?? "",
                            label: String(o.name ?? "").startsWith("eDP") ? "Built-in" : (o.model || o.name || "Display"),
                            x: o.logical.x ?? 0, y: o.logical.y ?? 0,
                            w: o.logical.width ?? 1920, h: o.logical.height ?? 1080,
                            scale: Math.round((o.logical.scale ?? 1) * 100),
                            hz: mode ? Math.round((mode.refresh_rate ?? 60000) / 1000) : 60
                        };
                    }).sort((a, b) => (a.name.startsWith("eDP") ? -1 : 1) - (b.name.startsWith("eDP") ? -1 : 1) || a.x - b.x);
                    studio.outputs = list;
                    if (studio.selectedIndex >= list.length) studio.selectedIndex = 0;
                } catch (e) {}
            }
        }
    }
    Timer { id: settle; interval: 450; onTriggered: studio.read() }

    readonly property var bounds: {
        if (!outputs.length) return { minX: 0, minY: 0, spanX: 1920, spanY: 1080 };
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
        for (const o of outputs) {
            minX = Math.min(minX, o.x); minY = Math.min(minY, o.y);
            maxX = Math.max(maxX, o.x + o.w); maxY = Math.max(maxY, o.y + o.h);
        }
        return { minX: minX, minY: minY, spanX: Math.max(1, maxX - minX), spanY: Math.max(1, maxY - minY) };
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) { core.quick(); event.accepted = true; }
        else if (event.key === Qt.Key_Left && outputs.length > 1) { selectedIndex = (selectedIndex + outputs.length - 1) % outputs.length; event.accepted = true; }
        else if (event.key === Qt.Key_Right && outputs.length > 1) { selectedIndex = (selectedIndex + 1) % outputs.length; event.accepted = true; }
        else if (event.text.length === 1 && event.text > " " && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
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
                    onClicked: studio.core.quick()
                    Icon { anchors.centerIn: parent; name: "chevron"; size: Style.iconSmall; rotation: 180 }
                }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Displays"; font.pixelSize: Style.heading; font.weight: Font.DemiBold }
            }
            Pressable {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: moreLbl.implicitWidth + Style.space(18); height: Style.space(26); radius: height / 2
                accessibleName: "All display settings"
                color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillHover * 2) : Theme.tint(Style.fillTile)
                onClicked: studio.core.search("display")
                Label { id: moreLbl; anchors.centerIn: parent; text: "Resolutions"; font.pixelSize: Style.caption; color: Theme.accent }
            }
        }

        // Spatial scaled monitor canvas
        Rectangle {
            id: stage
            width: parent.width; height: Style.canvasHeight
            radius: Style.tileRadius
            color: Theme.tint(Style.fillField)
            Bevel { radius: parent.radius; down: true }

            readonly property real pad: Style.space(16)
            readonly property real fit: Math.min((width - pad * 2) / studio.bounds.spanX, (height - pad * 2) / studio.bounds.spanY)
            readonly property real drawW: studio.bounds.spanX * fit
            readonly property real drawH: studio.bounds.spanY * fit
            readonly property real offX: (width - drawW) / 2
            readonly property real offY: (height - drawH) / 2

            Repeater {
                model: studio.outputs
                delegate: Pressable {
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === studio.selectedIndex
                    x: stage.offX + (modelData.x - studio.bounds.minX) * stage.fit
                    y: stage.offY + (modelData.y - studio.bounds.minY) * stage.fit
                    width: Math.max(Style.space(64), modelData.w * stage.fit)
                    height: Math.max(Style.space(42), modelData.h * stage.fit)
                    radius: Style.slotRadius
                    raised: true
                    accessibleName: modelData.label + ", " + modelData.scale + "%"
                    color: cur ? Theme.accentTint(Style.fillTileOn) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                    onClicked: studio.selectedIndex = index
                    Column {
                        anchors.centerIn: parent; spacing: Style.space(2)
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.pixelSize: Style.caption; font.weight: Font.DemiBold; color: cur ? Theme.accent : Theme.foreground }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.scale + "% · " + modelData.hz + " Hz"; font.pixelSize: Style.micro; dim: Style.textDim }
                    }
                }
            }
        }

        // Scale presets for the selected monitor
        Column {
            visible: studio.selectedOut !== null
            width: parent.width; spacing: Style.space(6)
            Label { micro: true; text: studio.selectedOut ? ("Scale · " + studio.selectedOut.label) : "Scale" }
            Row {
                width: parent.width; spacing: Style.space(6)
                Repeater {
                    model: [100, 125, 150, 175, 200]
                    delegate: Pressable {
                        required property int modelData
                        readonly property bool activeScale: studio.selectedOut && studio.selectedOut.scale === modelData
                        width: (parent.width - Style.space(6) * 4) / 5; height: Style.space(32); radius: Style.rowRadius; raised: activeScale
                        accessibleName: "Scale " + modelData + "%"
                        color: activeScale ? Theme.accentTint(Style.fillTileOn) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                        onClicked: {
                            if (!studio.selectedOut) return;
                            Quickshell.execDetached(["niri", "msg", "output", studio.selectedOut.name, "scale", String(modelData / 100)]);
                            settle.restart();
                        }
                        Label { anchors.centerIn: parent; text: modelData + "%"; font.pixelSize: Style.caption; color: activeScale ? Theme.accent : Theme.foreground }
                    }
                }
            }
        }

        // Arrange second monitor spatially (when 2+ monitors are active)
        Column {
            visible: studio.outputs.length > 1
            width: parent.width; spacing: Style.space(6)
            Label { micro: true; text: "Arrangement" }
            Row {
                width: parent.width; spacing: Style.space(6)
                Repeater {
                    model: [
                        { id: "left", label: "Left" },
                        { id: "right", label: "Right" },
                        { id: "above", label: "Above" },
                        { id: "below", label: "Below" }
                    ]
                    delegate: Pressable {
                        required property var modelData
                        width: (parent.width - Style.space(6) * 3) / 4; height: Style.space(32); radius: Style.rowRadius; raised: true
                        accessibleName: "Place second screen " + modelData.label
                        color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillTile + Style.fillHover) : Theme.tint(Style.fillTile)
                        onClicked: { studio.core.search("arrange " + modelData.id); }
                        Label { anchors.centerIn: parent; text: modelData.label; font.pixelSize: Style.caption }
                    }
                }
            }
        }
    }
}
