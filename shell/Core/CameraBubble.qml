// The camera as a round bubble in a corner of what is being recorded (takumi screen record --camera). One
// window on the overlay layer, as big as the screen it is on, clear, and taking input only on the bubble, so the
// windows under it keep their clicks. Drag the bubble anywhere inside the recorded area; the wheel over it, or
// + and -, makes it bigger or smaller; Esc hides it and lets the camera go. shell.qml starts and stops it over
// IPC (qs -c takumi ipc call camera show <x> <y> <width> <height> | hide), the area in the layout's coordinates,
// as slurp and niri give it. See docs/capture.md.
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import "../Look"
import "../Parts"

PanelWindow {
    id: bubble
    property bool shown: false
    property rect area: Qt.rect(0, 0, 0, 0)    // what is recorded, in this screen's own coordinates
    property real diameter: Style.space(160)
    readonly property real smallest: Style.space(88)
    readonly property real largest: Math.max(smallest, Math.min(area.width, area.height) * 0.6)

    // The area in the layout: the bubble goes to the screen holding its middle, in its bottom right corner.
    function showIn(x, y, w, h) {
        const cx = x + w / 2, cy = y + h / 2;
        const s = Quickshell.screens.find(o => cx >= o.x && cx < o.x + o.width && cy >= o.y && cy < o.y + o.height) ?? Quickshell.screens[0];
        if (!s) return;
        screen = s;
        area = Qt.rect(x - s.x, y - s.y, w, h);
        diameter = Math.max(smallest, Math.min(Style.space(240), Math.round(Math.min(w, h) * 0.24)));
        face.x = area.x + area.width - diameter - Style.space(24);
        face.y = area.y + area.height - diameter - Style.space(24);
        keepInside();
        shown = true;
    }
    function hide() { shown = false; }
    function keepInside() {
        face.x = Math.max(area.x, Math.min(face.x, area.x + area.width - diameter));
        face.y = Math.max(area.y, Math.min(face.y, area.y + area.height - diameter));
    }
    // Bigger or smaller about its middle.
    function grow(by) {
        const d = Math.max(smallest, Math.min(largest, diameter + by));
        face.x -= (d - diameter) / 2;
        face.y -= (d - diameter) / 2;
        diameter = d;
        keepInside();
    }
    // A picture just big enough for the bubble, at the camera's steadiest rate: less work for the camera and
    // for the shell than its largest picture.
    function pickFormat() {
        let best = null;
        for (const f of camera.cameraDevice.videoFormats) {
            const h = f.resolution.height;
            if (h < 360) continue;
            if (!best || h < best.resolution.height || (h === best.resolution.height && f.maxFrameRate > best.maxFrameRate)) best = f;
        }
        if (best) camera.cameraFormat = best;
    }
    Component.onCompleted: pickFormat()

    visible: shown
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "takumi-camera"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item: face }

    CaptureSession {
        camera: Camera {
            id: camera
            active: bubble.shown
            onCameraDeviceChanged: bubble.pickFormat()
            onErrorOccurred: (error, errorString) => {
                if (!bubble.shown) return;
                bubble.shown = false;
                Quickshell.execDetached(["takumi", "notice", "warn", "The camera did not start", "another app may be using it"]);
            }
        }
        videoOutput: video
    }

    Item {
        id: face
        width: bubble.diameter; height: width
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) bubble.hide();
            else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) bubble.grow(Style.space(24));
            else if (event.key === Qt.Key_Minus) bubble.grow(-Style.space(24));
            else return;
            event.accepted = true;
        }

        RectangularShadow {
            visible: Style.glow
            anchors.fill: parent
            radius: width / 2
            blur: Style.space(24)
            offset.y: Style.space(6)
            color: Qt.rgba(0, 0, 0, Style.shadow)
        }
        // Until the first picture: a quiet disc with a person in it.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.surface
            Icon { anchors.centerIn: parent; name: "person"; size: Style.space(28); color: Theme.tint(0.5) }
        }
        VideoOutput {
            id: video
            anchors.fill: parent
            // Drawn without a GPU there are no shaders to cut a circle with: a square inside the ring instead.
            anchors.margins: Style.glow ? 0 : Math.round(width * 0.147)
            fillMode: VideoOutput.PreserveAspectCrop
            // As in a mirror, the way people see themselves on a call.
            transform: Scale { origin.x: video.width / 2; xScale: -1 }
            layer.enabled: Style.glow
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: disc
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        Item {
            id: disc
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Style.space(3)
            border.color: Theme.withAlpha(Theme.codePaper, grab.containsMouse ? 1 : 0.85)
            Behavior on border.color { ColorAnimation { duration: Style.quick } }
        }
        MouseArea {
            id: grab
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: face
            drag.minimumX: bubble.area.x
            drag.maximumX: bubble.area.x + bubble.area.width - face.width
            drag.minimumY: bubble.area.y
            drag.maximumY: bubble.area.y + bubble.area.height - face.height
            onPressed: face.forceActiveFocus()
        }
        WheelHandler {
            onWheel: event => bubble.grow(event.angleDelta.y > 0 ? Style.space(16) : -Style.space(16))
        }
    }
}
