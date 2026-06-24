import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string eventSummary: ""
    property string eventStart: ""
    property string eventEnd: ""
    property bool isLoading: true

    property int refreshInterval: (pluginData.refreshInterval || 30) * 1000
    property int pillMaxWidth: pluginData.pillMaxWidth || 160
    property bool dynamicWidth: pluginData.dynamicWidth ?? false
    property int lookAheadDays: pluginData.lookAheadDays || 1
    property int nowWindowMinutes: pluginData.nowWindowMinutes ?? 5

    property real countdownNow: Date.now()

    property real remainingMs: {
        if (!eventStart)
            return -1;
        var startMs = new Date(eventStart).getTime();
        return startMs - countdownNow;
    }

    property bool isNow: {
        if (nowWindowMinutes <= 0 || eventStart === "" || remainingMs > 0)
            return false;
        var startMs = new Date(eventStart).getTime();
        var endMs = eventEnd ? new Date(eventEnd).getTime() : startMs;
        var duration = endMs - startMs;
        var maxWindow = nowWindowMinutes * 60000;
        var nowWindow = duration < maxWindow ? duration : maxWindow;
        return countdownNow < startMs + nowWindow;
    }
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
        case "EVENT_END":
            eventEnd = val;
            break;
        }
    }

    Process {
        id: fetchProcess
        command: ["bash", root.scriptPath, String(root.lookAheadDays), String(root.nowWindowMinutes)]
        running: false

        stdout: SplitParser {
            onRead: data => root.parseLine(data.trim())
        }

        stderr: SplitParser {
            onRead: data => console.warn("[dcalUpcoming]", data)
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[dcalUpcoming] script exited:", exitCode, "summary:", root.eventSummary, "start:", root.eventStart)
            root.isLoading = false;
        }
    }

    Timer {
        interval: root.refreshInterval
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

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle"]);
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: hRow.implicitWidth
            implicitHeight: hRow.implicitHeight

            Row {
                id: hRow
                spacing: Theme.spacingXS

                DankIcon {
                    name: "calendar_today"
                    size: iconSize
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
                    width: root.dynamicWidth ? Math.min(implicitWidth, root.pillMaxWidth) : root.pillMaxWidth
                }

                StyledText {
                    text: "•"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.timeColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasEvent
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDcal()
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: vCol.implicitWidth
            implicitHeight: vCol.implicitHeight

            Column {
                id: vCol
                spacing: Theme.spacingXS || 4

                DankIcon {
                    name: "calendar_today"
                    size: iconSize
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

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDcal()
            }
        }
    }
}
