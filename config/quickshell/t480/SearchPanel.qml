import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: searchWindow
    property var theme
    property string mode: "launcher"
    property var entries: []
    property bool hadFocus: false
    property bool refreshPending: false
    property string searchedText: ""
    property bool scanning: false
    property bool indexLimited: false
    property string notice: ""
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/t480-search"
    title: mode === "keys" ? "T480 Shortcuts" : "T480 Spotlight"
    visible: false
    implicitWidth: 680
    implicitHeight: 490
    minimumSize: Qt.size(680, 490)
    maximumSize: Qt.size(680, 490)
    color: theme.background

    function toggle() {
        if (visible) { visible = false; return; }
        visible = true;
    }
    function refresh() {
        if (!visible) return;
        if (searchProcess.running) { refreshPending = true; return; }
        refreshPending = false;
        searchedText = query.text;
        searchProcess.command = [helper, "search", mode, searchedText];
        searchProcess.running = true;
    }
    function move(amount) {
        if (!entries.length) return;
        results.currentIndex = Math.max(0, Math.min(entries.length - 1, results.currentIndex + amount));
        results.positionViewAtIndex(results.currentIndex, ListView.Contain);
    }
    function activate(index) {
        if (index < 0 || index >= entries.length || mode === "keys") return;
        const entry = entries[index];
        visible = false;
        Quickshell.execDetached([helper, "launch", entry.kind, entry.target]);
    }
    onVisibleChanged: {
        if (visible) {
            hadFocus = false;
            notice = "";
            query.text = "";
            entries = [];
            results.currentIndex = 0;
            query.forceActiveFocus();
            if (mode === "launcher" && !indexer.running) {
                scanning = true;
                indexer.running = true;
            }
            searchDelay.restart();
        } else {
            searchDelay.stop();
        }
    }
    Connections {
        target: body.Window.window
        function onActiveChanged() {
            if (!searchWindow.visible) return;
            if (body.Window.active) searchWindow.hadFocus = true;
            else if (searchWindow.hadFocus) searchWindow.visible = false;
        }
    }
    Timer { id: searchDelay; interval: 120; onTriggered: searchWindow.refresh() }
    Process {
        id: indexer
        command: [searchWindow.helper, "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const result = JSON.parse(text); searchWindow.indexLimited = result.limited === true; }
                catch (error) { console.warn("File index unavailable:", error); }
            }
        }
        onExited: (exitCode, exitStatus) => {
            searchWindow.scanning = false;
            if (exitCode !== 0) { searchWindow.notice = "File index unavailable"; console.warn("File index failed:", exitCode); }
            if (searchWindow.visible) searchDelay.restart();
        }
    }
    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (!searchWindow.visible || searchWindow.searchedText !== query.text) return;
                try {
                    const result = JSON.parse(text);
                    searchWindow.entries = Array.isArray(result) ? result : [];
                    if (!Array.isArray(result)) searchWindow.notice = "Search unavailable";
                    else if (searchWindow.notice === "Search unavailable") searchWindow.notice = "";
                    results.currentIndex = 0;
                } catch (error) { searchWindow.entries = []; console.warn("Search failed:", error); }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (searchWindow.visible && (searchWindow.refreshPending || searchWindow.searchedText !== query.text))
                searchDelay.restart();
        }
    }
    Rectangle {
        anchors.fill: parent
        color: searchWindow.theme.background
        border.color: searchWindow.theme.border
        border.width: 1
        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: searchWindow.mode === "keys" ? "Keyboard shortcuts" : "Spotlight"
                    color: searchWindow.theme.text
                    font.family: searchWindow.theme.font
                    font.pixelSize: 16
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: searchWindow.notice || (searchWindow.scanning ? "Indexing files…" : (searchWindow.indexLimited ? "First 30,000 files" : "Esc to close"))
                    color: searchWindow.theme.muted
                    font.family: searchWindow.theme.font
                    font.pixelSize: 11
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                color: searchWindow.theme.surface
                border.color: query.activeFocus ? searchWindow.theme.focus : searchWindow.theme.border
                border.width: 1
                TextInput {
                    id: query
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    color: searchWindow.theme.text
                    selectionColor: searchWindow.theme.selection
                    selectedTextColor: searchWindow.theme.text
                    font.family: searchWindow.theme.font
                    font.pixelSize: 14
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    focus: true
                    onTextChanged: searchDelay.restart()
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) searchWindow.visible = false;
                        else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier))) searchWindow.move(1);
                        else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) searchWindow.move(-1);
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) searchWindow.activate(results.currentIndex);
                        else return;
                        event.accepted = true;
                    }
                    Text {
                        anchors.fill: parent
                        visible: query.text.length === 0
                        text: searchWindow.mode === "keys" ? "Search shortcuts…" : "Search apps and files…"
                        color: searchWindow.theme.muted
                        font: query.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: searchWindow.entries
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: results.width
                    height: 48
                    color: ListView.isCurrentItem ? searchWindow.theme.selection : searchWindow.theme.background
                    border.color: ListView.isCurrentItem ? searchWindow.theme.border : "transparent"
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12
                        Text {
                            text: modelData.kind === "app" ? "APP" : modelData.kind === "folder" ? "DIR" : modelData.kind === "file" ? "FILE" : "KEY"
                            color: searchWindow.theme.muted
                            font.family: searchWindow.theme.font
                            font.pixelSize: 10
                            Layout.preferredWidth: 38
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { Layout.fillWidth: true; text: modelData.name; textFormat: Text.PlainText; elide: Text.ElideMiddle; color: searchWindow.theme.text; font.family: searchWindow.theme.font; font.pixelSize: 13 }
                            Text { Layout.fillWidth: true; text: modelData.detail; textFormat: Text.PlainText; elide: Text.ElideMiddle; color: searchWindow.theme.muted; font.family: searchWindow.theme.font; font.pixelSize: 10 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: results.currentIndex = index
                        onClicked: searchWindow.activate(index)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: searchWindow.entries.length === 0
                    text: searchWindow.scanning && searchWindow.mode === "launcher" ? "Searching apps · indexing files…" : "No results"
                    color: searchWindow.theme.muted
                    font.family: searchWindow.theme.font
                    font.pixelSize: 12
                }
            }
            Text {
                text: searchWindow.mode === "keys" ? "Type to filter  ·  ↑/↓ move  ·  Esc close" : "Type to search  ·  ↑/↓ move  ·  Enter open  ·  Esc close"
                color: searchWindow.theme.muted
                font.family: searchWindow.theme.font
                font.pixelSize: 11
            }
        }
    }
}
