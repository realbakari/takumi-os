// A card in the open Core, in place of the rows: a code to scan beside what it is about, and a secret
// that shows only when asked. The first card shares a Wi-Fi network (takumi wifi share --card): point a
// phone's camera at it and the phone joins. Enter shows or hides the password; Esc goes back.
import QtQuick
import "../Look"
import "../Parts"

Item {
    id: card
    property var info: null        // { kicker, title, detail, secretLabel, secret, qr: ["0101…", …], facts: [[name, value], …], copyLabel, copy }
    property bool reveal: false
    property bool copied: false    // Enter copied `copy` to the clipboard (a crash's report)
    readonly property var rows: info?.qr ?? []
    readonly property string secret: info?.secret ?? ""
    readonly property var facts: info?.facts ?? []
    onInfoChanged: copied = false
    implicitHeight: Math.max(Style.cardHeight, words.implicitHeight + Style.space(36))

    // Dark on light whatever the theme, so every phone camera reads it.
    Rectangle {
        id: tile
        visible: card.rows.length > 0
        x: Style.space(14)
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Style.qrTile : 0; height: Style.qrTile
        radius: Style.qrRadius
        color: Theme.codePaper
        Canvas {
            id: code
            readonly property int cell: card.rows.length ? Math.max(1, Math.floor((tile.height - Style.space(20)) / card.rows.length)) : 1
            anchors.centerIn: parent
            width: cell * card.rows.length; height: width
            onWidthChanged: requestPaint()
            Connections { target: card; function onRowsChanged() { code.requestPaint(); } }
            onPaint: {
                const ctx = getContext("2d"), rows = card.rows;
                ctx.reset();
                ctx.fillStyle = Theme.codeInk;
                for (let y = 0; y < rows.length; y++)
                    for (let x = 0; x < rows[y].length; x++)
                        if (rows[y][x] === "1") ctx.fillRect(x * cell, y * cell, cell, cell);
            }
        }
    }

    Column {
        id: words
        anchors {
            left: tile.right; leftMargin: tile.visible ? Style.space(22) : Style.space(18)
            right: parent.right; rightMargin: Style.space(18)
            verticalCenter: parent.verticalCenter
        }
        spacing: Style.space(6)
        Label { micro: true; text: card.info?.kicker ?? ""; color: Theme.accent; visible: text !== "" }
        Label { width: parent.width; text: card.info?.title ?? ""; font.pixelSize: Style.title; font.weight: Font.DemiBold }
        Label {
            width: parent.width; text: card.info?.detail ?? ""; dim: Style.textDim
            wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
        }
        Item { width: 1; height: Style.space(8); visible: card.secret !== "" }
        Label { micro: true; text: card.info?.secretLabel ?? ""; visible: card.secret !== "" }
        Label {
            visible: card.secret !== ""
            width: parent.width
            // Hidden, it never shows how long the password is.
            text: card.reveal ? card.secret : "••••••••••"
            font.family: Style.monoFamily; font.pixelSize: Style.subtitle; font.weight: Font.Normal
        }
        Label {
            visible: card.secret !== ""
            text: card.reveal ? "Enter hides it" : "Enter shows it"
            dim: Style.textFaint; font.pixelSize: Style.caption
        }
        // Facts, name and value in two columns (About this computer).
        Grid {
            visible: card.facts.length > 0
            columns: 2; columnSpacing: Style.space(16); rowSpacing: Style.space(4)
            topPadding: Style.space(4)
            Repeater {
                model: card.facts.length * 2
                delegate: Label {
                    required property int index
                    readonly property var fact: card.facts[Math.floor(index / 2)] ?? ["", ""]
                    text: index % 2 === 0 ? (fact[0] ?? "") : (fact[1] ?? "")
                    dim: index % 2 === 0 ? Style.textMicro : 1
                    font.pixelSize: Style.caption
                    width: index % 2 === 0 ? Style.space(96) : Math.min(implicitWidth, words.width - Style.space(112))
                }
            }
        }
        // A report to copy (why an app quit): Enter copies it.
        Rectangle {
            visible: (card.info?.copy ?? "") !== "" && card.secret === ""
            width: copyLabel.implicitWidth + Style.space(22); height: Style.space(28); radius: height / 2
            color: Theme.accentTint(card.copied ? 0.26 : 0.15)
            Label { id: copyLabel; anchors.centerIn: parent; font.weight: Font.DemiBold; font.pixelSize: Style.caption; color: Theme.accent
                text: card.copied ? "Copied" : (card.info?.copyLabel || "Copy") + " · Enter" }
        }
    }
}
