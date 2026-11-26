// GPU-batched optical bevel: crisp 1px perimeter border plus a top hairline catch that softly reflects
// the pointer position when hovered (restrained glass physics, zero CPU Canvas repaints).
import QtQuick
import "../Look"

Item {
    id: bevel
    property real radius: Style.rowRadius
    property bool down: false
    property bool lit: false               // on, or the selection: the outline takes the accent
    property real focusX: 0.5              // normalized 0..1 pointer X along the control
    property bool tracking: false          // pointer is over the control
    readonly property bool light: Theme.mode === "light"
    readonly property color rimColor: lit ? Theme.accentTint(down ? 0.44 : 0.32) : Theme.tint(down ? (light ? 0.16 : 0.10) : (light ? 0.13 : 0.06))
    readonly property color topColor: lit ? Theme.accentTint(down ? 0.72 : 0.56) : Theme.tint(down ? (light ? 0.10 : 0.07) : (light ? 0.09 : 0.14))
    readonly property color specColor: lit ? Theme.accentTint(down ? 0.94 : 0.84) : Theme.tint(light ? 0.20 : 0.36)
    readonly property color lowColor: Theme.tint(light ? 0.04 : 0.03)
    readonly property bool specular: tracking && Style.glow && !Style.reduceMotion
    // Effective corner radius and strictly straight horizontal span between corners (0 on circular buttons).
    readonly property real effectiveRadius: Math.min(bevel.radius, height / 2, width / 2)
    readonly property real straightSpan: Math.max(0, width - effectiveRadius * 2)
    readonly property bool hasStraightEdge: straightSpan > Style.space(6)
    anchors.fill: parent

    // Perimeter 1px hairline border (GPU Scene Graph rounded rect).
    Rectangle {
        anchors.fill: parent
        radius: bevel.effectiveRadius
        color: "transparent"
        border.width: Style.hairline
        border.color: bevel.rimColor
        Behavior on border.color { ColorAnimation { duration: Style.quick } }
    }

    // Top specular catch strictly inside the straight upper edge (never overshoots corners or circles).
    Item {
        visible: bevel.hasStraightEdge
        x: bevel.effectiveRadius
        y: 0
        width: bevel.straightSpan
        height: Style.hairline
        clip: true

        Rectangle {
            anchors.fill: parent
            opacity: bevel.specular ? 0.55 : 0.9
            Behavior on opacity { NumberAnimation { duration: Style.quick } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.15; color: bevel.topColor }
                GradientStop { position: 0.85; color: bevel.topColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Rectangle {
            visible: bevel.specular
            width: Math.max(Style.space(48), parent.width * 0.52)
            height: parent.height
            x: Math.max(0, Math.min(parent.width - width, parent.width * bevel.focusX - width / 2))
            Behavior on x { NumberAnimation { duration: Style.quick; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: bevel.specColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Subtle lower inner bounce strictly inside the straight lower edge.
    Rectangle {
        visible: bevel.hasStraightEdge
        x: bevel.effectiveRadius
        y: bevel.height - height
        width: bevel.straightSpan
        height: Style.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: bevel.lowColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
