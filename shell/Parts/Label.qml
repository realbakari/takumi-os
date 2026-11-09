// The one Text the shell uses. PlainText unless a caller escapes its own markup; no window title injects markup.
// `micro: true` gives the small label used for kinds, sections and keys: 12 px, weight 600, in sentence case.
import QtQuick
import "../Look"

Text {
    property real dim: micro ? Style.textMicro : 1.0
    property bool micro: false
    color: Theme.withAlpha(Theme.foreground, dim)
    font.family: Style.uiFamily
    font.pixelSize: micro ? Style.micro : Style.body
    font.weight: micro ? Font.DemiBold : Font.Medium
    font.capitalization: Font.MixedCase
    font.letterSpacing: micro ? Style.micro * Style.microTracking : 0
    font.features: { "tnum": 1 }
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Style.retint } }
}
