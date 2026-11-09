// What is playing, in Quick settings: the cover, the song and who made it, back, play or pause, next,
// and how far along it is. Shown while a player has a song (MPRIS), the same player the resting Core
// shows. Clicking the words brings the player's window forward when it has one.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../Look"
import "../Parts"

Rectangle {
    id: card
    property bool active: false            // Quick settings is open: keep the progress line moving
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    visible: player !== null
    implicitHeight: visible ? Style.space(72) : 0
    radius: Style.tileRadius
    color: Theme.tint(Style.fillTile)
    clip: true
    Bevel { radius: card.radius }

    // The position is read when asked for; asking once a second moves the line.
    Timer {
        interval: 1000; repeat: true
        running: card.active && card.visible && !!card.player?.isPlaying && !!card.player?.positionSupported
        onTriggered: card.player.positionChanged()
    }

    Rectangle {
        id: cover
        x: Style.space(12); anchors.verticalCenter: parent.verticalCenter
        width: Style.space(48); height: width; radius: Style.slotRadius
        color: Theme.accentTint(0.16)
        clip: true
        Image {
            id: art
            anchors.fill: parent
            source: card.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(width * 2, height * 2)
            asynchronous: true
            visible: status === Image.Ready
        }
        Icon { anchors.centerIn: parent; visible: !art.visible; name: "headphones"; color: Theme.accent }
    }

    Column {
        anchors { left: cover.right; leftMargin: Style.space(12); right: controls.left; rightMargin: Style.space(10); verticalCenter: parent.verticalCenter }
        spacing: Style.space(3)
        Label {
            width: parent.width
            text: card.player?.trackTitle || card.player?.identity || "Playing"
            font.pixelSize: Style.body; font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Label {
            width: parent.width
            text: [card.player?.trackArtist, card.player?.identity].filter(s => s).join(" · ")
            visible: text !== ""
            font.pixelSize: Style.caption; dim: Style.textDim
            elide: Text.ElideRight
        }
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: Style.space(10); verticalCenter: parent.verticalCenter }
        spacing: Style.space(4)
        Pressable {
            width: Style.space(34); height: width; radius: width / 2
            accessibleName: "Previous"
            enabled: !!card.player?.canGoPrevious
            opacity: enabled ? 1 : 0.35
            color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.1) : "transparent"
            onClicked: card.player.previous()
            Icon { anchors.centerIn: parent; name: "prev"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
        }
        Pressable {
            width: Style.space(40); height: width; radius: width / 2
            accessibleName: card.player?.isPlaying ? "Pause" : "Play"
            enabled: !!card.player?.canTogglePlaying
            color: pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
            onClicked: card.player.togglePlaying()
            Icon { anchors.centerIn: parent; name: card.player?.isPlaying ? "pause" : "play"; size: Style.iconSmall; color: Theme.background }
        }
        Pressable {
            width: Style.space(34); height: width; radius: width / 2
            accessibleName: "Next"
            enabled: !!card.player?.canGoNext
            opacity: enabled ? 1 : 0.35
            color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.1) : "transparent"
            onClicked: card.player.next()
            Icon { anchors.centerIn: parent; name: "next"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
        }
    }

    // How far along: a hairline along the bottom edge.
    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: parent.radius; rightMargin: parent.radius }
        visible: !!card.player?.positionSupported && (card.player?.length ?? 0) > 0
        width: (parent.width - parent.radius * 2) * Math.min(1, Math.max(0, (card.player?.position ?? 0) / (card.player?.length || 1)))
        height: 2; radius: 1
        color: Theme.accent
        Behavior on width { NumberAnimation { duration: 900 } }
    }
}
