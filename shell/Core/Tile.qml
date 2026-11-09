// A switch in Quick settings: an icon in a round field, a name, and a line saying what it is doing, lit in
// the accent while on. A press switches it. When it has a topic in the Palette (networks, devices, the
// night light's schedule) an arrow at its end opens that, and so does the right button. Space or Enter
// switches it from the keyboard, Right opens its topic.
import QtQuick
import "../Look"
import "../Parts"

Rectangle {
    id: tile
    property string icon: "cmd"
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property bool more: false
    signal toggled()
    signal moreRequested()

    readonly property bool overArrow: more && area.containsMouse && area.mouseX > width - Style.space(40)
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: detail
    Accessible.checkable: true
    Accessible.checked: on
    Accessible.onToggleAction: tile.toggled()
    Accessible.onPressAction: tile.toggled()
    implicitHeight: Style.tileHeight
    radius: Style.tileRadius
    activeFocusOnTab: available
    color: !available ? Theme.tint(Style.fillTile * 0.5)
         : on ? Theme.accentTint(Style.fillTileOn + (area.pressed ? 0.09 : area.containsMouse ? 0.04 : 0))
         : Theme.tint(area.pressed ? Style.fillPressed : area.containsMouse ? Style.fillTile + Style.fillHover : Style.fillTile)
    Behavior on color { ColorAnimation { duration: Style.quick } }
    // Quick settings opening: the tiles come in as a wave from the top left (Quick.qml sets order).
    property int order: 0
    transform: Translate { id: rise }
    function arrive() {
        appear.stop();
        if (Style.reduceMotion) { opacity = 1; rise.y = 0; return; }
        opacity = 0; rise.y = Style.space(10); appear.start();
    }
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: tile.order * Style.stagger }
        ParallelAnimation {
            NumberAnimation { target: tile; property: "opacity"; to: 1; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
            NumberAnimation { target: rise; property: "y"; to: 0; duration: Style.enter * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
        }
    }
    scale: area.pressed ? Style.press : 1
    Behavior on scale { NumberAnimation { duration: Style.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { tile.toggled(); event.accepted = true; }
        else if (event.key === Qt.Key_Right && tile.more) { tile.moreRequested(); event.accepted = true; }
    }

    Bevel { radius: tile.radius; down: area.pressed; lit: tile.on && tile.available; visible: tile.available }

    // Keyboard focus: a ring in the accent, just outside the tile.
    Rectangle {
        anchors.fill: parent; anchors.margins: -Style.space(3)
        radius: parent.radius + Style.space(3)
        color: "transparent"; border.width: 2; border.color: Theme.accentTint(0.7)
        visible: tile.activeFocus
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: tile.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        scale: 1 / tile.scale
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton || tile.overArrow) { if (tile.more) tile.moreRequested(); }
            else tile.toggled();
        }
    }

    Rectangle {
        id: disc
        x: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        // The icon stands bare: on is said once, by the tile's tint and the icon in the accent.
        width: Style.iconDisc; height: width
        color: "transparent"
        Icon {
            anchors.centerIn: parent
            name: tile.icon; size: Style.icon
            color: tile.on && tile.available ? Theme.accent : Theme.withAlpha(Theme.foreground, tile.available ? 0.82 : 0.35)
            Behavior on color { ColorAnimation { duration: Style.quick } }
        }
    }
    Column {
        anchors { left: disc.right; leftMargin: Style.space(11); right: arrow.left; rightMargin: Style.space(4); verticalCenter: parent.verticalCenter }
        spacing: Style.space(2)
        Label { width: parent.width; text: tile.label; font.weight: Font.DemiBold; dim: tile.available ? 1 : 0.45 }
        Label { width: parent.width; text: tile.detail; font.pixelSize: Style.caption; dim: tile.available ? Style.textDim : 0.35; visible: text !== "" }
    }
    Icon {
        id: arrow
        anchors { right: parent.right; rightMargin: tile.more ? Style.space(10) : 0; verticalCenter: parent.verticalCenter }
        visible: tile.more
        width: tile.more ? size : 0
        name: "chevron"; size: Style.iconSmall
        // Only where the pointer is: seven resting arrows say nothing a right click does not.
        color: Theme.withAlpha(Theme.foreground, tile.overArrow ? 0.95 : area.containsMouse || tile.activeFocus ? 0.4 : 0)
        Behavior on color { ColorAnimation { duration: Style.quick } }
    }
}
