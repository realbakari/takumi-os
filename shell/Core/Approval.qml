// The Core asking for your password on behalf of the system: what for, in words, and one field. Enter
// sends it, Esc says no. A wrong password shakes the field and empties it. See docs/approvals.md.
import QtQuick
import "../Look"
import "../Parts"

Item {
    id: face
    required property var approvals
    property bool reveal: false
    implicitWidth: Style.approvalWidth
    implicitHeight: body.implicitHeight + Style.space(28)
    width: implicitWidth
    height: implicitHeight

    function focusField() { secret.text = ""; reveal = false; secret.forceActiveFocus(); }
    Connections {
        target: face.approvals
        function onFailedChanged() { if (face.approvals.failed) { shake.restart(); secret.text = ""; } }
    }

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.space(14) }
        spacing: Style.space(12)

        Row {
            spacing: Style.space(12)
            Rectangle {
                width: Style.iconSlot; height: width; radius: Style.slotRadius
                color: Theme.accentTint(Style.fillSlotCurrent)
                anchors.verticalCenter: parent.verticalCenter
                Icon { anchors.centerIn: parent; name: "lock"; color: Theme.accent }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - Style.iconSlot - Style.space(12)
                Label { width: parent.width; text: face.approvals.title; font.weight: Font.DemiBold; font.pixelSize: Style.subtitle }
                Label { width: parent.width; text: face.approvals.detail; dim: Style.textDim; font.pixelSize: Style.caption; visible: text !== "" }
            }
        }

        Rectangle {
            width: parent.width; height: Style.field
            radius: Style.fieldRadius
            color: Theme.tint(Style.fillField)
            border.width: face.approvals.failed ? 1 : 0
            border.color: Theme.red
            transform: Translate { id: shakeX }

            TextInput {
                id: secret
                anchors { left: parent.left; leftMargin: Style.space(16); right: chip.left; rightMargin: Style.space(12); verticalCenter: parent.verticalCenter }
                echoMode: face.reveal || face.approvals.echo ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                readOnly: face.approvals.busy
                color: Theme.foreground
                font.family: face.reveal ? Style.monoFamily : Style.uiFamily
                font.pixelSize: Style.title; font.weight: Font.Medium
                selectionColor: Theme.accentTint(0.35)
                cursorDelegate: Rectangle { width: 2; color: Theme.accent; visible: secret.cursorVisible && !face.approvals.busy }
                clip: true
                Label {
                    anchors.fill: parent; dim: Style.textFaint; visible: !secret.text; font.pixelSize: Style.title
                    text: face.approvals.busy ? "Checking…" : face.approvals.failed ? "That was not it. Try again" : "Your password"
                }
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Return: case Qt.Key_Enter:
                        if (secret.text && !face.approvals.busy) { face.approvals.submit(secret.text); secret.text = ""; }
                        break;
                    case Qt.Key_Escape: secret.text = ""; face.approvals.cancel(); break;
                    default: return;
                    }
                    event.accepted = true;
                }
            }
            Rectangle {
                id: chip
                anchors { right: parent.right; rightMargin: Style.space(14); verticalCenter: parent.verticalCenter }
                width: chipLabel.implicitWidth + Style.space(12); height: Style.space(20)
                radius: Style.space(5); color: "transparent"
                border.width: 1; border.color: Theme.accentTint(0.45)
                Label { id: chipLabel; anchors.centerIn: parent; micro: true; font.pixelSize: Style.space(10); color: Theme.accent
                    text: face.reveal ? "Hide" : "Show" }
                MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor
                    onClicked: { face.reveal = !face.reveal; secret.forceActiveFocus(); } }
            }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 50 }
        NumberAnimation { target: shakeX; property: "x"; to: 8; duration: 70 }
        NumberAnimation { target: shakeX; property: "x"; to: -5; duration: 60 }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
    }
}
