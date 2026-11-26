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
    property var niri: null
    property var core: null
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    function focusPlayer() {
        if (!niri || !player) return;
        const entry = String(player.desktopEntry ?? "").toLowerCase();
        const ident = String(player.identity ?? "").toLowerCase();
        const w = (niri.windows ?? []).find(x => {
            const aid = String(x.app_id ?? "").toLowerCase(), t = String(x.title ?? "").toLowerCase();
            return (entry && aid.includes(entry)) || (ident && (aid.includes(ident) || t.includes(ident)));
        });
        if (w) { niri.focusWindow(w.id); if (core) core.close(); }
    }
    visible: player !== null
    implicitHeight: visible ? Style.space(hasSeek ? 94 : 74) : 0
    readonly property bool hasSeek: !!card.player?.positionSupported && (card.player?.length ?? 0) > 0
    readonly property real progress: hasSeek ? Math.min(1, Math.max(0, (card.player?.position ?? 0) / (card.player?.length || 1))) : 0
    function fmtTime(sec) {
        const s = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    radius: Style.tileRadius
    color: Theme.tint(Style.fillTile)
    clip: true
    Bevel {
        radius: card.radius
        tracking: cardArea.containsMouse || seekArea.containsMouse || seekArea.pressed
        down: seekArea.pressed
        lit: !!card.player?.isPlaying
        focusX: card.width > 0 ? Math.max(0, Math.min(1, (seekArea.pressed ? card.progress : cardArea.mouseX / card.width))) : 0.5
    }

    // Subtle ambient cover bleed on the left side of the glass card (macOS Liquid Glass contextual tint).
    Image {
        anchors.fill: parent
        source: card.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(64, 64)
        asynchronous: true
        opacity: status === Image.Ready ? (Theme.mode === "light" ? 0.08 : 0.14) : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Style.enter } }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.withAlpha(Theme.surface, 0.35) }
            GradientStop { position: 0.55; color: Theme.withAlpha(Theme.surface, 0.88) }
            GradientStop { position: 1.0; color: Theme.withAlpha(Theme.surface, 0.96) }
        }
    }

    // The position is read when asked for; asking once a second moves the seek bar and timestamp.
    Timer {
        interval: 1000; repeat: true
        running: card.active && card.visible && !!card.player?.isPlaying && !!card.player?.positionSupported
        onTriggered: card.player.positionChanged()
    }

    MouseArea {
        id: cardArea
        anchors { left: parent.left; top: parent.top; right: controls.left }
        height: Style.space(72)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.focusPlayer()
    }

    Rectangle {
        id: cover
        x: Style.space(12); y: Style.space(11)
        width: Style.space(50); height: width
        radius: Style.concentric(card.radius, Style.space(6))
        color: Theme.accentTint(0.16)
        border.width: Style.hairline; border.color: Theme.tint(Style.lineHair)
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
        anchors { left: cover.right; leftMargin: Style.space(12); right: controls.left; rightMargin: Style.space(10); verticalCenter: cover.verticalCenter }
        spacing: Style.space(2)
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
        anchors { right: parent.right; rightMargin: Style.space(10); verticalCenter: cover.verticalCenter }
        spacing: Style.space(3)
        Pressable {
            width: Style.space(32); height: width; radius: width / 2
            accessibleName: "Previous"
            enabled: !!card.player?.canGoPrevious
            opacity: enabled ? 1 : 0.35
            color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.1) : "transparent"
            onClicked: card.player.previous()
            Icon { anchors.centerIn: parent; name: "prev"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
        }
        Pressable {
            width: Style.space(36); height: width; radius: width / 2
            accessibleName: card.player?.isPlaying ? "Pause" : "Play"
            enabled: !!card.player?.canTogglePlaying
            color: pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
            onClicked: card.player.togglePlaying()
            Icon { anchors.centerIn: parent; name: card.player?.isPlaying ? "pause" : "play"; size: Style.iconSmall; color: Theme.background }
        }
        Pressable {
            width: Style.space(32); height: width; radius: width / 2
            accessibleName: "Next"
            enabled: !!card.player?.canGoNext
            opacity: enabled ? 1 : 0.35
            color: pressed ? Theme.tint(Style.fillPressed) : hovered ? Theme.tint(0.1) : "transparent"
            onClicked: card.player.next()
            Icon { anchors.centerIn: parent; name: "next"; size: Style.iconSmall; color: Theme.withAlpha(Theme.foreground, 0.85) }
        }
    }

    // Interactive seek bar + tabular elapsed/total timestamps (click or drag to scrub when supported).
    Item {
        id: seekRow
        visible: card.hasSeek
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Style.space(12); rightMargin: Style.space(12); bottomMargin: Style.space(9) }
        height: Style.space(18)

        Label {
            id: posLbl
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: card.fmtTime(card.player?.position ?? 0)
            font.pixelSize: Style.caption; font.family: Style.monoFamily; dim: Style.textMicro
        }
        Label {
            id: lenLbl
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: card.fmtTime(card.player?.length ?? 0)
            font.pixelSize: Style.caption; font.family: Style.monoFamily; dim: Style.textMicro
        }
        Item {
            id: trackWrap
            anchors { left: posLbl.right; right: lenLbl.left; leftMargin: Style.space(8); rightMargin: Style.space(8); verticalCenter: parent.verticalCenter }
            height: parent.height
            Rectangle {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: seekArea.containsMouse || seekArea.pressed ? Style.space(5) : Style.space(3)
                radius: height / 2
                color: Theme.tint(0.14)
                Behavior on height { NumberAnimation { duration: Style.quick } }
                Rectangle {
                    width: parent.width * card.progress
                    height: parent.height; radius: parent.radius
                    color: Theme.accent
                    Behavior on width { enabled: !seekArea.pressed; NumberAnimation { duration: 400 } }
                }
            }
            MouseArea {
                id: seekArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !!card.player?.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function seekTo(mx) {
                    if (!card.player || !card.player.canSeek || trackWrap.width <= 0) return;
                    const frac = Math.max(0, Math.min(1, mx / trackWrap.width));
                    card.player.position = frac * (card.player.length || 0);
                }
                onPressed: mouse => seekTo(mouse.x)
                onPositionChanged: mouse => { if (pressed) seekTo(mouse.x); }
            }
        }
    }
}
