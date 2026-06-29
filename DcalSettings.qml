import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "dcalUpcoming"

    property var availableCalendars: []
    property bool calendarsLoaded: false
    property string expandedVariantId: ""
    property bool showAddForm: false
    property var newInstanceCalendarIds: []

    function calendarSummary(calendarIds) {
        if (!calendarIds || calendarIds.length === 0)
            return "All calendars";
        var names = [];
        for (var i = 0; i < calendarIds.length; i++) {
            var found = false;
            for (var j = 0; j < availableCalendars.length; j++) {
                if (availableCalendars[j].id === calendarIds[i]) {
                    names.push(availableCalendars[j].name);
                    found = true;
                    break;
                }
            }
            if (!found)
                names.push(calendarIds[i].substring(0, 8) + "…");
        }
        return names.join(", ");
    }

    function toggleInList(calId, list) {
        var newList = list.slice();
        var idx = newList.indexOf(calId);
        if (idx >= 0)
            newList.splice(idx, 1);
        else
            newList.push(calId);
        return newList;
    }

    Process {
        id: calendarProcess
        command: ["dcal", "ipc", "calendars.list"]
        running: false
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => { calendarProcess.buffer += data + "\n" }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && calendarProcess.buffer) {
                try {
                    var parsed = JSON.parse(calendarProcess.buffer);
                    root.availableCalendars = parsed.filter(function(c) { return !c.hidden; });
                } catch(e) {
                    console.warn("[dcalUpcoming] Failed to parse calendars:", e);
                }
            }
            root.calendarsLoaded = true;
            calendarProcess.buffer = "";
        }
    }

    Component.onCompleted: {
        calendarProcess.running = true;
    }

    // ── Header ──

    StyledText {
        width: parent.width
        text: "Dcal Upcoming Event"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Shows your next calendar event from dcal with a live countdown. Click the widget to toggle the dcal UI."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── General Settings ──

    Item {
        width: parent.width
        implicitHeight: refreshSlider.implicitHeight

        SliderSetting {
            id: refreshSlider
            anchors.left: parent.left
            anchors.right: refreshInputBox.left
            anchors.rightMargin: 8
            settingKey: "refreshInterval"
            label: "Refresh Interval"
            description: "How often to fetch the next event (seconds)"
            defaultValue: 30
            minimum: 10
            maximum: 600
            unit: "sec"
            leftIcon: "schedule"
        }

        Connections {
            target: refreshSlider
            function onValueChanged() {
                if (!refreshInput.activeFocus)
                    refreshInput.text = refreshSlider.value.toString()
            }
        }

        Rectangle {
            id: refreshInputBox
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: 56
            height: 28
            radius: 6
            color: Theme.surfaceContainerHighest
            border.color: refreshInput.activeFocus ? Theme.primary : Theme.outline

            TextInput {
                id: refreshInput
                anchors.fill: parent
                anchors.margins: 4
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                selectByMouse: true
                validator: IntValidator { bottom: 10; top: 600 }
                Component.onCompleted: text = refreshSlider.value.toString()
                onAccepted: { applyValue(); focus = false }
                Keys.onEscapePressed: { text = refreshSlider.value.toString(); focus = false }
                onActiveFocusChanged: {
                    if (!activeFocus) applyValue()
                }
                function applyValue() {
                    var val = parseInt(text)
                    if (!isNaN(val) && val >= 10 && val <= 600)
                        refreshSlider.value = val
                    else
                        text = refreshSlider.value.toString()
                }
            }
        }
    }

    ToggleSetting {
        settingKey: "dynamicWidth"
        label: "Dynamic Width"
        description: "Shrink the widget to fit the event name instead of using a fixed width"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showTooltip"
        label: "Hover Tooltip"
        description: "Show the full event summary in a tooltip when hovering the widget"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pillMaxWidth"
        label: "Event Name Width"
        description: "Maximum width for the event name in the bar (pixels)"
        defaultValue: 160
        minimum: 80
        maximum: 300
        unit: "px"
        leftIcon: "width"
    }

    SliderSetting {
        settingKey: "nowWindowMinutes"
        label: "Now Duration"
        description: "How long to show 'Now' after an event starts (0 to disable)"
        defaultValue: 5
        minimum: 0
        maximum: 30
        unit: "min"
        leftIcon: "timelapse"
    }

    SliderSetting {
        settingKey: "lookAheadDays"
        label: "Look Ahead"
        description: "How many days ahead to check for events"
        defaultValue: 1
        minimum: 1
        maximum: 7
        unit: "days"
        leftIcon: "date_range"
    }

    // ── Calendar Filter ──

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Calendar Filter"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Choose which calendars to show events from. This applies when the widget is added directly (without creating instances below)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledText {
        width: parent.width
        visible: !root.calendarsLoaded
        text: "Loading calendars…"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    StyledText {
        width: parent.width
        visible: root.calendarsLoaded && root.availableCalendars.length === 0
        text: "No calendars found. Make sure dcal is running."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.calendarsLoaded && root.availableCalendars.length > 0

        DankToggle {
            width: parent.width
            text: "All Calendars"
            description: "Show events from every calendar"
            checked: {
                var ids = root.loadValue("calendarIds", []);
                return !Array.isArray(ids) || ids.length === 0;
            }
            onToggled: isChecked => {
                if (isChecked) {
                    root.saveValue("calendarIds", []);
                } else {
                    var allIds = [];
                    for (var i = 0; i < root.availableCalendars.length; i++)
                        allIds.push(root.availableCalendars[i].id);
                    root.saveValue("calendarIds", allIds);
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: {
                var ids = root.loadValue("calendarIds", []);
                return Array.isArray(ids) && ids.length > 0;
            }

            Repeater {
                model: root.availableCalendars

                DankToggle {
                    required property var modelData
                    width: parent.width
                    text: modelData.name
                    description: modelData.accountName || ""
                    checked: {
                        var ids = root.loadValue("calendarIds", []);
                        return Array.isArray(ids) && ids.indexOf(modelData.id) !== -1;
                    }
                    onToggled: isChecked => {
                        var ids = root.loadValue("calendarIds", []);
                        if (!Array.isArray(ids)) ids = [];
                        ids = root.toggleInList(modelData.id, ids);
                        if (ids.length === 0) {
                            var allIds = [];
                            for (var i = 0; i < root.availableCalendars.length; i++)
                                allIds.push(root.availableCalendars[i].id);
                            ids = allIds;
                        }
                        root.saveValue("calendarIds", ids);
                    }
                }
            }
        }
    }

    // ── Widget Instances ──

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Widget Instances"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Create named instances with different calendar filters. Each instance appears as a separate widget you can add to your bar. When instances exist, only they appear in the widget picker (not the base widget)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.variants

            Column {
                required property var modelData
                required property int index
                width: parent.width
                spacing: 0

                property string vId: modelData.id
                property string vName: modelData.name
                property var vCalendarIds: modelData.calendarIds || []
                property bool expanded: root.expandedVariantId === vId

                Rectangle {
                    width: parent.width
                    height: variantHeader.implicitHeight + Theme.spacingM * 2
                    radius: expanded ? Theme.cornerRadius : Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Row {
                        id: variantHeader
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Column {
                            width: parent.width - expandBtn.width - deleteBtn.width - Theme.spacingS * 2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: vName
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: root.calendarSummary(vCalendarIds)
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }

                        DankActionButton {
                            id: expandBtn
                            iconName: expanded ? "expand_less" : "expand_more"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.expandedVariantId = expanded ? "" : vId
                        }

                        DankActionButton {
                            id: deleteBtn
                            iconName: "delete"
                            iconColor: Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: {
                                if (root.expandedVariantId === vId)
                                    root.expandedVariantId = "";
                                root.removeVariant(vId);
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: expanded
                    topPadding: Theme.spacingS
                    leftPadding: Theme.spacingM

                    DankToggle {
                        width: parent.width - Theme.spacingM
                        text: "All Calendars"
                        checked: vCalendarIds.length === 0
                        onToggled: isChecked => {
                            if (isChecked) {
                                root.updateVariant(vId, { calendarIds: [] });
                            } else {
                                var allIds = [];
                                for (var i = 0; i < root.availableCalendars.length; i++)
                                    allIds.push(root.availableCalendars[i].id);
                                root.updateVariant(vId, { calendarIds: allIds });
                            }
                        }
                    }

                    Column {
                        width: parent.width - Theme.spacingM
                        spacing: Theme.spacingXS
                        visible: vCalendarIds.length > 0

                        Repeater {
                            model: root.availableCalendars

                            DankToggle {
                                required property var modelData
                                width: parent.width
                                text: modelData.name
                                description: modelData.accountName || ""
                                checked: vCalendarIds.indexOf(modelData.id) !== -1
                                onToggled: isChecked => {
                                    var newIds = root.toggleInList(modelData.id, vCalendarIds);
                                    if (newIds.length === 0) {
                                        var allIds = [];
                                        for (var i = 0; i < root.availableCalendars.length; i++)
                                            allIds.push(root.availableCalendars[i].id);
                                        newIds = allIds;
                                    }
                                    root.updateVariant(vId, { calendarIds: newIds });
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Add Instance Form ──

    DankButton {
        visible: !root.showAddForm && root.calendarsLoaded && root.availableCalendars.length > 0
        text: "Add Instance"
        iconName: "add"
        onClicked: {
            root.newInstanceCalendarIds = [];
            root.showAddForm = true;
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.showAddForm

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.15
        }

        DankTextField {
            id: newInstanceName
            width: parent.width
            placeholderText: "Instance name (e.g. Work, Personal)"
            leftIconName: "label"
        }

        StyledText {
            text: "Calendars"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        DankToggle {
            width: parent.width
            text: "All Calendars"
            checked: root.newInstanceCalendarIds.length === 0
            onToggled: isChecked => {
                if (isChecked) {
                    root.newInstanceCalendarIds = [];
                } else {
                    var allIds = [];
                    for (var i = 0; i < root.availableCalendars.length; i++)
                        allIds.push(root.availableCalendars[i].id);
                    root.newInstanceCalendarIds = allIds;
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: root.newInstanceCalendarIds.length > 0

            Repeater {
                model: root.availableCalendars

                DankToggle {
                    required property var modelData
                    width: parent.width
                    text: modelData.name
                    description: modelData.accountName || ""
                    checked: root.newInstanceCalendarIds.indexOf(modelData.id) !== -1
                    onToggled: isChecked => {
                        root.newInstanceCalendarIds = root.toggleInList(modelData.id, root.newInstanceCalendarIds);
                        if (root.newInstanceCalendarIds.length === 0) {
                            var allIds = [];
                            for (var i = 0; i < root.availableCalendars.length; i++)
                                allIds.push(root.availableCalendars[i].id);
                            root.newInstanceCalendarIds = allIds;
                        }
                    }
                }
            }
        }

        Row {
            spacing: Theme.spacingS

            DankButton {
                text: "Create"
                enabled: newInstanceName.text.trim() !== ""
                onClicked: {
                    root.createVariant(newInstanceName.text.trim(), {
                        calendarIds: root.newInstanceCalendarIds
                    });
                    newInstanceName.text = "";
                    root.newInstanceCalendarIds = [];
                    root.showAddForm = false;
                }
            }

            DankButton {
                text: "Cancel"
                backgroundColor: Theme.surfaceVariant
                textColor: Theme.surfaceText
                onClicked: {
                    newInstanceName.text = "";
                    root.newInstanceCalendarIds = [];
                    root.showAddForm = false;
                }
            }
        }
    }
}
