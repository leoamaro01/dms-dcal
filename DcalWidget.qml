import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string eventSummary: ""
    property string eventStart: ""
    property bool isLoading: true

    property real countdownNow: Date.now()

    property real remainingMs: {
        if (!eventStart)
            return -1;
        var startMs = new Date(eventStart).getTime();
        return startMs - countdownNow;
    }

    property bool isNow: eventStart !== "" && remainingMs <= 0
    property bool isLessThanOneMin: !isNow && remainingMs > 0 && remainingMs < 60000
    property bool hasEvent: eventSummary !== ""

    function formatTimeRemaining() {
        if (!hasEvent)
            return "";
        if (isNow)
            return "Now";
        if (isLessThanOneMin)
            return "<1m";
        if (remainingMs < 0)
            return "";

        var totalMinutes = Math.floor(remainingMs / 60000);
        var days = Math.floor(totalMinutes / 1440);
        var hours = Math.floor((totalMinutes % 1440) / 60);
        var minutes = totalMinutes % 60;

        var parts = [];
        if (days > 0)
            parts.push(days + "d");
        if (hours > 0)
            parts.push(hours + "h");
        if (minutes > 0)
            parts.push(minutes + "m");

        return parts.join("") || "<1m";
    }

    property string timeText: formatTimeRemaining()
    property color timeColor: isNow ? "#66BB6A" : Theme.surfaceText

    property string scriptPath: PluginService.pluginDirectory + "/dcalUpcoming/get-next-event"

    function parseLine(line) {
        var idx = line.indexOf("=");
        if (idx < 0)
            return;
        var key = line.substring(0, idx);
        var val = line.substring(idx + 1);

        switch (key) {
        case "EVENT_SUMMARY":
            eventSummary = val;
            break;
        case "EVENT_START":
            eventStart = val;
            break;
        }
    }

    Process {
        id: fetchProcess
        command: ["bash", root.scriptPath]
        running: false

        stdout: SplitParser {
            onRead: data => root.parseLine(data.trim())
        }

        onExited: (exitCode, exitStatus) => {
            root.isLoading = false;
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchProcess.running)
                fetchProcess.running = true;
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.countdownNow = Date.now();
        }
    }

    Process {
        id: toggleProcess
        command: ["dcal", "ipc", "ui.toggle"]
        running: false
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleProcess.running = true
            }

            DankIcon {
                name: "calendar_today"
                size: 16
                color: root.hasEvent ? root.timeColor : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.hasEvent ? root.eventSummary : "No events"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, 160)
            }

            StyledText {
                text: root.timeText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.timeColor
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasEvent
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS || 4

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleProcess.running = true
            }

            DankIcon {
                name: "calendar_today"
                size: 16
                color: root.hasEvent ? root.timeColor : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.timeText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.timeColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.hasEvent
            }
        }
    }
}
