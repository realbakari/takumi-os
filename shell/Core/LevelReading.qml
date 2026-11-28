// What a level says at its far end: the output in use and the number. Level.qml draws it twice, once in
// the panel's ink and once in the fill's ink clipped to the fill.
import QtQuick
import "../Look"
import "../Parts"

Row {
    id: reading
    property color ink
    property string detail
    property int shown
    property real span                    // the whole level's width: the words sit at its far end
    x: span - width - Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)
    Label { text: reading.detail; visible: text !== ""; font.pixelSize: Style.caption; color: reading.ink; width: Math.min(implicitWidth, reading.span * 0.4) }
    Label {
        id: number
        text: reading.shown + "%"; font.pixelSize: Style.caption; color: reading.ink
        horizontalAlignment: Text.AlignRight
        TextMetrics { id: widest; font: number.font; text: "100%" }
        width: widest.width
    }
}
