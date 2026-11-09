// The recovery code, shown once: in digits to write down and as a code a phone camera keeps. Going on asks
// for its last six digits, so it was really kept. It is never written to the disk (docs/encryption.md).
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "code"
    title: "Keep your recovery code"
    detail: "If you ever forget your password, this code opens the disk instead. Write it down or take a photo of it, and keep it away from this computer: whoever has it can read the disk."
    back: ""
    readonly property string digits: page.setup.code.replace(/[^0-9]/g, "")
    readonly property var groups: page.setup.code.split("-")
    canGo: digits.length >= 6 && check.text.replace(/[^0-9]/g, "") === digits.slice(-6)
    onShown: check.input.forceActiveFocus()

    Row {
        spacing: Style.space(24)
        Rectangle {
            id: tile
            width: Style.qrTile; height: width
            radius: Style.qrRadius
            color: Theme.codePaper
            visible: page.setup.codeRows.length > 0
            Canvas {
                id: qr
                readonly property var rows: page.setup.codeRows
                readonly property int cell: rows.length ? Math.max(1, Math.floor((tile.height - Style.space(20)) / rows.length)) : 1
                anchors.centerIn: parent
                width: cell * rows.length; height: width
                onRowsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = Theme.codeInk;
                    for (let y = 0; y < rows.length; y++)
                        for (let x = 0; x < rows[y].length; x++)
                            if (rows[y][x] === "1") ctx.fillRect(x * cell, y * cell, cell, cell);
                }
            }
        }
        Grid {
            anchors.verticalCenter: parent.verticalCenter
            columns: 2
            columnSpacing: Style.space(18)
            rowSpacing: Style.space(8)
            Repeater {
                model: page.groups
                delegate: Text {
                    required property string modelData
                    text: modelData
                    color: Theme.foreground
                    font.family: Style.monoFamily
                    font.pixelSize: Style.setupCode
                    font.weight: Font.Medium
                    font.letterSpacing: Style.setupCode * 0.06
                    renderType: Text.NativeRendering
                }
            }
        }
    }
    Field {
        id: check
        width: parent.width
        mono: true
        hint: "Type its last six digits to go on"
        wrong: check.text.replace(/[^0-9]/g, "").length >= 6 && !page.canGo
        onAccepted: page.tryGo()
    }
}
