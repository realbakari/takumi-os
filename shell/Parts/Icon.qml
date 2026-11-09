// A stroke icon from Look/Icons.js, drawn on its 24 grid and scaled to `size`.
import QtQuick
import QtQuick.Shapes
import "../Look"
import "../Look/Icons.js" as Icons

Item {
    id: icon
    property string name: "cmd"
    property int size: Style.icon
    property color color: Theme.withAlpha(Theme.foreground, Style.textDim)
    width: size; height: size

    Shape {
        width: 24; height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Icons.path(icon.name) }
        }
    }
}
