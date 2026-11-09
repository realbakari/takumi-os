// The shadow that lifts a surface off what is under it, by elevation: 2 a control, 8 a card or the Core at
// rest, 16 the word over the Core, 32 the Core open, 128 a dialog or the setup glass. Higher is larger,
// softer and further down (the levels of Windows' layering guidance:
// https://learn.microsoft.com/windows/apps/design/signature-experiences/layering). With a GPU the shadow is
// drawn live; without one it is the same soft shape drawn once and sliced as a nine-patch, so a computer
// with no 3D still sees depth instead of a hard ring.
import QtQuick
import QtQuick.Effects
import "../Look"

Item {
    id: root
    property int level: 32
    property real radius: Style.coreOpenRadius
    property real strength: 1
    readonly property bool far: level >= 24
    readonly property real blur: Style.space(level <= 2 ? 4 : level <= 8 ? 12 : level <= 16 ? 18 : level <= 32 ? 40 : 64)
    readonly property real drop: Style.space(level <= 2 ? 1 : level <= 8 ? 3 : level <= 16 ? 6 : level <= 32 ? 14 : 26)
    readonly property real alpha: (Theme.mode === "light" ? 0.7 : 1) * strength * (level <= 2 ? 0.22 : level <= 8 ? 0.3 : level <= 32 ? 0.42 : 0.5)

    RectangularShadow {
        visible: Style.glow
        anchors.fill: parent
        radius: root.radius
        blur: root.blur
        offset.y: root.drop
        color: Qt.rgba(0, 0, 0, root.alpha)
    }
    // shadow-near.png: a 104 px square, the shape inset 24 px with a 12 px corner; shadow-far.png: 224 px,
    // inset 64 px, a 24 px corner. Their peaks are 0.55 and 0.75.
    BorderImage {
        visible: !Style.glow
        readonly property int inset: root.far ? 64 : 24
        readonly property int edge: root.far ? 88 : 36
        source: root.far ? "../Look/shadow-far.png" : "../Look/shadow-near.png"
        x: -inset; y: -inset + root.drop
        width: Math.max(edge * 2, parent.width + inset * 2); height: Math.max(edge * 2, parent.height + inset * 2)
        border { left: edge; right: edge; top: edge; bottom: edge }
        opacity: Math.min(1, root.alpha / (root.far ? 0.75 : 0.55) * 1.6)
        smooth: true
    }
}
