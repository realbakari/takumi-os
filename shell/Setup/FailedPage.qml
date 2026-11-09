// The install stopped: where, in its own words, and the last lines of its log. At a first start, the owner's
// account: nothing is lost, and trying again starts over.
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "failed"
    title: page.setup.firstStart ? "Your account could not be set up" : "Takumi could not be installed"
    detail: page.setup.firstStart ? "It stopped at “" + page.setup.failure + "”. Nothing on this computer was lost. Trying again starts over."
          : "It stopped at “" + page.setup.failure + "”. The disk may be partly erased; nothing else on this computer changed. Trying again starts over."
    back: "Turn off"
    next: "Try again"
    Rectangle {
        width: parent.width
        height: log.implicitHeight + Style.space(24)
        visible: page.setup.failureLog.length > 0
        radius: Style.fieldRadius
        color: Theme.tint(Style.fillField)
        Text {
            id: log
            x: Style.space(14); y: Style.space(12)
            width: parent.width - Style.space(28)
            text: page.setup.failureLog.join("\n")
            color: Theme.withAlpha(Theme.foreground, Style.textDim)
            font.family: Style.monoFamily
            font.pixelSize: Style.caption
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
        }
    }
}
