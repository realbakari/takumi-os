// A button on the setup screen: the accent's capsule for the way on (red while it waits for a second press
// that erases), a quiet word for the rest.
import QtQuick
import "../Look"
import "../Parts"

Pressable {
    id: button
    property string text: ""
    property bool primary: false
    property bool warn: false
    width: label.implicitWidth + Style.space(primary ? 44 : 28)
    height: Style.setupButton
    radius: height / 2
    color: primary ? (warn ? Theme.red : Theme.accent) : pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(Style.fillHover) : "transparent"
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Style.quick } }
    accessibleName: text
    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? Theme.background : Theme.withAlpha(Theme.foreground, Style.textDim)
        font.pixelSize: Style.subtitle
        font.weight: Font.DemiBold
    }
}
