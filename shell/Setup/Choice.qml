// One choice in a setup list: what it is, a quieter word beside it, and a check on the chosen one. The row
// the arrow keys rest on has the hover's fill.
import QtQuick
import "../Look"
import "../Parts"

Pressable {
    id: row
    property string title: ""
    property string detail: ""
    property string tag: ""
    property bool chosen: false
    property bool lit: false
    width: ListView.view ? ListView.view.width : implicitWidth
    height: Style.rowHeight
    selected: chosen
    color: pressed ? Theme.tint(Style.fillPressed) : chosen ? Theme.accentTint(Style.fillSelected) : (hovered || lit) ? Theme.tint(Style.fillHover * 1.6) : "transparent"
    accessibleName: detail ? title + ", " + detail : title
    Row {
        anchors { left: parent.left; leftMargin: Style.space(16); right: marks.left; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
        spacing: Style.space(10)
        Label { id: name; text: row.title; font.pixelSize: Style.subtitle; width: Math.min(implicitWidth, parent.width) }
        Label { text: row.detail; dim: Style.textDim; font.pixelSize: Style.body; font.weight: Font.Normal; visible: text !== ""; width: Math.max(0, Math.min(implicitWidth, parent.width - name.width - parent.spacing)) }
    }
    Row {
        id: marks
        anchors { right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
        spacing: Style.space(10)
        Label { anchors.verticalCenter: parent.verticalCenter; text: row.tag; micro: true; visible: text !== "" }
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "check"; size: Style.iconSmall; color: Theme.accent; visible: row.chosen }
    }
}
