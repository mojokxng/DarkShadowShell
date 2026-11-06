import Quickshell
import Quickshell.Io
import QtQuick

Column {
    id: page
    property var ctl
    property var mons: []
    property int countdown: 0
    spacing: 14

    Process {
        id: monProc
        command: ["bash", "-c", "\"$HOME/.local/bin/hypr-set\" monitors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.mons = JSON.parse(text) } catch (e) { } }
        }
    }

    Timer { id: refresh; interval: 1500; onTriggered: monProc.running = true }

    Timer {
        interval: 1000
        repeat: true
        running: page.countdown > 0
        onTriggered: {
            page.countdown -= 1
            if (page.countdown === 0) page.revert()
        }
    }

    function ratesFor(m, res) {
        for (let i = 0; i < m.modes.length; i++) {
            if (m.modes[i].res === res) return m.modes[i].rates
        }
        return []
    }
    function apply(name, res, rate, scale) {
        ctl.hrun(["monitor-apply", name, res, rate, scale], "Display changed")
        countdown = 12
        refresh.restart()
    }
    // ---------- more than one monitor: their order (left to right) and the main one ----------
    readonly property var ordered: mons.slice().sort(function(a, b) { return a.x - b.x || a.y - b.y })
    property string mainName: ""
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice/screens.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.mainName = JSON.parse(text()).main || "" } catch (e) { page.mainName = "" } }
        onLoadFailed: page.mainName = ""
    }
    // what the shell uses when none was picked: the left one (the same rule as Mon.qml in the desktop shell)
    readonly property string mainShown: mainName !== "" && mons.some(function(m) { return m.name === mainName }) ? mainName
        : (ordered.length > 0 ? ordered[0].name : "")
    function move(i, d) {
        const l = ordered.map(function(m) { return m.name })
        const j = i + d
        if (j < 0 || j >= l.length) return
        const t = l[i]; l[i] = l[j]; l[j] = t
        ctl.hrun(["monitor-arrange", l.join(",")], "Monitors arranged")
        refresh.restart()
    }
    function setMain(n) { ctl.hrun(["monitor-main", n], n + " is the main monitor"); mainName = n }

    function keep() { ctl.hrun(["monitor-keep"], "Display settings saved"); countdown = 0; refresh.restart() }
    function revert() { ctl.hrun(["monitor-revert"], "Reverted display settings"); countdown = 0; refresh.restart() }

    Rectangle {
        visible: page.countdown > 0
        width: parent.width
        height: 56
        radius: 12
        color: M3.surfaceHigh
        border.width: 1
        border.color: M3.outline
        T {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("Keep these display settings? Reverting in ") + page.countdown + " s"
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Pill { label: I18n.t("Keep"); onClicked: page.keep() }
            Pill { label: I18n.t("Revert"); onClicked: page.revert() }
        }
    }

    Rectangle {
        visible: page.mons.length > 1
        width: parent.width
        height: visible ? arr.implicitHeight + 28 : 0
        radius: 12
        color: M3.surfaceC
        border.width: 1
        border.color: M3.outlineVariant
        Column {
            id: arr
            x: 16; y: 14
            width: parent.width - 32
            spacing: 10
            T { text: I18n.t("Arrangement"); font.bold: true }
            T { kind: "reading"; width: parent.width; wrapMode: Text.WordWrap; color: M3.inkDim; font.pixelSize: 12
                text: I18n.t("Left to right, as they stand on your desk. The main monitor has the desktop widgets, the dock and the notifications; the launcher and the menus open on the monitor you are on.") }
            // the monitors as they are placed, to scale
            Row {
                id: strip
                spacing: 8
                readonly property real total: page.ordered.reduce(function(a, m) { return a + m.width / (m.scale || 1) }, 0)
                readonly property real k: total > 0 ? (arr.width - 8 * Math.max(0, page.ordered.length - 1)) / total : 0
                Repeater {
                    model: page.ordered
                    delegate: Rectangle {
                        id: tile
                        readonly property bool isMain: modelData.name === page.mainShown
                        width: modelData.width / (modelData.scale || 1) * strip.k
                        height: Math.min(150, modelData.height / (modelData.scale || 1) * strip.k)
                        radius: 10
                        color: isMain ? M3.primaryContainer : M3.surfaceHigh
                        border.width: isMain ? 2 : 1
                        border.color: isMain ? M3.primary : M3.outlineVariant
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            T { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; font.bold: true
                                color: tile.isMain ? M3.inkPrimaryC : M3.ink }
                            T { anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 11
                                text: tile.isMain ? I18n.t("Main") : modelData.width + "x" + modelData.height
                                color: tile.isMain ? M3.inkPrimaryC : M3.inkDim }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 6
                                Pill { label: "◀"; visible: index > 0; onClicked: page.move(index, -1) }
                                Pill { label: I18n.t("Make main"); visible: !tile.isMain; onClicked: page.setMain(modelData.name) }
                                Pill { label: "▶"; visible: index < page.ordered.length - 1; onClicked: page.move(index, 1) }
                            }
                        }
                    }
                }
            }
        }
    }

    Repeater {
        model: page.mons
        delegate: Rectangle {
            id: card
            property var m: modelData
            property string curRes: m.width + "x" + m.height
            width: page.width
            height: inner.implicitHeight + 28
            radius: 12
            color: M3.surfaceC
            border.width: 1
            border.color: M3.outlineVariant

            Column {
                id: inner
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 8

                T { text: card.m.name + "   " + card.curRes + " @ " + card.m.rate + I18n.t(" Hz   scale ") + card.m.scale; font.bold: true }

                T { text: I18n.t("Resolution"); color: M3.inkDim; font.pixelSize: 12 }
                Seg {
                    options: card.m.modes.slice(0, 5).map(x => ({ label: x.res, value: x.res }))
                    current: card.curRes
                    onChosen: function(v) {
                        const r = page.ratesFor(card.m, v)
                        page.apply(card.m.name, v, r.length > 0 ? r[0] : card.m.rate, card.m.scale)
                    }
                }

                T { text: I18n.t("Refresh rate"); color: M3.inkDim; font.pixelSize: 12 }
                Seg {
                    options: page.ratesFor(card.m, card.curRes).slice(0, 6).map(x => ({ label: x + I18n.t(" Hz"), value: x }))
                    current: card.m.rate
                    onChosen: function(v) { page.apply(card.m.name, card.curRes, v, card.m.scale) }
                }

                T { text: I18n.t("Scale"); color: M3.inkDim; font.pixelSize: 12 }
                Seg {
                    options: [
                        { label: "1x", value: "1" },
                        { label: "1.25x", value: "1.25" },
                        { label: "1.5x", value: "1.5" },
                        { label: "2x", value: "2" }
                    ]
                    current: String(card.m.scale)
                    onChosen: function(v) { page.apply(card.m.name, card.curRes, card.m.rate, v) }
                }
            }
        }
    }

    T {
        visible: page.mons.length === 0
        text: I18n.t("No monitors found.")
        color: M3.inkDim
    }
}
