pragma Singleton
import Quickshell
import QtQuick

// How see-through the desktop widgets are, and what colors they take. shell.qml fills this in from desktop.json and rice-effects.
Singleton {
    id: look
    // blurred wallpaper behind the cards (Settings > Widgets > Blur)
    property bool blur: true
    // how strong the widget cards are, for all widgets (Settings > Widgets > Transparency): 1 solid .. 0.2 see-through
    property real widgetAlpha: 1
    // no blur and no transparency at all (Settings > Services: Lite, or gaming mode)
    property bool flat: false
    // Light mode (Settings > Home): the visualizer stops and widgets pause while a window covers them
    property bool lite: false
    // windows cover the desktop (rice-busy): the widgets' decorative motion pauses (nobody sees it, and the
    // compositor does not have to redraw the desktop under the windows)
    property bool covered: false
    // widget style (Settings > Widgets > Theme): shadow (DarkShadow's Shell), google, outline
    property string theme: "shadow"
    // text and cards turn light or dark with the wallpaper behind each widget (Settings > Widgets)
    property bool adapt: true
    // shell shadows (Settings > Desktop > Windows; rice-shadows): shell.qml fills these in from shadows.json
    property bool shadowsAll: true
    property bool shadowBar: true
    property bool shadowPanels: true
    property bool shadowWidgets: true
    property bool shadowNotif: true
    property real shadowSize: 18
    property real shadowStrength: 0.45
    readonly property bool shadows: shadowsAll && !flat
    // your shape (Settings > Appearance > Shapes; settings-app.json): icons, loaders and highlights take it
    property string shape: "verysunny"
    // progress lines and rings: wavy or flat, and how thick (Settings > Appearance > Components; settings-app.json)
    property bool wavy: true
    property real waveThick: 4
    // Material 3 motion curves for the panels: in on emphasized-decelerate, out on emphasized-accelerate
    readonly property var decel: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var accel: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var emph: [0.2, 0, 0, 1, 1, 1]
    // how far a panel is shown, from its even-running t (0 .. 1). In: a quick start and a long soft landing.
    // Out (a close that starts fully open): t^3, so it starts to leave the moment you close it. The in curve
    // played backwards hardly moved for the first half of the close (still 94 % there), which read as a slow
    // close. A panel clears `out` once t is back at 0 or 1, so a reversed animation never jumps between curves.
    function panelEase(t, out) {
        const p = Math.max(0, Math.min(1, t))
        return out ? p * p * p : 1 - Math.pow(1 - p, 4)
    }
    // the accent color of your theme (Waybar colors), used by the Google style and the visualizer
    property color accent: "#9ec9bd"

    // brightness of the wallpaper (shell.qml's WallLum reads it): lumW x lumH cells, each 0 (black) .. 1 (white)
    property var lumGrid: []
    property int lumW: 64
    property int lumH: 36
    // average brightness of a rectangle of the screen (x, y, w, h in screen pixels); 0.3 until the wallpaper is read
    // how far a wheel event moves a slider (the volume ...), in mouse-wheel notches: one notch of a mouse is 1,
    // a touchpad gives its distance (about 50 px of finger = 1), so a swipe no longer jumps a whole step per event
    function notches(e) {
        if (e.pixelDelta && e.pixelDelta.y !== 0) return e.pixelDelta.y / 50
        return e.angleDelta.y / 120
    }
    function lumAt(x, y, w, h, sw, sh) {
        const g = lumGrid
        if (!g || g.length < lumW * lumH || sw <= 0 || sh <= 0) return 0.3
        const x0 = Math.max(0, Math.min(lumW - 1, Math.floor(x / sw * lumW)))
        const x1 = Math.max(x0, Math.min(lumW - 1, Math.floor((x + w) / sw * lumW)))
        const y0 = Math.max(0, Math.min(lumH - 1, Math.floor(y / sh * lumH)))
        const y1 = Math.max(y0, Math.min(lumH - 1, Math.floor((y + h) / sh * lumH)))
        let s = 0, n = 0
        for (let j = y0; j <= y1; j++)
            for (let i = x0; i <= x1; i++) { s += g[j * lumW + i]; n++ }
        return n > 0 ? s / n : 0.3
    }
}
