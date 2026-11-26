// Visual Emoji Grid inside the Palette: shown for ":" or "emoji" searches. Arrow keys move in 2D;
// Enter or click types the emoji where you were and copies it. See docs/palette.md.
import QtQuick
import "../Look"
import "../Parts"

GridView {
    id: grid
    property var items: []                 // rows from emoji provider: { id, title, char, run }
    property int columns: Style.emojiColumns
    signal chosen(var row)

    cellWidth: Math.floor(width / columns)
    cellHeight: Style.emojiCell
    model: items
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: items.length ? 0 : -1
    keyNavigationEnabled: false
    highlightFollowsCurrentItem: true
    highlightMoveDuration: Style.glide
    highlight: Rectangle {
        radius: Style.rowRadius
        color: Theme.accentTint(Style.fillSelected)
        visible: grid.currentIndex >= 0
        border.width: Style.hairline; border.color: Theme.accentTint(Style.rimLit)
    }

    delegate: Pressable {
        id: cell
        required property var modelData
        required property int index
        readonly property bool current: index === grid.currentIndex
        width: grid.cellWidth; height: grid.cellHeight
        radius: Style.rowRadius
        accessibleName: modelData.title ?? ""
        selected: false
        color: hovered && !current ? Theme.tint(Style.fillHover) : "transparent"
        onClicked: grid.chosen(modelData)

        Label {
            anchors.centerIn: parent
            text: cell.modelData.char ?? ""
            font.pixelSize: Style.emojiGlyph
            elide: Text.ElideNone
            scale: cell.pressed ? 0.9 : cell.current || cell.hovered ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: Style.quick; easing.type: Easing.OutCubic } }
        }
    }
}
