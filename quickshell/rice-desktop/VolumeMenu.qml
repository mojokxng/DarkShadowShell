import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick

// The sound menu: right click the volume icon on the bar and it drops down under it (like a small pavucontrol).
// Output volume, where the sound goes (speakers, headphones ...), the microphone and the apps that play right now.
PanelWindow {
    id: vm
    property bool open: false
    property real t: 0
    // t runs evenly; the menu eases on its own: it grows out of the bar (quick start, soft landing) and
    // folds back up quickly when it closes
    Behavior on t { NumberAnimation { duration: vm.open ? 520 : 160; easing.type: Easing.Linear } }
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

    // ---------- Pipewire ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    function pick(f) { return Pipewire.nodes.values.filter(f) }
    readonly property var sinks: pick(function(n) { return n.audio && n.isSink && !n.isStream })
    readonly property var sources: pick(function(n) { return n.audio && !n.isSink && !n.isStream && (n.name || "").indexOf(".monitor") < 0 })
    readonly property var apps: pick(function(n) { return n.audio && n.isStream && !n.isSink })
    PwObjectTracker { objects: [vm.sink, vm.source].concat(vm.sinks, vm.sources, vm.apps) }
    function label(n) {
        if (!n) return ""
        const p = n.properties || {}
        return p["application.name"] || n.nickname || n.description || n.name || "?"
    }
    function setVol(n, v) { if (n && n.audio) { n.audio.muted = false; n.audio.volume = Math.max(0, Math.min(1, v)) } }

    Process {
        id: barProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-bar\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { vm.bc = JSON.parse(text) } catch (e) { } } }
    }
    // opens on the monitor you are on, or the one whose bar you clicked (Mon.qml)
    function show(x) { vm.screen = Mon.target(); cx = x; barProc.running = true; open = true }
    function hide() { open = false }
    Trigger {
        name: "volume-open"
        onFired: function(o) {
            const x = parseFloat(o.split(" ")[1])
            if (vm.open) vm.hide(); else vm.show(isNaN(x) ? vm.width - 200 : x)
        }
    }

    visible: open || (t > 0.01 && !closeT.done)
    // if the closing animation ever stalls (the compositor sent no frames for a moment), it still goes away
    Timer { id: closeT; property bool done: false; interval: 600; running: !open; onRunningChanged: if (running) done = false; onTriggered: done = true }
    // niri: blur behind it (Hyprland blurs this layer with its own rule)
    NiriBlur { win: vm; items: [card]; radius: card.radius; on: vm.open && vm.t > 0.98 }
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-volume"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    MouseArea { anchors.fill: parent; onClicked: vm.hide() }

    // ---------- pieces ----------
    // a volume line: icon (click mutes), slider, percent
    component VolRow: Item {
        id: vr
        property var node: null
        property string text: ""
        property string iconName: "volume_up"
        property int glyph: 0xF057E
        property string iconSrc: ""
        readonly property real v: node && node.audio ? node.audio.volume : 0
        readonly property bool muted: node && node.audio ? node.audio.muted : false
        width: parent ? parent.width : 300; height: text !== "" ? 58 : 40
        Text { visible: vr.text !== ""; x: 46; y: 2; width: parent.width - 100; elide: Text.ElideRight; text: vr.text
            color: vm.dim; font.family: Fonts.main; font.pixelSize: 12 }
        Item {
            id: ib
            x: 6; width: 32; height: 32; y: parent.height - 36
            IconImage { visible: vr.iconSrc !== ""; anchors.centerIn: parent; implicitSize: 22; source: vr.iconSrc }
            MIcon { visible: vr.iconSrc === ""; anchors.centerIn: parent; size: 20; color: vr.muted ? vm.dim : vm.fg
                name: vr.muted ? (vr.iconName === "mic" ? "mic_off" : "volume_off") : vr.iconName
                glyph: String.fromCodePoint(vr.muted ? (vr.iconName === "mic" ? 0xF036D : 0xF0581) : vr.glyph) }
            Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(1, 1, 1, ibm.containsMouse ? 0.08 : 0) }
            MouseArea { id: ibm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: if (vr.node && vr.node.audio) vr.node.audio.muted = !vr.node.audio.muted }
        }
        Item {
            id: track
            x: 46; width: parent.width - 46 - 54; height: 32; y: ib.y
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.12) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(6, parent.width * vr.v); height: 6; radius: 3
                color: vr.muted ? Qt.rgba(1, 1, 1, 0.3) : vm.fg
                Behavior on width { enabled: !sm.pressed; NumberAnimation { duration: 120 } } }
            Rectangle { x: parent.width * vr.v - width / 2; anchors.verticalCenter: parent.verticalCenter
                width: sm.pressed || sm.containsMouse ? 16 : 12; height: width; radius: width / 2; color: vm.fg
                Behavior on width { NumberAnimation { duration: 100 } } }
            MouseArea {
                id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onPressed: function(m) { vm.setVol(vr.node, m.x / width) }
                onPositionChanged: function(m) { if (pressed) vm.setVol(vr.node, m.x / width) }
                onWheel: function(e) { vm.setVol(vr.node, vr.v + Look.notches(e) * 0.04) }
            }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 8; y: ib.y + (32 - height) / 2; text: Math.round(vr.v * 100) + "%"
            color: vm.fg; font.family: Fonts.main; font.pixelSize: 13; width: 42; horizontalAlignment: Text.AlignRight }
    }
    // one device you can pick
    component DevRow: Item {
        id: dr
        property var node: null
        property bool chosen: false
        signal picked()
        width: parent ? parent.width : 300; height: 36
        Rectangle { anchors.fill: parent; radius: 11; color: dr.chosen ? Qt.rgba(1, 1, 1, 0.12) : (dm.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } } }
        Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: "transparent"
            border.width: 2; border.color: dr.chosen ? vm.fg : vm.dim
            Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: vm.fg; visible: dr.chosen } }
        Text { x: 40; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52; elide: Text.ElideRight
            text: vm.label(dr.node); color: dr.chosen ? vm.fg : vm.dim; font.family: Fonts.main; font.pixelSize: 13 }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dr.picked() }
    }
    component Head: Text { color: vm.fg; font.family: Fonts.main; font.pixelSize: 12; font.weight: Font.DemiBold; topPadding: 8; leftPadding: 8; opacity: 0.85 }

    Rectangle {
        id: card
        width: 380
        height: Math.min(col.implicitHeight + 28, vm.height - vm.barSpace - 20)
        x: Math.max(12, Math.min(vm.width - width - 12, vm.cx - width / 2))
        y: vm.atBottom ? vm.height - vm.barSpace - height : vm.barSpace
        radius: 20
        color: vm.bg
        border.width: 1; border.color: vm.line
        clip: true
        opacity: Math.min(1, vm.et * 1.6)
        scale: 0.9 + 0.1 * vm.et
        transformOrigin: vm.atBottom ? Item.Bottom : Item.Top
        transform: Translate { y: (1 - vm.et) * (vm.atBottom ? 26 : -26) }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: vm.hide()
        MouseArea { anchors.fill: parent; onWheel: function(e) { } }

        Flickable {
            anchors.fill: parent; anchors.margins: 14
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: 4

                Item {
                    width: parent.width; height: 34
                    MIcon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: "graphic_eq"; glyph: String.fromCodePoint(0xF1450); size: 20; color: vm.fg }
                    Text { x: 40; anchors.verticalCenter: parent.verticalCenter; text: "Sound"; color: vm.fg; font.family: Fonts.main; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Rectangle {   // open pavucontrol
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: pv.implicitWidth + 22; height: 28; radius: 9
                        color: pvm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                        Text { id: pv; anchors.centerIn: parent; text: "More…"; color: vm.fg; font.family: Fonts.main; font.pixelSize: 12 }
                        MouseArea { id: pvm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { vm.hide(); Quickshell.execDetached(["bash", "-c", "pavucontrol || pwvucontrol"]) } }
                    }
                }

                VolRow { node: vm.sink; iconName: "volume_up"; glyph: 0xF057E }

                Head { text: "Output"; visible: vm.sinks.length > 1 }
                Repeater {
                    model: vm.sinks.length > 1 ? vm.sinks : []
                    delegate: DevRow { node: modelData; chosen: !!vm.sink && vm.sink.name === modelData.name; onPicked: Pipewire.preferredDefaultAudioSink = modelData }
                }

                Head { text: "Microphone"; visible: vm.source !== null }
                VolRow { visible: vm.source !== null; node: vm.source; iconName: "mic"; glyph: 0xF036C }
                Repeater {
                    model: vm.sources.length > 1 ? vm.sources : []
                    delegate: DevRow { node: modelData; chosen: !!vm.source && vm.source.name === modelData.name; onPicked: Pipewire.preferredDefaultAudioSource = modelData }
                }

                Head { text: "Apps"; visible: vm.apps.length > 0 }
                Repeater {
                    model: vm.apps
                    delegate: VolRow {
                        node: modelData
                        text: vm.label(modelData)
                        iconSrc: { const p = modelData.properties || {}; const n = p["application.icon-name"] || ""; return n !== "" ? Quickshell.iconPath(n, true) : "" }
                        iconName: "music_note"; glyph: 0xF075A
                    }
                }
            }
        }
    }
}
