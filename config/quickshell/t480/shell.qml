import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

ShellRoot {
    id: root
    property var theme: ({background: "#0b0b0b", surface: "#151515", selection: "#353535", text: "#e0e0e0", muted: "#a0a0a0", border: "#353535", focus: "#bdbdbd", font: "JetBrainsMono Nerd Font Mono"})
    property var battery: ({percent: null, charging: false})
    property bool ready: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int volume: sink && sink.audio ? Math.round(sink.audio.volume * 100) : -1
    property real downloadRate: 0
    property real lastRx: -1
    property real lastRxTime: 0
    readonly property string batteryIcon: battery.percent === null ? "\uf128" :
        battery.percent >= 90 ? "\uf240" : battery.percent >= 65 ? "\uf241" :
        battery.percent >= 40 ? "\uf242" : battery.percent >= 15 ? "\uf243" : "\uf244"
    // Five pipe-separated fields let dwm draw and click each status pill.
    readonly property string status: "\uf1eb " + (Networking.wifiEnabled ? downloadRate.toFixed(2) + " MB/s" : "off")
        + "|\uf294 " + (adapter && adapter.enabled ? "on" : "off")
        + "|" + (sink && sink.audio && sink.audio.muted ? "\uf026 mute" : "\uf028 " + (volume < 0 ? "--" : volume + "%"))
        + "|" + batteryIcon + " " + (battery.percent === null ? "--" : battery.percent + "%" + (battery.charging ? "+" : ""))
        + "|" + Qt.formatDateTime(clock.date, "ddd HH:mm")

    Process {
        id: networkReader
        command: ["cat", "/sys/class/net/wlp3s0/statistics/rx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bytes = Number(text.trim());
                const now = Date.now();
                if (isFinite(bytes) && text.trim() !== "") {
                    if (root.lastRx >= 0 && now > root.lastRxTime && bytes >= root.lastRx)
                        root.downloadRate = (bytes - root.lastRx) / ((now - root.lastRxTime) / 1000) / 1000000;
                    else root.downloadRate = 0;
                    root.lastRx = bytes;
                    root.lastRxTime = now;
                } else { root.downloadRate = 0; root.lastRx = -1; }
            }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: if (!networkReader.running) networkReader.running = true }
    // Refresh even when values do not change, so long window titles scroll.
    Timer { interval: 1000; running: true; repeat: true; onTriggered: if (root.ready && !statusWriter.running) statusWriter.running = true }


    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/t480/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.theme = JSON.parse(text()); }
            catch (error) { console.warn("Theme JSON invalid; retaining last valid theme:", error); }
        }
    }
    Process {
        id: powerReader
        command: [Quickshell.env("HOME") + "/.local/bin/t480-power-state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.battery = JSON.parse(text); }
                catch (error) { console.warn("Battery status unavailable:", error); }
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: if (!powerReader.running) powerReader.running = true }
    Process { id: statusWriter; command: ["xsetroot", "-name", root.status] }
    Timer { id: statusDebounce; interval: 150; onTriggered: if (!statusWriter.running) statusWriter.running = true }
    onStatusChanged: if (ready) statusDebounce.restart()
    Component.onCompleted: {
        ready = true;
        themeFile.reload();
        powerReader.running = true;
        networkReader.running = true;
        statusDebounce.restart();
    }
    function launch(command) {
        Quickshell.execDetached(command);
        panel.visible = false;
    }
    property string osdKind: "volume"
    property int brightnessPercent: 0
    function showVolume() {
        osdKind = "volume";
        volumeOsd.visible = true;
        volumeHide.restart();
    }
    function showBrightness(percent) {
        osdKind = "brightness";
        brightnessPercent = Math.max(0, Math.min(100, percent));
        volumeOsd.visible = true;
        volumeHide.restart();
    }
    function changeVolume(delta) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1, Math.round((sink.audio.volume + delta) * 100) / 100));
        sink.audio.muted = false;
        showVolume();
    }
    function toggleMute() {
        if (!sink || !sink.audio) return;
        sink.audio.muted = !sink.audio.muted;
        showVolume();
    }
    Timer { id: volumeHide; interval: 1500; onTriggered: volumeOsd.visible = false }
    PanelWindow {
        id: volumeOsd
        visible: false
        anchors { top: true; right: true }
        margins { top: 48; right: 20 }
        implicitWidth: 260
        implicitHeight: 72
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        aboveWindows: true
        color: root.theme.background
        Rectangle {
            anchors.fill: parent
            color: root.theme.background
            border.color: root.theme.border
            border.width: 1
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.osdKind === "brightness" ? "Brightness" : (root.sink && root.sink.audio && root.sink.audio.muted ? "Muted" : "Volume")
                        color: root.theme.text
                        font.family: root.theme.font
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (root.osdKind === "brightness" ? root.brightnessPercent : Math.max(0, root.volume)) + "%"
                        color: root.theme.text
                        font.family: root.theme.font
                        font.pixelSize: 13
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    color: root.theme.selection
                    Rectangle {
                        height: parent.height
                        width: parent.width * (root.osdKind === "brightness" ? root.brightnessPercent : Math.max(0, Math.min(100, root.volume))) / 100
                        color: root.osdKind === "volume" && root.sink && root.sink.audio && root.sink.audio.muted ? root.theme.muted : root.theme.text
                    }
                }
            }
        }
    }
    IpcHandler {
        target: "controls"
        function toggle(): void { panel.visible = !panel.visible; }
        function openMenu(): void { panel.visible = true; }
        function closeMenu(): void { panel.visible = false; }
        function isOpen(): bool { return panel.visible; }
        function state(): string { return root.status; }
        function showBrightness(percent: int): void { root.showBrightness(percent); }
        function volumeUp(): void { root.changeVolume(0.05); }
        function volumeDown(): void { root.changeVolume(-0.05); }
        function toggleMute(): void { root.toggleMute(); }
    }
    SearchPanel { id: spotlight; theme: root.theme; mode: "launcher" }
    SearchPanel { id: keyguide; theme: root.theme; mode: "keys" }
    IpcHandler {
        target: "spotlight"
        function toggle(): void { keyguide.visible = false; spotlight.toggle(); }
        function close(): void { spotlight.visible = false; }
        function isOpen(): bool { return spotlight.visible; }
    }
    IpcHandler {
        target: "keyguide"
        function toggle(): void { spotlight.visible = false; keyguide.toggle(); }
        function close(): void { keyguide.visible = false; }
        function isOpen(): bool { return keyguide.visible; }
    }
    ClipboardPanel { id: clipboardPanel; theme: root.theme }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboardPanel.toggle(); }
        function close(): void { clipboardPanel.visible = false; }
        function info(): string { return JSON.stringify({open: clipboardPanel.visible, count: clipboardPanel.entries.length, index: clipboardPanel.currentIndex}); }
    }
    component Action: Button {
        Layout.fillWidth: true
        implicitHeight: 42
        padding: 12
        font.family: root.theme.font
        font.pixelSize: 13
        contentItem: Text {
            text: parent.text
            color: parent.enabled ? root.theme.text : root.theme.muted
            font: parent.font
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideRight
        }
        background: Rectangle {
            color: parent.down || parent.hovered || parent.visualFocus ? root.theme.selection : root.theme.surface
            border.color: parent.visualFocus ? root.theme.focus : root.theme.border
            border.width: 1
        }
    }
    FloatingWindow {
        id: panel
        title: "T480 Controls"
        visible: false
        implicitWidth: 440
        implicitHeight: 555
        minimumSize: Qt.size(440, 555)
        maximumSize: Qt.size(440, 555)
        color: root.theme.background
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12
            focus: true
            Keys.onEscapePressed: panel.visible = false
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 3
                    Text { text: Qt.formatDateTime(clock.date, "dddd, d MMMM"); color: root.theme.text; font.family: root.theme.font; font.pixelSize: 17 }
                    Text { text: "ThinkPad T480  /  " + (root.battery.percent === null ? "AC" : "Battery " + root.battery.percent + "%"); color: root.theme.muted; font.family: root.theme.font; font.pixelSize: 12 }
                }
                Item { Layout.fillWidth: true }
                Action { text: "Esc"; Layout.fillWidth: false; implicitWidth: 55; onClicked: panel.visible = false }
            }
            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true
                Action { text: "Wi-Fi / wifitui"; onClicked: root.launch([Quickshell.env("HOME") + "/.local/bin/t480-tui", "wifi"]) }
                Action { text: "Bluetooth / pair"; onClicked: root.launch([Quickshell.env("HOME") + "/.local/bin/t480-tui", "bluetooth"]) }
                Action { text: root.adapter && root.adapter.enabled ? "Bluetooth: on" : "Bluetooth: off"; enabled: root.adapter !== null; onClicked: root.adapter.enabled = !root.adapter.enabled }
                Action { text: "System / btop"; onClicked: root.launch([Quickshell.env("HOME") + "/.local/bin/t480-tui", "monitor"]) }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.border }
            RowLayout {
                Text { text: "Volume"; color: root.theme.text; font.family: root.theme.font; font.pixelSize: 13 }
                Slider {
                    Layout.fillWidth: true
                    from: 0; to: 1
                    enabled: root.sink !== null && root.sink.audio !== null
                    value: root.volume < 0 ? 0 : root.volume / 100
                    onMoved: if (root.sink && root.sink.audio) { root.sink.audio.volume = value; root.showVolume(); }
                    background: Rectangle { x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 2; width: parent.availableWidth; height: 4; color: root.theme.border }
                    handle: Rectangle { x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width); y: parent.topPadding + parent.availableHeight / 2 - height / 2; width: 10; height: 16; color: root.theme.text }
                }
                Text { text: root.volume < 0 ? "--" : root.volume + "%"; color: root.theme.muted; font.family: root.theme.font; font.pixelSize: 12 }
            }
            Action { text: root.sink && root.sink.audio && root.sink.audio.muted ? "Unmute audio" : "Mute audio"; enabled: root.sink !== null && root.sink.audio !== null; onClicked: root.toggleMute() }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.border }
            GridLayout {
                columns: 2; columnSpacing: 8; rowSpacing: 8
                Layout.fillWidth: true
                Action { text: "Files / PCManFM"; onClicked: root.launch(["pcmanfm"]) }
                Action { text: "Web / LibreWolf"; onClicked: root.launch(["librewolf-bin"]) }
                Action { text: "Codex"; onClicked: root.launch(["chatgpt"]) }
                Action { text: "LocalSend"; onClicked: root.launch(["localsend"]) }
            }
            Item { Layout.fillHeight: true }
            Text { text: "Super+P controls  /  Super+Return terminal"; color: root.theme.muted; font.family: root.theme.font; font.pixelSize: 11 }
        }
    }
}
