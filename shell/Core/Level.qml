// A level in Quick settings: the sound, or the screen's brightness. Drag or click along it; the wheel and
// the arrow keys step by five, Home and End go to the ends. The fill never shrinks past its icon, which is
// a button of its own where the level has one (the sound: mute). The value is written at the far end.
import QtQuick
import "../Look"
import "../Parts"

Rectangle {
    id: level
    property string icon: "vol"
    property int value: 0                 // 0..100, as the system last said
    property string detail: ""            // before the number: the output in use
    property bool iconAction: false
    property string label: ""             // what a screen reader calls it: "Volume", "Brightness"
    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: shown + "%"
    Accessible.onIncreaseAction: set(shown + 5)
    Accessible.onDecreaseAction: set(shown - 5)
    signal moved(int value)               // while you drag; the caller decides how often to act on it
    signal iconClicked()

    property int shown: value             // follows the pointer while dragging, the system otherwise
    readonly property bool dragging: area.pressed && !area.onIcon
    onValueChanged: if (!dragging) shown = value
    function set(v) { shown = Math.max(0, Math.min(100, Math.round(v))); moved(shown); }

    implicitHeight: Style.levelHeight
    radius: height / 2
    color: Theme.tint(0.07)
    Bevel { radius: parent.radius; z: 1 }
    activeFocusOnTab: true

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Right: case Qt.Key_Up: level.set(level.shown + 5); break;
        case Qt.Key_Left: case Qt.Key_Down: level.set(level.shown - 5); break;
        case Qt.Key_Home: level.set(0); break;
        case Qt.Key_End: level.set(100); break;
        default: return;
        }
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -Style.space(3)
        radius: parent.radius + Style.space(3)
        color: "transparent"; border.width: 2; border.color: Theme.accentTint(0.7)
        visible: level.activeFocus
    }

    Rectangle {
        id: fill
        width: Math.max(height, level.width * level.shown / 100)
        height: parent.height; radius: height / 2
        // The level in the accent, as the notice's segments are: a bright grey slab outshone the panel.
        color: Theme.withAlpha(Theme.accent, 0.9)
        Behavior on width { enabled: !level.dragging; NumberAnimation { duration: Style.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut } }
    }
    Icon {
        x: (level.height - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        name: level.icon; size: Style.iconSmall
        color: Theme.background
        scale: area.onIcon && area.pressed ? Style.press : 1
    }
    Row {
        anchors { right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
        spacing: Style.space(8)
        // Over the fill once it reaches this far, so it takes the fill's ink.
        readonly property color ink: fill.width > level.width - width - Style.space(20) ? Theme.background : Theme.withAlpha(Theme.foreground, Style.textDim)
        Label { text: level.detail; visible: text !== ""; font.pixelSize: Style.caption; color: parent.ink; width: Math.min(implicitWidth, level.width * 0.4) }
        Label {
            id: number
            text: level.shown + "%"; font.pixelSize: Style.caption; color: parent.ink
            horizontalAlignment: Text.AlignRight
            TextMetrics { id: widest; font: number.font; text: "100%" }
            width: widest.width
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property bool onIcon: false
        onPressed: mouse => {
            onIcon = level.iconAction && mouse.x < level.height;
            if (!onIcon) level.set(mouse.x / level.width * 100);
        }
        onPositionChanged: mouse => { if (pressed && !onIcon) level.set(mouse.x / level.width * 100); }
        onClicked: if (onIcon) level.iconClicked()
    }
    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y;
            while (Math.abs(acc) >= 120) { level.set(level.shown + (acc > 0 ? 5 : -5)); acc -= acc > 0 ? 120 : -120; }
        }
    }
}
