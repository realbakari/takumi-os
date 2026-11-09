// The outline of a control: one pixel, lighter along the top than the bottom, so a switch, a level or a
// field reads as raised from the surface it sits on, and as pressed in when `down` (Windows' controls are
// drawn the same way: a stroke that varies with elevation and state,
// https://learn.microsoft.com/windows/apps/design/signature-experiences/layering).
import QtQuick
import "../Look"

Canvas {
    id: bevel
    property real radius: Style.rowRadius
    property bool down: false
    property bool lit: false               // on, or the selection: the outline takes the accent
    readonly property bool light: Theme.mode === "light"
    readonly property color lightTop: lit ? Theme.accentTint(0.55) : Theme.tint(down ? (light ? 0.16 : 0.04) : (light ? 0.07 : 0.12))
    readonly property color lightLow: lit ? Theme.accentTint(0.25) : Theme.tint(down ? (light ? 0.07 : 0.10) : (light ? 0.15 : 0.035))
    anchors.fill: parent
    onLightTopChanged: requestPaint(); onLightLowChanged: requestPaint(); onRadiusChanged: requestPaint()
    onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d"), w = width, h = height, rr = Math.min(radius, h / 2, w / 2);
        ctx.reset();
        if (w < 2 || h < 2) return;
        const g = ctx.createLinearGradient(0, 0, 0, h);
        g.addColorStop(0, lightTop); g.addColorStop(Math.min(0.5, Style.space(8) / h), lightLow); g.addColorStop(1, lightLow);
        ctx.strokeStyle = g; ctx.lineWidth = Style.hairline;
        ctx.beginPath(); ctx.roundedRect(0.5, 0.5, w - 1, h - 1, rr, rr); ctx.stroke();
    }
}
