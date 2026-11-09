// A part of the Core at rest you can press: a pill that lights under the pointer and gives a little when
// pressed (Parts/Pressable), its content in a row, and a word for what it is. See Core/Rest.qml.
import QtQuick
import "../Look"
import "../Parts"

Pressable {
    default property alias content: inner.data
    property string hint: ""           // the word above the Core while the pointer rests here
    accessibleName: hint
    property int pad: Style.space(10)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: inner.implicitWidth + pad * 2
    height: Style.coreHeight - Style.space(12)
    radius: height / 2
    Row { id: inner; anchors.centerIn: parent; spacing: Style.space(8) }
}
