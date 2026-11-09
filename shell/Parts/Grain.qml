// The grain of a material: a tile of fine noise over a surface at a few percent, so glass and its opaque
// fallback read as a material rather than a flat fill, and their gradients do not band (the noise layer of
// acrylic: https://learn.microsoft.com/windows/apps/design/style/acrylic). Nothing can clip an image to a
// rounded corner without a GPU, so the grain is three bands that never overlap, and each corner is a
// quarter disc of the grain's average tone (grain.png averages #808080): a canvas draws the noise itself
// darker than the tiled picture, which left a seam at every corner; a corner a few pixels wide without
// texture does not show.
import QtQuick
import "../Look"

Item {
    id: root
    property real radius: 0
    property real strength: 1
    readonly property real r: Math.floor(Math.min(radius, width / 2, height / 2))
    readonly property url tile: Qt.resolvedUrl("../Look/grain.png")
    opacity: (Theme.mode === "light" ? 0.05 : 0.06) * strength
    Image { x: 0; y: root.r; width: root.width; height: Math.max(0, root.height - root.r * 2); source: root.tile; fillMode: Image.Tile; smooth: false }
    Image { x: root.r; y: 0; width: Math.max(0, root.width - root.r * 2); height: root.r; source: root.tile; fillMode: Image.Tile; smooth: false }
    Image { x: root.r; y: root.height - root.r; width: Math.max(0, root.width - root.r * 2); height: root.r; source: root.tile; fillMode: Image.Tile; smooth: false }
    Repeater {
        model: root.r > 0 ? 4 : 0
        delegate: Canvas {
            id: corner
            required property int index
            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atLow: index >= 2
            x: atRight ? root.width - root.r : 0
            y: atLow ? root.height - root.r : 0
            width: root.r; height: root.r
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"), s = width;
                ctx.reset();
                if (s < 1) return;
                // The disc's centre is the corner square's inner corner.
                const cx = atRight ? 0 : s, cy = atLow ? 0 : s;
                ctx.fillStyle = "#808080";
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, s, 0, Math.PI * 2, false);
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
