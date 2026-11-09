// A button in a notice (Notice.qml): an app's own action, Copy for a one-time code, or "3 more". The accent
// for an action, a quiet tint for the count.
import QtQuick
import "../Look"
import "../Parts"

Rectangle {
    id: chip
    property string text: ""
    property bool strong: true
    signal activated()
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: chipLabel.width + Style.space(18)
    height: Style.space(26)
    radius: height / 2
    color: strong ? Theme.accentTint(chipArea.containsMouse ? 0.26 : 0.15) : Theme.tint(chipArea.containsMouse ? 0.12 : 0.07)
    Behavior on color { ColorAnimation { duration: Style.quick } }
    Accessible.role: Accessible.Button
    Accessible.name: chip.text
    Accessible.onPressAction: chip.activated()

    Label {
        id: chipLabel
        anchors.centerIn: parent
        width: Math.min(implicitWidth, Style.space(160))
        text: chip.text
        color: chip.strong ? Theme.accent : Theme.withAlpha(Theme.foreground, Style.textDim)
        font.weight: Font.DemiBold
        font.pixelSize: Style.caption
        horizontalAlignment: Text.AlignHCenter
    }
    MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.activated() }
}
