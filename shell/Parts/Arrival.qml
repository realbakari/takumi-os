// The login screen's first moment. The first one since the computer started opens on the boot splash's
// picture (docs/boot.md), the tile and the line on the night; then the line goes out, the tile rises onto
// the emblem above the clock as the sky comes up behind it, and the time, the date and the field follow.
// After a logout the night only fades.
import QtQuick
import "../Look"

Item {
    id: arrival
    required property Item target          // the emblem the tile lands on
    property bool fromBoot: false
    property bool ready: false              // the window is on screen
    property bool backdropReady: true       // what the night uncovers has been drawn
    property bool landed: !fromBoot         // the target may show
    property real reveal: fromBoot ? 0 : 1  // the rest of the login screen
    property bool done: false
    visible: !done

    // Where plymouth draws the splash: the 112-pixel watermark (a 96-pixel tile in it) centred across and
    // 45% of the way down, the 176 by 4 line 56% down; twice the size on a screen at least 1200 pixels tall
    // and denser than 192 dpi.
    readonly property real dpr: Screen.devicePixelRatio
    readonly property int bootScale: Screen.height * dpr >= 1200 && Screen.pixelDensity * 25.4 * dpr > 192 ? 2 : 1
    readonly property real u: bootScale / dpr

    Rectangle { id: night; anchors.fill: parent; color: Style.bootNight }
    Rectangle {
        id: line
        visible: arrival.fromBoot
        width: 176 * arrival.u; height: 4 * arrival.u; radius: height / 2
        x: (arrival.width - width) / 2
        y: (arrival.height - height) * 0.56
        color: Style.bootLine
    }
    Emblem {
        id: flyer
        visible: arrival.fromBoot
        size: Math.round(96 * arrival.u)
        x: (arrival.width - 112 * arrival.u) / 2 + 8 * arrival.u
        y: (arrival.height - 112 * arrival.u) * 0.45 + 8 * arrival.u
        transformOrigin: Item.TopLeft
        tile: Style.bootAccent
        ink: Style.bootNight
        retint: Style.arrive
    }

    property real toX: 0
    property real toY: 0
    property real toScale: 1
    property bool started: false
    function go() {
        if (started || !ready) return;
        started = true;
        fromBoot ? beat.start() : fade.start();
    }
    onReadyChanged: if (ready) { backdropReady ? go() : patience.start(); }
    onBackdropReadyChanged: if (backdropReady) go()
    Timer { id: patience; interval: 2000; onTriggered: arrival.go() }   // a slow sky does not hold the login
    Timer {
        id: beat
        interval: Style.duration(260)       // the splash holds a moment, so the rise reads as the start
        onTriggered: {
            const p = arrival.target.mapToItem(arrival, 0, 0);
            arrival.toX = p.x; arrival.toY = p.y; arrival.toScale = arrival.target.width / flyer.width;
            flyer.tile = Theme.accent; flyer.ink = Theme.background;
            rise.start();
        }
    }

    SequentialAnimation {
        id: rise
        ParallelAnimation {
            NumberAnimation { target: line; property: "opacity"; to: 0; duration: Style.duration(180) }
            NumberAnimation { target: flyer; property: "x"; to: arrival.toX; duration: Style.arrive; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyer; property: "y"; to: arrival.toY; duration: Style.arrive; easing.type: Easing.InOutCubic }
            NumberAnimation { target: flyer; property: "scale"; to: arrival.toScale; duration: Style.arrive; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Style.duration(160) }
                NumberAnimation { target: night; property: "opacity"; to: 0; duration: Style.duration(700); easing.type: Easing.OutCubic }
            }
            // The time and the field come once the tile has cleared them.
            SequentialAnimation {
                PauseAnimation { duration: Style.duration(560) }
                NumberAnimation { target: arrival; property: "reveal"; to: 1; duration: Style.duration(480); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: arrival.landed = true }
        NumberAnimation { target: flyer; property: "opacity"; to: 0; duration: Style.quick }
        ScriptAction { script: arrival.done = true }
    }
    SequentialAnimation {
        id: fade
        PauseAnimation { duration: Style.duration(80) }
        NumberAnimation { target: night; property: "opacity"; to: 0; duration: Style.duration(420); easing.type: Easing.OutCubic }
        ScriptAction { script: arrival.done = true }
    }
}
