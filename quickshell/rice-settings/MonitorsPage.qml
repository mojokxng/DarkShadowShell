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
