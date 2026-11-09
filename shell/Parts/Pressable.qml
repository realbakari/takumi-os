// Hover and press feedback: fill from the state alphas, a slight press. The hit area counter-scales so a
// press near an edge still lands.
import QtQuick
import "../Look"

Rectangle {
    id: root
    property bool selected: false
    property bool raised: false            // a button on a surface, not a row: it gets a control's outline
    property alias hovered: area.containsMouse
    property alias pressed: area.pressed
    signal clicked()
    signal rightClicked()   // the right button: a menu, or a second action
    // What a screen reader says for it; callers give the words (a segment's hint, a row's title).
    property string accessibleName: ""
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: root.clicked()
    radius: Style.rowRadius
    color: pressed ? Theme.tint(Style.fillPressed) : selected ? Theme.accentTint(Style.fillSelected) : hovered ? Theme.tint(Style.fillHover) : "transparent"
    Behavior on color { ColorAnimation { duration: Style.quick } }
    scale: pressed ? Style.press : 1
    Behavior on scale { NumberAnimation { duration: Style.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }
    Bevel { visible: root.raised; radius: root.radius; down: root.pressed }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        scale: 1 / root.scale
        onClicked: mouse => mouse.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
