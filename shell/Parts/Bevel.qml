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
    readonly property color topColor: lit ? Theme.accentTint(down ? 0.76 : 0.62) : Theme.tint(down ? (light ? 0.10 : 0.07) : (light ? 0.09 : 0.16))
    readonly property color specColor: lit ? Theme.accentTint(down ? 0.96 : 0.85) : Theme.tint(light ? 0.20 : 0.38)
    readonly property color lowColor: Theme.tint(light ? 0.04 : 0.03)
    readonly property bool specular: tracking && Style.glow && !Style.reduceMotion
    anchors.fill: parent

    // Perimeter 1px hairline border (GPU Scene Graph rounded rect).
    Rectangle {
        anchors.fill: parent
        radius: Math.min(bevel.radius, height / 2, width / 2)
        color: "transparent"
        border.width: Style.hairline
        border.color: bevel.rimColor
        Behavior on border.color { ColorAnimation { duration: Style.quick } }
    }

    // Top specular catch along the upper edge; shifts toward pointer X while hovered or dragged.
    Item {
        readonly property real inset: Math.min(bevel.radius * 0.65, width * 0.25)
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: inset; rightMargin: inset }
        height: Style.hairline
        clip: true

        Rectangle {
            anchors.fill: parent
            color: bevel.topColor
            opacity: bevel.specular ? 0.55 : 0.9
            Behavior on opacity { NumberAnimation { duration: Style.quick } }
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

    // Subtle lower inner bounce for machined optical depth.
    Rectangle {
        readonly property real inset: Math.min(bevel.radius * 0.72, width * 0.25)
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: inset; rightMargin: inset }
        height: Style.hairline
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: bevel.lowColor }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
