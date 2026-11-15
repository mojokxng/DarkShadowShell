import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

// The DarkShadow bar on the LEFT or RIGHT edge (Settings > DarkShadow bar > Position). The same modules as the
// top bar, stacked: the layout's left zone goes on top, center in the middle, right at the bottom. The clock
// stands as hours over minutes, the workspaces as a column of dots, the visualizer grows sideways.
// (The top / bottom bar is Bar.qml; only one of the two shows.)
PanelWindow {
    id: vb
    screen: Mon.screen

    // ---------- settings (~/.config/rice/bar.json, the same file as the top bar) ----------
    property var bc: ({})
    property string cfgText: ""
    readonly property string home: Quickshell.env("HOME")
    Trigger {
        path: vb.home + "/.config/rice/bar.json"
        every: 2000
        onContent: function(t) {
            const x = t.trim()
            if (x === vb.cfgText) return
            vb.cfgText = x
            try { vb.bc = x === "" ? ({}) : JSON.parse(x) } catch (e) { }
        }
    }
    readonly property bool atRight: bc.position === "right"
    readonly property bool on: bc.enabled !== false && (bc.position === "left" || bc.position === "right")
    readonly property string sty: bc.style === "flat" ? "flat" : (bc.style === "dynamic" || bc.style === "google" || bc.style === undefined ? "dynamic" : "island")
    readonly property bool goo: sty === "dynamic"
    readonly property bool flat: sty === "flat"
    readonly property int barW: bc.height ? bc.height + 4 : 42
    readonly property real gap: flat ? 0 : 8
    readonly property real alpha: Look.flat ? 1 : (bc.opacity !== undefined ? bc.opacity : 0.72)
    NPal { id: gp; theme: "shell"; alpha: Math.min(1, vb.alpha + 0.14) }
    readonly property color fg: goo ? gp.fg : "#F6F5F4"
    readonly property color dim: goo ? gp.dim : Qt.rgba(0.965, 0.961, 0.957, 0.66)
    readonly property color bg: goo ? gp.surface : Qt.rgba(0.05, 0.05, 0.05, alpha)
    readonly property int nws: bc.workspaces ? bc.workspaces : 5
    function noClock(l) { return (l || []).map(function(m) { return m === "clock" ? "island" : m }) }
    readonly property var lay: bc.layout ? ({ top: noClock(bc.layout.left), mid: noClock(bc.layout.center), bottom: noClock(bc.layout.right) })
        : ({ top: ["launcher", "workspaces"], mid: ["island"], bottom: ["tray", "volume", "bluetooth", "network", "battery", "notifications", "power"] })
    function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
    // the pop-up menus open next to the bar: they are told a spot near this edge
    function menuX() { return atRight ? (vb.screen ? vb.screen.width - 260 : 1660) : 260 }

    // ---------- the window ----------
    visible: rvW.alive && (on)
    Revive { id: rvW; win: vb }     // back after niri closed it (its monitor went off)
    color: "transparent"
    anchors { top: true; bottom: true; left: !atRight; right: atRight }
    implicitWidth: barW + gap * 2
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barW + gap * 2
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"
    NiriBlur { win: vb; items: [panel]; radius: panel.radius; on: vb.on }

    // ---------- what it shows ----------
    readonly property var player: { const l = Mpris.players.values; for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i]; return l.length ? l[0] : null }
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [vb.sink] }
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var batt: UPower.displayDevice
    readonly property bool hasBatt: batt && batt.isPresent && batt.isLaptopBattery
    readonly property real battPct: batt ? Math.round(batt.percentage * 100) : 0
    readonly property bool charging: batt && (batt.state === UPowerDeviceState.Charging || batt.state === UPowerDeviceState.FullyCharged)
    property var svc: ({})
    Process {
        id: svcProc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-services\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { vb.svc = JSON.parse(text) } catch (e) { } } }
    }
    Timer { interval: 8000; running: vb.on; repeat: true; triggeredOnStart: true; onTriggered: if (!svcProc.running) svcProc.running = true }
    Timer { id: svcAgain; interval: 700; onTriggered: if (!svcProc.running) svcProc.running = true }
    property var now: new Date()
    Timer { interval: 15000; running: vb.on; repeat: true; triggeredOnStart: true; onTriggered: vb.now = new Date() }
    property bool h12: false
    Trigger { path: vb.home + "/.config/rice/region.json"; every: 5000; onContent: function(t) { vb.h12 = /"clock": *"12"/.test(t) } }
    function two(n) { return n < 10 ? "0" + n : "" + n }

    // ---------- the panel ----------
    Rectangle {
        id: panel
        x: vb.gap; y: vb.gap
        width: vb.barW; height: parent.height - vb.gap * 2
        radius: vb.flat ? 0 : vb.barW / 2
        color: vb.bg
        border.width: vb.goo ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.07)

        Column { id: topCol; anchors.horizontalCenter: parent.horizontalCenter; y: 10; spacing: 6
            Repeater { model: vb.lay.top; delegate: Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: vb.compFor(modelData) } } }
        Column { anchors.centerIn: parent; spacing: 6
            Repeater { model: vb.lay.mid; delegate: Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: vb.compFor(modelData) } } }
        Column { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; spacing: 6
            Repeater { model: vb.lay.bottom; delegate: Loader { anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: vb.compFor(modelData) } } }
    }

    function compFor(n) {
        switch (n) {
        case "launcher": return cLauncher
        case "workspaces": return cWs
        case "island": case "clock": return cClock
        case "media": return cMedia
        case "tray": return cTray
        case "volume": return cVolume
        case "network": return cNet
        case "bluetooth": return cBt
        case "battery": return cBatt
        case "notifications": return cNotif
        case "power": return cPower
        case "visualizer": return cViz
        }
        return null                     // the window title has no room standing up
    }

    // one round icon button
    component Btn: Item {
        id: b
        property string icon: ""
        property string glyph: ""
        property color tint: vb.fg
        property real isz: 19
        signal hit(var mouse)
        signal wheel(var e)
        width: vb.barW - 10; height: width
        Rectangle { anchors.fill: parent; radius: width / 2; color: vb.fg; opacity: bm.containsMouse ? 0.1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } } }
        MIcon { anchors.centerIn: parent; size: b.isz; name: b.icon; glyph: b.glyph; color: b.tint }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(m) { Sfx.play("click"); b.hit(m) }
            onWheel: function(e) { b.wheel(e) } }
    }

    Component { id: cLauncher
        Item { width: vb.barW - 6; height: width
            Rectangle { anchors.fill: parent; radius: lm.pressed ? width * 0.3 : width / 2; visible: vb.goo
                color: gp.mono ? gp.container : gp.primary; scale: lm.containsMouse ? 1.06 : 1
                Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } } }
            BlackHoleMark { visible: vb.bc.logo === "blackhole"; anchors.centerIn: parent; size: parent.width; extras: false; running: visible && !Look.lite }
            MoonMark { visible: vb.bc.logo === "moon"; anchors.centerIn: parent; size: parent.width - 8; extras: false; running: visible && !Look.lite }
            MIcon { visible: vb.bc.logo !== "blackhole" && vb.bc.logo !== "moon"; anchors.centerIn: parent; name: "apps"; glyph: String.fromCodePoint(0xF003B); size: 18
                color: vb.goo ? (gp.mono ? gp.inkContainer : gp.inkPrimary) : vb.fg }
            MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { Sfx.play("click"); vb.run("\"$HOME/.local/bin/rice-launch\"") } }
        }
    }

    Component { id: cWs
        Column {
            spacing: 4
            Repeater {
                model: Wm.maxWs(vb.nws)
                delegate: Item {
                    readonly property int wid: index + 1
                    readonly property bool act: Wm.focusedId === wid
                    readonly property bool occ: Wm.occupied(wid)
                    width: vb.barW - 10; height: act ? 34 : 16
                    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: act ? 10 : (occ ? 9 : 6); height: act ? parent.height - 6 : width; radius: width / 2
                        color: act ? (vb.goo ? gp.primary : vb.fg) : (occ ? vb.fg : vb.dim)
                        opacity: act ? 1 : (occ ? 0.75 : 0.35)
                        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wm.goWs(wid) }
                }
            }
            // the wheel over the dots: one workspace per notch
            property real sum: 0
            WheelHandler { onWheel: function(e) { parent.sum += e.angleDelta.y; while (Math.abs(parent.sum) >= 120) { Wm.goWs(parent.sum > 0 ? "e-1" : "e+1"); parent.sum -= (parent.sum > 0 ? 120 : -120) } } }
        }
    }

    Component { id: cClock
        Rectangle {
            width: vb.barW - 8; height: cc.implicitHeight + 16; radius: width / 2
            color: vb.goo ? gp.container : "transparent"
            Column { id: cc; anchors.centerIn: parent; spacing: -2
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: vb.h12 ? String((vb.now.getHours() + 11) % 12 + 1) : vb.two(vb.now.getHours())
                    color: vb.goo ? gp.inkContainer : vb.fg; font.family: Fonts.main; font.pixelSize: 16; font.weight: Font.Bold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: vb.two(vb.now.getMinutes())
                    color: vb.goo ? gp.inkContainer : vb.fg; opacity: 0.8; font.family: Fonts.main; font.pixelSize: 16; font.weight: Font.Medium }
                Text { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 4; text: vb.now.getDate() + "." + vb.two(vb.now.getMonth() + 1)
                    color: vb.goo ? gp.inkContainer : vb.dim; opacity: 0.7; font.family: Fonts.main; font.pixelSize: 10 }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Sfx.play("click"); vb.run("\"$HOME/.local/bin/rice-dashboard\" open") } }
        }
    }

    Component { id: cMedia
        Btn { visible: vb.player !== null; icon: vb.player && vb.player.isPlaying ? "pause" : "music_note"; glyph: String.fromCodePoint(vb.player && vb.player.isPlaying ? 0xF03E4 : 0xF075A)
            onHit: function(m) { if (vb.player) vb.player.togglePlaying() } }
    }

    Component { id: cTray
        Column { spacing: 6
            Repeater {
                model: SystemTray.items.values || []
                delegate: Item {
                    id: ti
                    width: vb.barW - 10; height: 24
                    IconImage { anchors.centerIn: parent; implicitSize: Math.min(20, vb.bc.tray_size ? vb.bc.tray_size : 18); source: Icons.src(modelData.icon)
                        scale: tm.containsMouse ? 1.15 : 1; Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } } }
                    MouseArea {
                        id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: function(m) {
                            if ((m.button === Qt.RightButton || modelData.onlyMenu) && modelData.hasMenu) {
                                const p = ti.mapToItem(null, vb.atRight ? -4 : ti.width + 4, 0)
                                modelData.display(vb, p.x, p.y)
                            } else if (m.button === Qt.MiddleButton) modelData.secondaryActivate()
                            else modelData.activate()
                        }
                    }
                }
            }
        }
    }

    Component { id: cVolume
        Btn { icon: vb.muted ? "volume_off" : (vb.vol < 0.34 ? "volume_mute" : (vb.vol < 0.67 ? "volume_down" : "volume_up"))
            glyph: String.fromCodePoint(vb.muted ? 0xF0581 : (vb.vol < 0.34 ? 0xF057F : (vb.vol < 0.67 ? 0xF0580 : 0xF057E)))
            tint: vb.muted ? vb.dim : vb.fg; isz: 20
            onHit: function(m) {
                if (m.button === Qt.LeftButton) vb.run("\"$HOME/.local/bin/rice-volume\" menu " + vb.menuX())
                else if (vb.sink && vb.sink.audio) vb.sink.audio.muted = !vb.sink.audio.muted
            }
            onWheel: function(e) { if (vb.sink && vb.sink.audio) vb.sink.audio.volume = Math.max(0, Math.min(1, vb.sink.audio.volume + Look.notches(e) * 0.04)) } }
    }
    Component { id: cNet
        Btn { icon: vb.svc.network ? "wifi" : "wifi_off"; glyph: String.fromCodePoint(vb.svc.network ? 0xF05A9 : 0xF05AA); tint: vb.svc.network ? vb.fg : vb.dim
            onHit: function(m) { vb.run("\"$HOME/.local/bin/rice-wifi\" " + vb.menuX()) } }
    }
    Component { id: cBt
        Btn { icon: vb.svc.bluetooth ? "bluetooth" : "bluetooth_disabled"; glyph: String.fromCodePoint(vb.svc.bluetooth ? 0xF00AF : 0xF00B2); tint: vb.svc.bluetooth ? vb.fg : vb.dim
            onHit: function(m) { vb.run("\"$HOME/.local/bin/rice-bluetooth\" " + vb.menuX()) } }
    }
    Component { id: cBatt
        Column { visible: vb.hasBatt; spacing: 1
            MIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 17; color: !vb.charging && vb.battPct <= 15 ? "#ff6b6b" : vb.fg
                name: vb.charging ? "battery_charging_full" : "battery_full"; glyph: String.fromCodePoint(vb.charging ? 0xF0084 : 0xF0079) }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: vb.battPct; color: vb.dim; font.family: Fonts.main; font.pixelSize: 10 }
        }
    }
    Component { id: cNotif
        Btn { icon: vb.svc.dnd ? "notifications_off" : "notifications"; glyph: String.fromCodePoint(vb.svc.dnd ? 0xF009B : 0xF009A); tint: vb.svc.dnd ? vb.dim : vb.fg
            onHit: function(m) { vb.run(m.button === Qt.RightButton ? "\"$HOME/.local/bin/rice-cc\" dnd toggle" : "\"$HOME/.local/bin/rice-cc\" toggle"); svcAgain.restart() } }
    }
    Component { id: cPower
        Btn { icon: "power_settings_new"; glyph: String.fromCodePoint(0xF0425); tint: "#ff8a80"
            onHit: function(m) { vb.run("\"$HOME/.local/bin/rice-power\" " + vb.menuX()) } }
    }
    Component { id: cViz
        BarViz { vertical: true; count: 10; thick: vb.barW - 18; active: vb.on; color: vb.goo ? gp.primary : vb.fg }
    }
}
