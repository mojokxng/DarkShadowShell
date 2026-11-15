import Quickshell
import QtQuick

// Brings a layer window back after the compositor closed it.
// niri closes every layer surface of an output that goes away (swayidle's `niri msg output DP-1 off`, a cable,
// a monitor that sleeps). Quickshell then marks the window invisible for good (ProxyWindowBase::onVisibleChanged
// sets visible = false and emits closed()), and moving it to another screen later only re-shows windows that are
// still visible. So a window that should always be there (the dock's edge strip, the desktop right-click catcher)
// stayed gone until the shell restarted. Windows made per screen by a Variants do not need this: theirs are made anew.
// Use: Revive { id: rv; win: myWindow }  and  visible: rv.alive && (...)
QtObject {
    id: rv
    property var win: null
    property bool alive: true
    // a moment later, and only once there is a monitor to put it on (Mon.screen moved it to one that is left)
    function retry() { if (!alive && Quickshell.screens.length > 0) back.restart() }
    property Timer back: Timer { interval: 800; onTriggered: rv.alive = true }
    property Connections winWatch: Connections {
        target: rv.win
        function onClosed() { rv.alive = false; rv.retry() }
    }
    property Connections screensWatch: Connections {
        target: Quickshell
        function onScreensChanged() { rv.retry() }
    }
}
