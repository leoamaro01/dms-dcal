import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

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
    property bool showTooltip: pluginData.showTooltip ?? true
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
    property string timeText: formatTimeRemaining()
    property color timeColor: isNow ? "#66BB6A" : Theme.surfaceText
    property string scriptPath: PluginService.pluginDirectory + "/dcalUpcoming/get-next-event"

    pillClickAction: () => toggleDcal() 

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

    function parseLine(line) {
        var idx = line.indexOf("=");
        if (idx < 0)
            return ;

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

    function toggleDcal() {
        Quickshell.execDetached(["dcal", "ipc", "ui.toggle", "view=day"]);
    }

    Process {
        id: fetchProcess

        command: ["bash", root.scriptPath, String(root.lookAheadDays), String(root.nowWindowMinutes)]
        running: false
        onExited: (exitCode, exitStatus) => {
            console.log("[dcalUpcoming] script exited:", exitCode, "summary:", root.eventSummary, "start:", root.eventStart);
            root.isLoading = false;
        }

        stdout: SplitParser {
            onRead: (data) => {
                return root.parseLine(data.trim());
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("[dcalUpcoming]", data);
            }
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

    function showEventTooltip(pill) {
        if (!root.showTooltip || !pill || !root.parentScreen)
            return ;

        var screen = root.parentScreen;
        var edge = root.axis?.edge ?? (root.isVertical ? "left" : "top");
        var gap = (root.barConfig?.spacing ?? 4) + Theme.spacingXS;
        var center = pill.mapToItem(null, pill.width / 2, pill.height / 2);
        var side, anchorX, anchorY;
        if (edge === "left") {
            side = "right";
            anchorX = root.barThickness + gap;
            anchorY = center.y;
        } else if (edge === "right") {
            side = "left";
            anchorX = screen.width - root.barThickness - gap;
            anchorY = center.y;
        } else if (edge === "bottom") {
            side = "top";
            anchorX = center.x;
            anchorY = screen.height - root.barThickness - gap;
        } else {
            side = "bottom";
            anchorX = center.x;
            anchorY = root.barThickness + gap;
        }
        // Stash the target so onLoaded can show it if the PanelWindow's Wayland
        // surface isn't ready synchronously on first activation.
        eventTooltipLoader.pendingX = anchorX;
        eventTooltipLoader.pendingY = anchorY;
        eventTooltipLoader.pendingScreen = screen;
        eventTooltipLoader.pendingSide = side;
        eventTooltipLoader.pendingShow = true;
        eventTooltipLoader.active = true;
        if (eventTooltipLoader.item)
            eventTooltipLoader.item.showAt(anchorX, anchorY, screen, side);
    }

    function hideEventTooltip() {
        eventTooltipLoader.pendingShow = false;
        if (eventTooltipLoader.item)
            eventTooltipLoader.item.hideTip();
        // Tear down the Wayland surface instead of leaving it hidden for the session.
        eventTooltipLoader.active = false;
    }

    Loader {
        id: eventTooltipLoader

        active: false

        property real pendingX: 0
        property real pendingY: 0
        property var pendingScreen: null
        property string pendingSide: "right"
        property bool pendingShow: false

        onLoaded: if (pendingShow)
            item.showAt(pendingX, pendingY, pendingScreen, pendingSide)

        sourceComponent: PanelWindow {
            id: ttip

            property real targetX: 0
            property real targetY: 0
            property string side: "right"

            function showAt(x, y, scr, placement) {
                ttip.screen = scr ?? null;
                targetX = x;
                targetY = y;
                side = placement;
                visible = true;
            }

            function hideTip() {
                visible = false;
            }

            WlrLayershell.namespace: "dms:plugins:dcal-tooltip"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            color: "transparent"
            visible: false
            implicitWidth: ttBg.implicitWidth
            implicitHeight: ttBg.implicitHeight
            // Empty input region: the tooltip is purely visual and never steals
            // clicks from the pill underneath it.
            mask: Region {
            }

            anchors {
                top: true
                left: true
            }

            margins {
                left: {
                    var sw = ttip.screen?.width ?? Screen.width;
                    var lx;
                    if (ttip.side === "right")
                        lx = ttip.targetX;
                    else if (ttip.side === "left")
                        lx = ttip.targetX - ttip.implicitWidth;
                    else
                        lx = ttip.targetX - ttip.implicitWidth / 2;
                    return Math.round(Math.max(Theme.spacingS, Math.min(sw - ttip.implicitWidth - Theme.spacingS, lx)));
                }
                top: {
                    var sh = ttip.screen?.height ?? Screen.height;
                    var ty;
                    if (ttip.side === "bottom")
                        ty = ttip.targetY;
                    else if (ttip.side === "top")
                        ty = ttip.targetY - ttip.implicitHeight;
                    else
                        ty = ttip.targetY - ttip.implicitHeight / 2;
                    return Math.round(Math.max(Theme.spacingS, Math.min(sh - ttip.implicitHeight - Theme.spacingS, ty)));
                }
            }

            Rectangle {
                id: ttBg

                implicitWidth: ttCol.width + Theme.spacingM * 2
                implicitHeight: ttCol.implicitHeight + Theme.spacingS * 2
                color: Theme.withAlpha(Theme.surfaceContainerHigh, root.barConfig?.transparency ?? 1)
                radius: Theme.cornerRadius
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                Column {
                    id: ttCol

                    x: Theme.spacingM
                    y: Theme.spacingS
                    // Scale with the theme font so the tooltip stays sensible
                    // across DPI / screen sizes instead of a fixed pixel width.
                    width: Math.round(Theme.fontSizeSmall * 18)
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: root.hasEvent ? root.eventSummary : "No events"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        width: parent.width
                        visible: root.hasEvent && root.timeText !== ""
                        text: root.isNow ? "Happening now" : ("Starts in " + root.timeText)
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.timeColor
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

    }

    horizontalBarPill: Component {
        Item {
            id: hPill

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

                Item {
                    id: summaryClip

                    width: root.dynamicWidth ? Math.min(summaryText.implicitWidth, root.pillMaxWidth) : root.pillMaxWidth
                    height: summaryText.implicitHeight
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    property real overflow: Math.max(0, summaryText.implicitWidth - width)

                    StyledText {
                        id: summaryText

                        text: root.hasEvent ? root.eventSummary : "No events"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    SequentialAnimation {
                        running: summaryClip.overflow > 0
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) summaryText.x = 0

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            target: summaryText
                            property: "x"
                            to: -summaryClip.overflow
                            duration: summaryClip.overflow * 25
                            easing.type: Easing.Linear
                        }

                        PauseAnimation { duration: 1500 }

                        NumberAnimation {
                            target: summaryText
                            property: "x"
                            to: 0
                            duration: 300
                        }

                    }

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

            // Hover shows the full event in the same tooltip (handy when the
            // summary is mid-scroll). A HoverHandler is passive: unlike a
            // MouseArea it doesn't consume the hover, so the bar pill keeps its
            // own highlight + pointing-hand cursor and its pillClickAction.
            HoverHandler {
                enabled: root.showTooltip
                onHoveredChanged: hovered ? root.showEventTooltip(hPill) : root.hideEventTooltip()
            }

        }

    }

    verticalBarPill: Component {
        Item {
            id: vPill

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

                // Compact countdown so it fits a narrow vertical bar. The event
                // summary (which scrolls on the horizontal pill) is shown in a
                // hover tooltip instead.
                StyledText {
                    width: root.widgetThickness
                    text: root.timeText
                    font.pixelSize: Math.max(8, Math.round(Theme.fontSizeSmall * 0.7))
                    font.weight: Font.Medium
                    color: root.timeColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hasEvent
                }

            }

            // Hover shows the full event in a custom tooltip beside the bar.
            // HoverHandler is passive so the bar's own click (pillClickAction)
            // still toggles dcal and the pill keeps its highlight + cursor.
            HoverHandler {
                enabled: root.showTooltip
                onHoveredChanged: hovered ? root.showEventTooltip(vPill) : root.hideEventTooltip()
            }

        }

    }

}
