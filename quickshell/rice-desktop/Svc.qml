pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// rice-services state (network, bluetooth, do not disturb ...), read once for every bar. One run starts about
// 20 programs (systemctl, nmcli, wpctl, powerprofilesctl ...); each bar polling it on its own doubled that.
Singleton {
    id: sv
    property var state: ({})
    property int users: 0                 // bars that show it (Bar.qml counts itself in and out)
    function again() { soon.restart() }   // re-read shortly after a toggle
    Process {
        id: proc
        command: ["bash", "-c", "\"$HOME/.local/bin/rice-services\" state 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { try { sv.state = JSON.parse(text) } catch (e) { } } }
    }
    Timer { interval: 8000; running: sv.users > 0; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }
    Timer { id: soon; interval: 700; onTriggered: if (!proc.running) proc.running = true }
}
