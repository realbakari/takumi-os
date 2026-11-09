// A field on the setup screen: glass, the accent's rim while you type in it, red when it is wrong, a hint
// while it is empty. A secret shows dots unless Show is pressed.
import QtQuick
import "../Look"
import "../Parts"

Rectangle {
    id: field
    property alias text: input.text
    property alias input: input
    property string hint: ""
    property bool secret: false
    property bool reveal: false
    property bool wrong: false
    property bool mono: false
    signal accepted()
    signal escaped()
    signal up()
    signal down()
    implicitHeight: Style.field
    radius: Style.fieldRadius
    color: Theme.tint(Style.fillField)
    border.width: 1
    border.color: wrong ? Theme.red : input.activeFocus ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.lineHair)
    Behavior on border.color { ColorAnimation { duration: Style.quick } }

    TextInput {
        id: input
        anchors { left: parent.left; leftMargin: Style.space(18); right: show.visible ? show.left : parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
        echoMode: field.secret && !field.reveal ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        color: Theme.foreground
        font.family: field.mono || (field.secret && field.reveal) ? Style.monoFamily : Style.uiFamily
        font.pixelSize: Style.subtitle + Style.space(2)
        font.weight: Font.Medium
        selectionColor: Theme.accentTint(0.35)
        selectedTextColor: Theme.foreground
        cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: input.cursorVisible }
        clip: true
        activeFocusOnTab: true
        Accessible.role: Accessible.EditableText
        Accessible.name: field.hint
        Accessible.passwordEdit: field.secret
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Return: case Qt.Key_Enter: field.accepted(); break;
            case Qt.Key_Escape: field.escaped(); break;
            case Qt.Key_Up: field.up(); break;
            case Qt.Key_Down: field.down(); break;
            default: return;
            }
            event.accepted = true;
        }
        Label {
            anchors.fill: parent
            text: field.hint
            dim: Style.textFaint
            visible: !input.text && !input.preeditText
            font.pixelSize: input.font.pixelSize
            font.weight: Font.Normal
        }
    }
    Label {
        id: show
        visible: field.secret
        anchors { right: parent.right; rightMargin: Style.space(16); verticalCenter: parent.verticalCenter }
        text: field.reveal ? "Hide" : "Show"
        dim: Style.textDim
        font.pixelSize: Style.caption
        font.weight: Font.DemiBold
        MouseArea { anchors.fill: parent; anchors.margins: -Style.space(8); cursorShape: Qt.PointingHandCursor; onClicked: field.reveal = !field.reveal }
    }
    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onPressed: input.forceActiveFocus() }
}
