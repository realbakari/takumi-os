// Visual Theme Gallery inside the Palette: 3-column grid of 16:9 theme cards. Arrow keys or hover preview
// each theme live on the shell and Sky; Enter or click applies it with the horizon split. See docs/palette.md.
import QtQuick
import "../Look"
import "../Parts"

GridView {
    id: grid
    property var themes: []                // rows from themes provider: { id, title, subtitle, preview, swatch, keywords, run }
    property int columns: Style.themeColumns
    property bool entering: false
    signal chosen(var row)
    signal previewRequested(string slug)

    cellWidth: Math.floor(width / columns)
    cellHeight: Style.themeCellH
    model: themes
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: themes.length ? 0 : -1
    keyNavigationEnabled: false
    highlightFollowsCurrentItem: true
    highlightMoveDuration: Style.glide
    highlight: Rectangle {
        radius: Style.tileRadius
        color: Theme.accentTint(Style.fillSelected)
        visible: grid.currentIndex >= 0
        border.width: Style.hairline; border.color: Theme.accentTint(Style.rimLit)
    }

    onCurrentIndexChanged: {
        const r = themes[currentIndex];
        if (r && String(r.id).startsWith("theme:")) previewRequested(String(r.id).slice(6));
    }

    delegate: Pressable {
        id: card
        required property var modelData
        required property int index
        readonly property bool current: index === grid.currentIndex
        readonly property string slug: String(modelData.id ?? "").replace(/^theme:/, "")
        readonly property string cleanTitle: String(modelData.title ?? "").replace(/^Theme /, "")
        readonly property bool inUse: slug === Theme.name
        readonly property string previewPath: modelData.preview ?? ""
        readonly property var sw: modelData.swatch ?? []
        readonly property bool isLight: String(modelData.keywords ?? "").split(" ").includes("light")

        width: grid.cellWidth; height: grid.cellHeight
        radius: Style.tileRadius
        accessibleName: cleanTitle + (inUse ? ", in use" : "")
        selected: false
        color: hovered && !current ? Theme.tint(Style.fillHover) : "transparent"
        onClicked: grid.chosen(modelData)
        onHoveredChanged: if (hovered) grid.previewRequested(slug)

        opacity: 1
        transform: Translate { id: rise }
        Component.onCompleted: if (grid.entering && !Style.reduceMotion && index < 9) { opacity = 0; rise.y = Style.space(6); appear.start(); }
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: card.index * Style.stagger * 0.6 }
            ParallelAnimation {
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: Style.enter; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
                NumberAnimation { target: rise; property: "y"; to: 0; duration: Style.enter * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.easeOut }
            }
        }

        // 16:9 preview thumbnail (sample.png when shipped, else a painted palette mini-card).
        Rectangle {
            id: thumb
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(8) }
            height: Math.round(width * 9 / 16)
            radius: Style.slotRadius
            color: card.sw.length > 0 ? card.sw[0] : Theme.background
            border.width: Style.hairline
            border.color: card.current ? Theme.accentTint(Style.rimLit) : Theme.tint(Style.lineHair)
            clip: true

            Image {
                id: pic
                anchors.fill: parent
                anchors.margins: Style.hairline
                visible: card.previewPath !== "" && status === Image.Ready
                source: card.previewPath ? "file://" + card.previewPath : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                asynchronous: true
            }
            // Fallback mini-card when a custom theme lacks sample.png.
            Item {
                anchors.fill: parent
                visible: !pic.visible
                Rectangle {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 2; color: card.sw.length > 2 ? card.sw[2] : Theme.accent
                }
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Style.space(8) }
                    width: parent.width * 0.54; height: Style.space(12); radius: height / 2
                    color: card.sw.length > 1 ? card.sw[1] : Theme.surface
                    border.width: Style.hairline; border.color: card.sw.length > 3 ? card.sw[3] : Theme.foreground
                }
            }
            // Active theme badge in the corner of the thumbnail.
            Rectangle {
                visible: card.inUse
                anchors { right: parent.right; top: parent.top; margins: Style.space(6) }
                width: Style.space(8); height: width; radius: width / 2
                color: Theme.accent
            }
        }

        Row {
            anchors { left: thumb.left; right: thumb.right; top: thumb.bottom; topMargin: Style.space(6) }
            spacing: Style.space(4)
            Label {
                width: parent.width - modeTag.implicitWidth - parent.spacing
                text: card.cleanTitle
                font.pixelSize: Style.caption; font.weight: card.current || card.inUse ? Font.DemiBold : Font.Medium
                color: card.current ? Theme.foreground : Theme.withAlpha(Theme.foreground, 0.88)
            }
            Label {
                id: modeTag
                text: card.isLight ? "Light" : "Dark"
                font.pixelSize: Style.micro; dim: Style.textFaint
            }
        }
    }
}
