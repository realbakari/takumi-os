// The fourth question: whose computer this is. A name, from which the account and the computer's name come,
// and a password, typed twice. The same password opens the disk when the computer starts (docs/encryption.md).
// On the setup disc it can be for someone else: then only a password for now, which its owner types once at
// the first start, where this same page asks them (takumi setup owner).
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "you"
    readonly property bool owner: page.setup.firstStart
    readonly property bool other: !owner && page.setup.forOther
    title: owner ? "Whose computer is this?" : "Who is this computer for?"
    detail: owner && !page.setup.encrypted ? "Your name, and the password you will log in with."
          : owner ? "Your name, and a password you will type when the computer starts. It replaces the one it started with today, and locks the disk: without it, nobody can read what is on it."
          : other ? "Choose a password for now. Its owner types it once, when the computer first starts, and then picks their own name, password and keyboard."
          : "Your name, and a password you will type when the computer starts. It also locks the disk: without it, nobody can read what is on it."
    next: owner ? "Set up" : "Continue"
    readonly property alias password: pw.text
    readonly property bool tooShort: pw.text.length > 0 && pw.text.length < 6
    readonly property bool differ: again.text.length > 0 && again.text !== pw.text && (again.text.length >= pw.text.length || !pw.text.startsWith(again.text))
    canGo: (other || page.setup.account !== "") && pw.text.length >= 6 && again.text === pw.text
    function clear() { pw.text = ""; again.text = ""; pw.reveal = false; again.reveal = false; }
    function focusFirst() { (other || name.text ? pw : name).input.forceActiveFocus(); }
    onShown: focusFirst()

    // Whose it is, on the setup disc only.
    Column {
        width: parent.width
        spacing: Style.space(4)
        visible: !page.owner
        Choice {
            width: parent.width
            title: "For me"
            detail: "Set it up as yours now"
            chosen: !page.other
            onClicked: { page.setup.forOther = false; page.clear(); page.focusFirst(); }
        }
        Choice {
            width: parent.width
            title: "For someone else"
            detail: "They choose their name and password when it first starts"
            chosen: page.other
            onClicked: { page.setup.forOther = true; page.clear(); page.focusFirst(); }
        }
    }
    Field {
        id: name
        width: parent.width
        visible: !page.other
        hint: "Your name"
        onTextChanged: page.setup.name = text
        onAccepted: pw.input.forceActiveFocus()
        onEscaped: page.goBack()
    }
    Label {
        width: parent.width
        visible: !page.other
        text: page.setup.account ? "Your account: " + page.setup.account + "      This computer: " + page.setup.host : " "
        dim: Style.textMicro
        font.pixelSize: Style.caption
    }
    Field {
        id: pw
        width: parent.width
        secret: true
        hint: page.other ? "A password for now" : "Choose a password"
        wrong: page.tooShort && !pw.input.activeFocus
        onAccepted: again.input.forceActiveFocus()
        onEscaped: page.goBack()
    }
    Field {
        id: again
        width: parent.width
        secret: true
        reveal: pw.reveal
        hint: "Type it again"
        wrong: page.differ
        onAccepted: page.tryGo()
        onEscaped: page.goBack()
    }
    Label {
        width: parent.width
        wrapMode: Text.WordWrap; elide: Text.ElideNone
        text: page.differ ? "The two are not the same." : "At least six characters."
        color: page.differ || (page.tooShort && !pw.input.activeFocus) ? Theme.red : Theme.withAlpha(Theme.foreground, Style.textMicro)
        font.pixelSize: Style.caption
    }
}
