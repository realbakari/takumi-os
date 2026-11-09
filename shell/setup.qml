// Takumi's setup: the first screen on the setup disc. Five questions (the language, the keyboard, the place,
// you, the disk), then the install, the recovery code, and a restart. At a first start (a computer set up for
// someone else, or erased) the same screen asks its owner the first four and gives it to them. niri draws it
// (commands/setup/start); the takumi setup commands do the work. See docs/setup.md.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Look"
import "Parts"
import "Sky"
import "Setup"

ShellRoot {
    SetupState { id: setupState }

    PanelWindow {
        id: win
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "takumi-setup"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: Theme.background
        // Frosted glass over the sky where there is a GPU (niri blurs the glass's shape behind it).
        BackgroundEffect.blurRegion: Style.glow ? glassShape : null
        Region { id: glassShape; item: glass; radius: glass.radius }

        SkyCanvas { anchors.fill: parent }
        // Under the glass the sky darkens toward the ground, so a bright day still reads.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.withAlpha(Theme.background, 0.6) }
            }
        }

        Emblem {
            visible: glass.y > Style.emblemLock + Style.space(40)
            size: Style.emblemLock
            anchors { horizontalCenter: parent.horizontalCenter; bottom: glass.top; bottomMargin: Style.space(26) }
        }
        RectangularShadow {
            visible: Style.glow
            anchors.fill: glass
            radius: glass.radius
            blur: Style.space(48)
            offset.y: Style.space(12)
            color: Qt.rgba(0, 0, 0, Style.shadow)
        }
        Rectangle {
            id: glass
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Style.space(24)
            width: Math.min(Style.setupWidth, win.width - Style.space(48))
            height: pages.height + Style.setupPad * 2
            Behavior on height { NumberAnimation { duration: Style.morph; easing.type: Easing.OutCubic } }
            radius: Style.setupRadius
            // The sky's disc must not show through the words: glass over a blur, nearly opaque without one.
            color: Theme.withAlpha(Theme.surface, Style.glow ? Style.glassFillOpen : Style.coreFillOpen)
            border.width: Style.hairline
            border.color: Theme.tint(Style.rimMid)
            clip: true

            Item {
                id: pages
                x: Style.setupPad; y: Style.setupPad
                width: parent.width - Style.setupPad * 2
                readonly property var all: [language, keyboard, place, you, disk, installing, code, ready, failed]
                readonly property Item shown: all.find(p => p.current) ?? null
                height: shown ? shown.implicitHeight : 0

                LanguagePage { id: language; setup: setupState; onGo: setupState.page = "keyboard" }
                KeyboardPage { id: keyboard; setup: setupState; onGo: setupState.page = "place"; onGoBack: setupState.page = "language" }
                PlacePage { id: place; setup: setupState; onGo: setupState.page = "you"; onGoBack: setupState.page = "keyboard" }
                YouPage {
                    id: you; setup: setupState; onGoBack: setupState.page = "place"
                    onGo: if (setupState.firstStart) setupState.claim(you.password); else setupState.page = "disk"
                }
                DiskPage { id: disk; setup: setupState; onGoBack: setupState.page = "you"; onInstall: setupState.install(you.password) }
                InstallingPage { id: installing; setup: setupState }
                CodePage { id: code; setup: setupState; onGo: { you.clear(); setupState.page = "ready"; } }
                ReadyPage {
                    id: ready; setup: setupState
                    onShown: you.clear()
                    onGo: if (setupState.firstStart) setupState.finish(); else if (setupState.forOther) setupState.turnOff(); else setupState.restart()
                    onGoOther: if (setupState.forOther) setupState.restart(); else setupState.turnOff()
                }
                FailedPage { id: failed; setup: setupState; onGo: setupState.page = setupState.firstStart ? "you" : "disk"; onGoBack: setupState.turnOff() }
            }
        }

        // The questions as dots under the glass.
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: glass.bottom; topMargin: Style.space(22) }
            spacing: Style.space(8)
            visible: setupState.questions.indexOf(setupState.page) >= 0
            Repeater {
                model: setupState.questions
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property int at: setupState.questions.indexOf(setupState.page)
                    width: index === at ? Style.setupDot * 3 : Style.setupDot
                    height: Style.setupDot
                    radius: height / 2
                    color: index <= at ? Theme.accent : Theme.tint(0.25)
                    Behavior on width { NumberAnimation { duration: Style.morph; easing.type: Easing.OutCubic } }
                }
            }
        }
        Label {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: Style.space(24); bottomMargin: Style.space(20) }
            micro: true
            text: "Takumi " + (setupState.facts.version ?? "") + " setup"
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: Style.space(24); bottomMargin: Style.space(18) }
            spacing: Style.space(8)
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "keyboard"; size: Style.iconSmall }
            Label { anchors.verticalCenter: parent.verticalCenter; text: setupState.layoutName; dim: Style.textDim; font.pixelSize: Style.caption }
        }
    }
}
