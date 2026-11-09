// The emblem: 匠, takumi, the artisan, in the surface colour on a tile of the accent. One shape at every
// size: the Core's corner, the field, the lock and the login screen.
import QtQuick
import "../Look"

Item {
    id: emblem
    property int size: Style.emblemSmall
    property color tile: Theme.accent
    property color ink: Theme.background
    property int retint: Style.retint      // how long a change of colour takes
    width: size; height: size

    Rectangle {
        anchors.fill: parent
        radius: emblem.size * Style.emblemRadius
        color: emblem.tile
        Behavior on color { ColorAnimation { duration: emblem.retint } }
    }
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -emblem.size * 0.02
        text: "匠"
        color: emblem.ink
        font.family: Style.cjkFamily
        font.pixelSize: emblem.size * Style.emblemGlyph
        font.weight: Font.Black
        renderType: Text.NativeRendering
        Behavior on color { ColorAnimation { duration: emblem.retint } }
    }
}
