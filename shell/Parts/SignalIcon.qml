// Wi-Fi strength: the Wi-Fi mark with its unlit arcs dimmed, 1, 2 or 3 of 3.
import QtQuick
import "../Look"

Item {
    id: signal
    property int bars: 3
    property int size: Style.icon
    property color color: Theme.withAlpha(Theme.foreground, Style.textDim)
    width: size; height: size
    Icon { visible: signal.bars < 3; name: "wifi"; size: signal.size; color: Theme.withAlpha(signal.color, Style.signalOff) }
    Icon { name: signal.bars >= 3 ? "wifi" : signal.bars === 2 ? "wifi2" : "wifi1"; size: signal.size; color: signal.color }
}
