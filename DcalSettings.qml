import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dcalUpcoming"

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
}
