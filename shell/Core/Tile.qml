// A switch in Quick settings, in the Core's own shapes: a disc with its icon, its name under it, and a
// line saying what it is doing. The disc fills with the accent while on, and a ring leaves it each time it
// changes. A press on the disc switches it. When it has a topic in the Palette (networks, devices, the
// night light's schedule) its words carry a small arrow: a press on the words opens that, and so does the
// right button anywhere. Space or Enter switches it from the keyboard, Down opens its topic.
import QtQuick
import "../Look"
import "../Parts"

Item {
    id: tile
    property string icon: "cmd"
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property bool more: false
    signal toggled()
    signal moreRequested()

    readonly property bool overWords: more && area.containsMouse && area.mouseY > disc.y + disc.height + Style.space(2)
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: detail
    Accessible.checkable: true
    Accessible.checked: on
    Accessible.onToggleAction: tile.toggled()
    Accessible.onPressAction: tile.toggled()
    implicitHeight: Style.switchCell
    activeFocusOnTab: available

    // Quick settings opening: the switches come in as a wave from the top left (Quick.qml sets order).
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

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { tile.toggled(); event.accepted = true; }
        else if (event.key === Qt.Key_Down && tile.more) { tile.moreRequested(); event.accepted = true; }
    }

    // It changed: a ring of the accent leaves the disc and fades, so the eye sees which one answered.
    onOnChanged: if (available && visible && opacity === 1 && !Style.reduceMotion) ripple.restart()
    Rectangle {
        id: ring
        anchors.centerIn: disc
        width: disc.width; height: width; radius: width / 2
        color: "transparent"; border.width: Style.space(1.5); border.color: Theme.accent
        opacity: 0
        ParallelAnimation {
            id: ripple
            NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.42; duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }
            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }
        }
    }

    Rectangle {
        id: disc
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.space(2)
        width: Style.switchDisc; height: width; radius: width / 2
        color: !tile.available ? Theme.tint(Style.fillTile * 0.5)
             : tile.on ? Theme.withAlpha(Theme.accent, area.pressed && !tile.overWords ? 0.78 : area.containsMouse && !tile.overWords ? 1 : 0.92)
             : Theme.tint(area.pressed && !tile.overWords ? Style.fillPressed : area.containsMouse && !tile.overWords ? Style.fillTile + Style.fillHover + 0.03 : Style.fillTile + 0.03)
        Behavior on color { ColorAnimation { duration: Style.quick } }
        scale: area.pressed && !tile.overWords ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: Style.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.spring } }
        Bevel { radius: disc.radius; down: area.pressed; lit: false; visible: tile.available && !tile.on }
        Icon {
            anchors.centerIn: parent
            name: tile.icon; size: Style.icon
            color: !tile.available ? Theme.withAlpha(Theme.foreground, 0.35) : tile.on ? Theme.background : Theme.withAlpha(Theme.foreground, 0.85)
            Behavior on color { ColorAnimation { duration: Style.quick } }
        }
        // Keyboard focus: a ring in the accent, just outside the disc.
        Rectangle {
            anchors.fill: parent; anchors.margins: -Style.space(4)
            radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.accentTint(0.7)
            visible: tile.activeFocus
        }
    }

    Column {
        id: words
        anchors { top: disc.bottom; topMargin: Style.space(7); left: parent.left; right: parent.right }
        spacing: Style.space(1)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(1)
            Label {
                id: name
                text: tile.label; font.pixelSize: Style.caption; font.weight: Font.DemiBold
                dim: !tile.available ? 0.45 : tile.overWords ? 1 : 0.92
                width: Math.min(implicitWidth, tile.width - (tile.more ? Style.space(11) : 0))
            }
            Icon {
                visible: tile.more
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron"; size: Style.space(10)
                color: Theme.withAlpha(Theme.foreground, tile.overWords ? 0.95 : Style.textFaint)
                Behavior on color { ColorAnimation { duration: Style.quick } }
            }
        }
        Label {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: tile.detail; font.pixelSize: Style.caption
            color: tile.on && tile.available ? Theme.accent : Theme.withAlpha(Theme.foreground, tile.available ? Style.textDim : 0.35)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: tile.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton || tile.overWords) { if (tile.more) tile.moreRequested(); }
            else tile.toggled();
        }
    }
}
