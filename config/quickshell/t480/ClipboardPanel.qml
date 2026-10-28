import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: picker
    property var theme
    property var entries: []
    property string pasteTarget: "0x0"
    property bool hadFocus: false
    property alias currentIndex: list.currentIndex
    title: "T480 Clipboard"
    visible: false
    implicitWidth: 420
    implicitHeight: 420
    minimumSize: Qt.size(420, 420)
    maximumSize: Qt.size(420, 420)
    color: theme.background

    function toggle() {
        if (visible) { visible = false; return; }
        if (!focusQuery.running) focusQuery.running = true;
    }
    function pasteItem(index) {
        if (pasteProcess.running || index < 0 || index >= entries.length) return;
        let key = entries[index].id;
        visible = false;
        pasteProcess.command = [Quickshell.env("HOME") + "/.local/bin/t480-clipboard", "paste", key, pasteTarget];
        pasteProcess.running = true;
    }
    function move(amount) {
        if (entries.length === 0) return;
        list.currentIndex = Math.max(0, Math.min(entries.length - 1, list.currentIndex + amount));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    onVisibleChanged: {
        if (visible) {
            hadFocus = false;
            indexFile.reload();
            list.currentIndex = 0;
            content.forceActiveFocus();
        }
    }
    Connections {
        target: content.Window.window
        function onActiveChanged() {
            if (!picker.visible) return;
            if (content.Window.active) picker.hadFocus = true;
            else if (picker.hadFocus) picker.visible = false;
        }
    }
    Process {
        id: initialize
        command: [Quickshell.env("HOME") + "/.local/bin/t480-clipboard", "location"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let directory = text.trim();
                if (directory.length > 0) {
                    indexFile.path = directory + "/index.json";
                    indexFile.reload();
                }
            }
        }
    }
    FileView {
        id: indexFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { picker.entries = JSON.parse(text()); }
            catch (error) { console.warn("Clipboard index unavailable:", error); }
        }
    }
    Process {
        id: focusQuery
        command: [Quickshell.env("HOME") + "/.local/bin/t480-keys", "active"]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.pasteTarget = text.trim();
                picker.visible = true;
            }
        }
    }
    Process { id: pasteProcess }
    Rectangle {
        anchors.fill: parent
        color: picker.theme.background
        border.width: 1
        border.color: picker.theme.border
        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_J || event.key === Qt.Key_Down) picker.move(1);
                else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) picker.move(-1);
                else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) picker.move(picker.entries.length);
                else if (event.key === Qt.Key_G) picker.move(-picker.entries.length);
                else if (event.key === Qt.Key_D && (event.modifiers & Qt.ControlModifier)) picker.move(5);
                else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) picker.move(-5);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) picker.pasteItem(list.currentIndex);
                else if (event.key === Qt.Key_Escape) picker.visible = false;
                else return;
                event.accepted = true;
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Clipboard"; color: picker.theme.text; font.family: picker.theme.font; font.pixelSize: 15 }
                Item { Layout.fillWidth: true }
                Text { text: picker.entries.length + " / 20"; color: picker.theme.muted; font.family: picker.theme.font; font.pixelSize: 12 }
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: picker.entries
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 58
                    color: ListView.isCurrentItem ? picker.theme.selection : picker.theme.surface
                    border.color: ListView.isCurrentItem ? picker.theme.focus : picker.theme.border
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10
                        Image {
                            visible: modelData.kind === "image"
                            Layout.preferredWidth: 62
                            Layout.preferredHeight: 40
                            source: modelData.kind === "image" ? "file://" + modelData.image : ""
                            sourceSize: Qt.size(124, 80)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.kind === "image" ? "Image  " + modelData.width + " × " + modelData.height : modelData.text.replace(/\s+/g, " ")
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: picker.theme.text
                            font.family: picker.theme.font
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: picker.pasteItem(index)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: picker.entries.length === 0
                    text: "Copy something to get started"
                    color: picker.theme.muted
                    font.family: picker.theme.font
                    font.pixelSize: 12
                }
            }
            Text { text: "j/k move   Enter paste   Esc close"; color: picker.theme.muted; font.family: picker.theme.font; font.pixelSize: 11 }
        }
    }
}
