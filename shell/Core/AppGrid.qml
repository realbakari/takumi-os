// Apps as tiles, an icon over a name. The empty Palette shows one row of the apps you open most, then
// "All apps"; typing "apps" shows every app in a grid that scrolls. The Palette's field keeps the keys:
// it moves `currentIndex` here and opens the current app on Enter (Open.qml). A click opens one too.
import QtQuick
import Quickshell
import "../Look"
import "../Parts"

GridView {
    id: grid
    property var apps: []                  // rows from `takumi palette index apps`: { id, title, icon, run }
    property int columns: Style.appColumns
    property bool selecting: true          // false: no tile is current (the selection is in the list)
    property bool entering: false          // the Core just opened: tiles rise in after the field
    signal opened(var app)

    cellWidth: Math.floor(width / columns)
    cellHeight: Style.appCell
    model: apps
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: -1
    keyNavigationEnabled: false
    highlightFollowsCurrentItem: true
    highlightMoveDuration: Style.glide
    highlight: Rectangle {
        radius: Style.tileRadius
        color: Theme.accentTint(Style.fillSelected)
        visible: grid.selecting && grid.currentIndex >= 0
        border.width: Style.hairline; border.color: Theme.accentTint(Style.rimLit)
    }

    delegate: Pressable {
        id: tile
        required property var modelData
        required property int index
        readonly property bool current: grid.selecting && index === grid.currentIndex
        readonly property string iconPath: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
        width: grid.cellWidth; height: grid.cellHeight
        radius: Style.tileRadius
        accessibleName: modelData.title
        selected: false
        color: hovered && !current ? Theme.tint(Style.fillHover) : "transparent"
        onClicked: grid.opened(modelData)
        opacity: 1
        transform: Translate { id: rise }
        Component.onCompleted: if (grid.entering && !Style.reduceMotion && index < 12) { opacity = 0; rise.y = Style.space(6); appear.start(); }
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: tile.index * Style.stagger * 0.6 }
            ParallelAnimation {
                NumberAnimation { target: tile; property: "opacity"; to: 1; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
                NumberAnimation { target: rise; property: "y"; to: 0; duration: Style.enter * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
            }
        }

        Item {
            id: face
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.space(12)
            width: Style.appIcon; height: width
            scale: tile.pressed ? 0.94 : tile.current || tile.hovered ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: Style.glide; easing.type: Easing.OutCubic } }
            Image {
                id: picture
                anchors.fill: parent
                visible: tile.iconPath !== "" && status === Image.Ready
                source: tile.iconPath
                sourceSize: Qt.size(width * 2, height * 2)
                asynchronous: true
                smooth: true
            }
            // No icon (or a glyph tile such as All apps): the stroke icon on a soft square.
            Rectangle {
                anchors.fill: parent
                visible: !picture.visible
                radius: Style.slotRadius * 1.4
                color: tile.current ? Theme.accentTint(Style.fillSlotCurrent) : Theme.tint(0.07)
                border.width: Style.hairline; border.color: Theme.tint(Style.lineHair)
                Icon { anchors.centerIn: parent; name: tile.modelData.glyph ?? "apps"; size: Style.icon; color: tile.current ? Theme.accent : Theme.tint(0.78) }
            }
        }
        Label {
            anchors { top: face.bottom; topMargin: Style.space(8); horizontalCenter: parent.horizontalCenter }
            width: parent.width - Style.space(10)
            horizontalAlignment: Text.AlignHCenter
            text: tile.modelData.title ?? ""
            font.pixelSize: Style.caption
            color: tile.current ? Theme.foreground : Theme.withAlpha(Theme.foreground, Style.textDim)
            wrapMode: Text.Wrap; maximumLineCount: 2; lineHeight: 0.92   // "LibreOffice Calc" on two lines, not cut short
            elide: Text.ElideRight
        }
    }
}
