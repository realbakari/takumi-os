// The install, in the words takumi setup install sends: what it is doing and how far it is. At a first start,
// the owner's account being made (takumi setup owner apply), in the same words.
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "installing"
    title: page.setup.firstStart ? "Setting up your account" : "Installing Takumi"
    detail: page.setup.stepText
    back: ""
    next: ""
    Item {
        width: parent.width
        height: Style.setupBar
        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.tint(0.1) }
        Rectangle {
            width: Math.max(height, parent.width * page.setup.progress / 100)
            height: parent.height
            radius: height / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Style.slide; easing.type: Easing.OutCubic } }
        }
    }
    Item {
        width: parent.width
        height: Style.space(20)
        Label { anchors.left: parent.left; text: page.setup.firstStart ? "Keep the computer on. It takes a moment." : "Keep the computer on. It takes a few minutes."; dim: Style.textDim; font.weight: Font.Normal }
        Label { anchors.right: parent.right; text: page.setup.progress + "%"; dim: Style.textDim }
    }
}
