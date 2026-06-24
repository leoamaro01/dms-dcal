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

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "How often to fetch the next event (seconds)"
        defaultValue: 30
        minimum: 10
        maximum: 120
        unit: "sec"
        leftIcon: "schedule"
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
