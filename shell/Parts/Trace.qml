// The horizon's light running along a surface's top edge: from the middle out to both corners, then gone.
// The Core plays it each time it opens, so every surface seems to grow out of the line across the Sky.
// One short motion, no glow: it plays the same with or without a GPU, and not at all with reduced motion.
import QtQuick
import "../Look"

Item {
    id: trace
    property real radius: 0                    // the surface's corner: the light runs only along the straight part
    height: Style.space(2)
    opacity: 0
    property real spread: 0                    // 0..1 of the straight part; a fraction, as the Core is still growing

    function play() {
        run.stop();
        if (Style.reduceMotion || width <= radius * 2) return;
        run.start();
    }

    Rectangle {
        id: line
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        height: Style.hairline * 1.5
        width: Math.max(0, trace.width - trace.radius * 2) * trace.spread
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accentTint(0) }
            GradientStop { position: 0.5; color: Theme.withAlpha(Theme.accent, 0.95) }
            GradientStop { position: 1; color: Theme.accentTint(0) }
        }
    }

    // A soft bloom under the line: light spilling into the glass, fading sideways (the gradient) and
    // downward (layers of falling depth that add up near the line).
    Repeater {
        model: [3, 6, 10, 15]
        Rectangle {
            required property var modelData
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            height: Style.space(modelData)
            width: line.width * (1 - modelData / 40)
            radius: height / 2
            opacity: 0.07
            gradient: line.gradient
        }
    }
    // A bright spark riding each end of the line as it runs.
    Repeater {
        model: 2
        Rectangle {
            required property int index
            width: Style.space(34); height: Style.hairline * 2; radius: height / 2
            y: -Style.hairline * 0.25
            x: trace.width / 2 + (index === 0 ? -line.width / 2 : line.width / 2) - width / 2
            opacity: trace.spread < 1 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(200) } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.9) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    SequentialAnimation {
        id: run
        PropertyAction { target: trace; property: "spread"; value: 0 }
        PropertyAction { target: trace; property: "opacity"; value: 1 }
        NumberAnimation {
            target: trace; property: "spread"; to: 1
            duration: Style.duration(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter
        }
        NumberAnimation { target: trace; property: "opacity"; to: 0; duration: Style.duration(360); easing.type: Easing.InOutSine }
    }
}
