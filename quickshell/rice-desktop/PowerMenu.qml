import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// The power menu: click the power icon on the bar and it drops down under it.
// Lock, Sleep, Log out, Restart, Shut down. The last three need a second click, so nothing happens by accident.
PanelWindow {
    screen: Mon.screen
    id: pw
    property bool open: false
    property real t: 0
    // t runs evenly; the menu eases on its own: it grows out of the bar (quick start, soft landing) and
    // folds back up quickly when it closes
    Behavior on t { NumberAnimation { duration: pw.open ? 520 : 160; easing.type: Easing.Linear } }
    readonly property real et: Look.panelEase(t, outCurve)
    property bool outCurve: false            // Look.panelEase: a close that started fully open
    onTChanged: if (outCurve && (t < 0.001 || (open && t > 0.999))) outCurve = false
    onOpenChanged: { if (!open && t > 0.98) outCurve = true; t = open ? 1 : 0 }

    readonly property color fg: "#F6F5F4"
    readonly property color dim: Qt.rgba(0.965, 0.961, 0.957, 0.6)
    readonly property color line: Qt.rgba(1, 1, 1, 0.09)
    readonly property color bg: Qt.rgba(0.05, 0.05, 0.05, Look.flat ? 1 : 0.62)
    property var bc: ({})
    readonly property bool atBottom: bc.position === "bottom"
    readonly property real barSpace: (bc.enabled === false ? 34 : (bc.height ? bc.height : 38)) + (bc.style === "flat" ? 0 : 16) + 8
    property real cx: 0
    property string armed: ""          // the action that waits for its second click
    property int hover: -1

    readonly property var items: [
        { key: "lock", label: Tr.t("Lock"), icon: "lock", glyph: 0xF033E, cmd: "\"$HOME/.local/bin/rice-power\" lock", ask: false },
        { key: "suspend", label: Tr.t("Sleep"), icon: "bedtime", glyph: 0xF0904, cmd: "\"$HOME/.local/bin/rice-power\" lock; sleep 0.6; systemctl suspend", ask: false },
        { key: "logout", label: Tr.t("Log out"), icon: "logout", glyph: 0xF0343, cmd: "\"$HOME/.local/bin/logout\"", ask: true },
        { key: "reboot", label: Tr.t("Restart"), icon: "restart_alt", glyph: 0xF0709, cmd: "systemctl reboot", ask: true },
        { key: "poweroff", label: Tr.t("Shut down"), icon: "power_settings_new", glyph: 0xF0425, cmd: "systemctl poweroff", ask: true }
    ]
    function run(it) {
        if (it.ask && armed !== it.key) { armed = it.key; Sfx.play("click"); disarm.restart(); return }
        Sfx.play("select")
        hide()
        Quickshell.execDetached(["bash", "-c", "sleep 0.15; " + it.cmd])
    }
    Timer { id: disarm; interval: 3000; onTriggered: pw.armed = "" }

    Process {
        id: barProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-bar\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { pw.bc = JSON.parse(text) } catch (e) { } } }
    }
    // opens on the monitor you are on, or the one whose bar you clicked (Mon.qml)
    function show(x) { pw.screen = Mon.target(); cx = x; armed = ""; barProc.running = true; open = true }
    function hide() { open = false; armed = "" }
    Trigger {
        name: "power-open"
        onFired: function(o) {
            const x = parseFloat(o.split(" ")[1])
            if (pw.open) pw.hide(); else pw.show(isNaN(x) ? pw.width - 120 : x)
        }
    }

    visible: open || (t > 0.01 && !closeT.done)
    // if the closing animation ever stalls (the compositor sent no frames for a moment), it still goes away
    Timer { id: closeT; property bool done: false; interval: 600; running: !open; onRunningChanged: if (running) done = false; onTriggered: done = true }
    // niri: blur behind the card (Hyprland blurs this layer with its own rule)
    NiriBlur { win: pw; items: [card]; radius: card.radius; on: pw.open && pw.t > 0.98 }
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; onClicked: pw.hide() }

    Rectangle {
        id: card
        width: 220
        height: col.height + 16
        x: Math.max(12, Math.min(pw.width - width - 12, pw.cx - width / 2))
        y: pw.atBottom ? pw.height - pw.barSpace - height : pw.barSpace
        radius: 20
        color: pw.bg
        border.width: 1; border.color: pw.line
        opacity: Math.min(1, pw.et * 1.6)
        scale: 0.9 + 0.1 * pw.et
        transformOrigin: pw.atBottom ? Item.Bottom : Item.Top
        transform: Translate { y: (1 - pw.et) * (pw.atBottom ? 26 : -26) }
        focus: true
        Keys.onEscapePressed: pw.hide()
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: 8; y: 8; width: parent.width - 16
            Repeater {
                model: pw.items
                delegate: Item {
                    id: row
                    readonly property bool hot: pw.armed === modelData.key
                    readonly property bool danger: modelData.key === "poweroff" || modelData.key === "reboot"
                    readonly property bool red: modelData.key === "poweroff"           // Shut down is always red
                    width: col.width; height: 44
                    opacity: 0
                    property real slide: -8
                    transform: Translate { y: row.slide }
                    Component.onCompleted: enter.start()
                    SequentialAnimation { id: enter
                        PauseAnimation { duration: index * 28 }
                        ParallelAnimation {
                            NumberAnimation { target: row; property: "opacity"; to: 1; duration: 180 }
                            NumberAnimation { target: row; property: "slide"; to: 0; duration: 240; easing.type: Easing.OutCubic }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 2; radius: 13
                        color: row.hot ? (row.danger ? Qt.rgba(1, 0.42, 0.42, 0.22) : Qt.rgba(1, 1, 1, 0.14)) : (rm.containsMouse ? (row.red ? Qt.rgba(1, 0.42, 0.42, 0.14) : Qt.rgba(1, 1, 1, 0.07)) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MIcon { x: 14; anchors.verticalCenter: parent.verticalCenter; size: 19; name: modelData.icon; glyph: String.fromCodePoint(modelData.glyph)
                        color: (row.hot && row.danger) || row.red ? "#ff8a8a" : pw.fg }
                    Text { x: 46; anchors.verticalCenter: parent.verticalCenter; font.family: Fonts.main; font.pixelSize: 14
                        text: row.hot ? Tr.t("Click again: ") + modelData.label.toLowerCase() : modelData.label
                        color: (row.hot && row.danger) || row.red ? "#ff8a8a" : pw.fg }
                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pw.run(modelData) }
                }
            }
        }
    }
}
