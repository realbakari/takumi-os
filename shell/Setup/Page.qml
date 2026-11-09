// One moment of the setup screen: a title, a line under it, what to choose or type, and the ways on. Enter
// goes on and Esc goes back from anywhere on it (its fields pass both along).
import QtQuick
import "../Look"
import "../Parts"

FocusScope {
    id: page
    required property var setup
    property string key: ""
    property string title: ""
    property string detail: ""
    property string next: "Continue"
    property bool canGo: true
    property bool warn: false
    property string back: "Back"      // "" hides it
    property string other: ""         // a quiet third way (Turn off)
    readonly property bool current: setup.page === key
    default property alias content: body.data
    signal go()
    signal goBack()
    signal goOther()
    signal shown()
    function tryGo() { if (canGo && next !== "") go(); }
    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight
    visible: opacity > 0
    opacity: current ? 1 : 0
    enabled: current
    Behavior on opacity { NumberAnimation { duration: Style.enter } }
    transform: Translate {
        y: page.current ? 0 : Style.space(10)
        Behavior on y { NumberAnimation { duration: Style.slide; easing.type: Easing.OutCubic } }
    }
    onCurrentChanged: if (current) { forceActiveFocus(); shown(); }
    // The first page is current from the start, so it never changes to it.
    Component.onCompleted: if (current) Qt.callLater(() => { forceActiveFocus(); shown(); })
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) page.tryGo();
        else if (event.key === Qt.Key_Escape && page.back !== "") page.goBack();
        else return;
        event.accepted = true;
    }

    Column {
        id: column
        width: parent.width
        Label {
            width: parent.width
            text: page.title
            wrapMode: Text.WordWrap; elide: Text.ElideNone
            font.pixelSize: Style.setupTitle; font.weight: Font.Light; font.letterSpacing: -0.4
        }
        Item { width: 1; height: Style.space(10) }
        Label {
            width: parent.width
            text: page.detail
            visible: text !== ""
            wrapMode: Text.WordWrap; elide: Text.ElideNone
            dim: Style.textDim; font.pixelSize: Style.subtitle; font.weight: Font.Normal; lineHeight: 1.25
        }
        Item { width: 1; height: Style.space(24) }
        Column { id: body; width: parent.width; spacing: Style.space(12) }
        readonly property bool ways: page.back !== "" || page.next !== "" || page.other !== ""
        Item { width: 1; height: column.ways ? Style.space(28) : Style.space(4) }
        Item {
            visible: column.ways
            width: parent.width; height: Style.setupButton
            Button { visible: page.back !== ""; text: page.back; anchors.left: parent.left; onClicked: page.goBack() }
            Row {
                anchors.right: parent.right
                spacing: Style.space(8)
                Button { visible: page.other !== ""; text: page.other; onClicked: page.goOther() }
                Button { visible: page.next !== ""; text: page.next; primary: true; warn: page.warn; enabled: page.canGo; onClicked: page.go() }
            }
        }
    }
}
