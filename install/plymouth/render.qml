// Draws the boot splash's images (default/plymouth/takumi/*.png) the way the shell draws the emblem:
// the tile and 匠, a line a light runs along while the computer starts, and the pieces of the password
// field for an encrypted disk. Run in a Takumi session, then copy the folder into the repository:
//   OUT=/tmp/takumi-plymouth qs -p install/plymouth/render.qml
// Colours are the ion theme at night, the theme a new computer starts with.
import QtQuick
import QtQuick.Shapes
import Quickshell

ShellRoot {
    FloatingWindow {
        id: win
        implicitWidth: 420; implicitHeight: 360
        color: "#0b0f14"
        readonly property string out: Quickshell.env("OUT") || "/tmp/takumi-plymouth"
        readonly property color accent: "#5ad7ff"
        readonly property color ink: "#0b0f14"
        readonly property int frames: 48

        Item {
            id: logo
            width: 112; height: 112
            Rectangle { anchors.fill: parent; anchors.margins: 8; radius: 27; color: win.accent }
            Text {
                anchors.centerIn: parent; anchors.verticalCenterOffset: -2
                text: "匠"; color: win.ink
                font.family: "Noto Sans CJK JP"; font.weight: Font.Black; font.pixelSize: 71
            }
        }
        Item {
            id: line
            y: 130; width: 176; height: 4
            property real t: 0
            clip: true
            Rectangle { anchors.fill: parent; radius: 2; color: "#1b2530" }
            Rectangle {
                width: 64; height: 4; radius: 2
                x: -width + (line.width + width) * line.t
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#005ad7ff" }
                    GradientStop { position: 0.5; color: win.accent }
                    GradientStop { position: 1; color: "#005ad7ff" }
                }
            }
        }
        Rectangle {
            id: entry
            y: 150; width: 280; height: 44; radius: 22
            color: "#e6111821"; border.width: 1; border.color: "#995ad7ff"
        }
        Rectangle { id: bullet; y: 210; width: 8; height: 8; radius: 4; color: "#e6d9e2ec" }
        Item {
            id: lock
            y: 230; width: 24; height: 24
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: win.accent; strokeWidth: 1.6; fillColor: "transparent"
                    capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M7 11h10a1.5 1.5 0 0 1 1.5 1.5v6A1.5 1.5 0 0 1 17 20H7a1.5 1.5 0 0 1-1.5-1.5v-6A1.5 1.5 0 0 1 7 11zM8.5 11V8a3.5 3.5 0 0 1 7 0v3" }
                }
            }
        }

        function pad(n) { return ("000" + n).slice(-4); }
        function save(item, name, next) { item.grabToImage(r => { r.saveToFile(win.out + "/" + name); next(); }); }
        function frame(i) {
            if (i > win.frames) { console.log("rendered", win.frames, "frames to", win.out); Qt.quit(); return; }
            // An ease in and out, then a rest with the line dark, so the light runs and pauses.
            const run = 34, u = Math.min(1, (i - 1) / run);
            line.t = i - 1 < run ? u * u * (3 - 2 * u) : 1;
            Qt.callLater(() => save(line, "throbber-" + pad(i) + ".png", () => frame(i + 1)));
        }
        // Started once the window is on screen: an item can only be captured from a window.
        Timer {
            interval: 1000; running: true
            onTriggered: win.save(logo, "watermark.png", () => win.save(entry, "entry.png", () => win.save(bullet, "bullet.png",
                             () => win.save(lock, "lock.png", () => win.frame(1)))))
        }
    }
}
