// Apps as tiles, an icon over a name. The empty Palette shows one row of the apps you open most, then
// "All apps"; typing "apps" shows every app in a grid that scrolls. The Palette's field keeps the keys:
// it moves `currentIndex` here and opens the current app on Enter (Open.qml). A click opens one too.
import QtQuick
import Quickshell
import "../Look"
import "../Look/Icons.js" as Icons
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
        readonly property string iconPath: !modelData.icon ? "" : modelData.icon.startsWith("/") ? ("file://" + modelData.icon) : Quickshell.iconPath(modelData.icon, true)
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
            // Takumi's own apps come with their squircle drawn in (lib/theme.sh). Everyone else's app keeps
            // its maker's icon, untouched, set on the same squircle: same plate, same rim, same size.
            readonly property bool plated: tile.iconPath !== "" && !Icons.isOwnApp(String(tile.modelData.icon ?? ""))
            Rectangle {
                visible: face.plated && picture.status === Image.Ready
                anchors.fill: parent; anchors.margins: parent.width * Style.platePad
                radius: parent.width * Style.plateRadius
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.surface }
                    GradientStop { position: 1; color: Theme.background }
                }
                border.width: Style.hairline; border.color: Theme.tint(0.16)
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.accentTint(0.14) }
                        GradientStop { position: 0.6; color: Theme.accentTint(0) }
                    }
                }
            }
            Image {
                id: picture
                anchors.fill: parent
                anchors.margins: face.plated ? parent.width * Style.plateInset : 0
                visible: tile.iconPath !== "" && status === Image.Ready
                source: tile.iconPath
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(width * 2, height * 2)
                cache: !tile.iconPath.startsWith("file://")
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
            wrapMode: Text.Wrap; maximumLineCount: 2; lineHeight: 1.08   // clean two-line spacing without crowding
            elide: Text.ElideRight
        }
    }
}
