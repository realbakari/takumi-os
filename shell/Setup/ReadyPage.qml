// Done: take the stick out and restart. The first start asks for the password once, then the desktop. For
// someone else: turn it off and hand it over with the password for now. At a first start: the desktop.
import QtQuick
import "../Look"
import "../Parts"

Page {
    id: page
    key: "ready"
    title: page.setup.firstStart ? "Welcome" : page.setup.forOther ? "Takumi is ready for its owner" : "Takumi is ready"
    detail: page.setup.firstStart ? "This computer is yours. Your desktop opens next."
          : page.setup.forOther ? "Take out the USB stick or the disc, turn the computer off, and give it to its owner with the password you chose. When it first starts it asks for that password once; then they choose their own name, password and keyboard."
          : "Take out the USB stick or the disc, then restart. When the computer starts it asks for your password once, and then you are in."
    back: ""
    next: page.setup.firstStart ? "Start" : page.setup.forOther ? "Turn off" : "Restart"
    other: page.setup.firstStart ? "" : page.setup.forOther ? "Restart" : "Turn off"
}
