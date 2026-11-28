// The steps a conversation has taken so far, above the row that says what it is doing now: a node and a
// line for each, oldest at the top, joined by one line that runs down into that row's icon. A step that is
// done has a filled node; the line's last stretch breathes while the command works. See Core/Open.qml.
import QtQuick
import "../Look"
import "../Parts"

Item {
    id: thread
    property var steps: []
    property bool live: false              // the command is working: the last stretch of the line breathes
    // The centre of a row's icon slot (ResultRow.qml), so the line meets the icon under it.
    readonly property real axis: Style.space(12) + Style.iconSlot / 2
    height: steps.length * Style.threadRow

    // The line: from the first node down past the last, into the row below.
    Rectangle {
        x: thread.axis - width / 2
        y: Style.threadRow / 2
        width: Style.hairline; height: Math.max(0, thread.height - Style.threadRow / 2)
        color: Theme.accentTint(0.38)
    }
    Rectangle {
        x: thread.axis - width / 2
        y: thread.height
        width: Style.hairline; height: Style.space(8)
        color: Theme.accentTint(0.38)
        SequentialAnimation on opacity {
            running: thread.live && thread.visible && Style.continuousMotion; loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: Style.breathe; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.2; to: 1; duration: Style.breathe; easing.type: Easing.InOutSine }
        }
    }

    Column {
        width: parent.width
        Repeater {
            model: thread.steps
            delegate: Item {
                id: step
                required property string modelData
                required property int index
                width: thread.width; height: Style.threadRow
                Accessible.role: Accessible.StaticText
                Accessible.name: "Done: " + modelData
                // A step arrives from below, where it was the row's own line a moment ago.
                opacity: 0
                transform: Translate { id: rise; y: Style.space(6) }
                Component.onCompleted: arrive.start()
                ParallelAnimation {
                    id: arrive
                    NumberAnimation { target: step; property: "opacity"; to: 1; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }
                    NumberAnimation { target: rise; property: "y"; to: 0; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeEnter }
                }
                Rectangle {
                    x: thread.axis - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.threadNode; height: width; radius: width / 2
                    color: Theme.accent
                }
                Label {
                    anchors { left: parent.left; leftMargin: Style.space(12) + Style.iconSlot + Style.space(12); right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
                    text: step.modelData
                    font.pixelSize: Style.caption; dim: Style.textDim
                }
            }
        }
    }
}
