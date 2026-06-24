# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Dank Material Shell (DMS) plugin that displays the user's next calendar event from [dcal](https://github.com/AvengeMedia/dcal) with a live countdown timer in the DMS bar. Plugin ID: `dcalUpcoming`.

## Development

There is no build step, test suite, or linter. The plugin is pure QML + a bash helper script, loaded directly by the DMS plugin runtime.

**To test changes locally**, symlink or clone into the DMS plugins directory and reload:

```bash
# Plugin install path
~/.config/DankMaterialShell/plugins/dcalUpcoming/
```

Runtime dependencies: `dcal` (calendar daemon with IPC) and `jq`.

## Architecture

- **`plugin.json`** — DMS plugin manifest. Declares the widget component, settings component, required binaries, and permissions.
- **`DcalWidget.qml`** — Main widget. A `PluginComponent` that periodically shells out to `get-next-event`, parses the key=value output, and renders a countdown pill in both horizontal and vertical bar orientations. Clicking the pill toggles the dcal UI via `dcal ipc ui.toggle`.
- **`DcalSettings.qml`** — Settings panel. A `PluginSettings` form with three `SliderSetting` controls that write to `pluginData` (refreshInterval, pillMaxWidth, lookAheadDays).
- **`get-next-event`** — Bash script that calls `dcal ipc events.list` with a time window, pipes through `jq` to find the next upcoming (or currently-running-within-10min) event, and emits `EVENT_SUMMARY=`, `EVENT_START=`, `EVENT_END=` lines.

## DMS Plugin Conventions

QML files import from `qs.*` namespaces provided by DMS: `qs.Common` (Theme, StyledText), `qs.Widgets` (DankIcon, SliderSetting), `qs.Services` (PluginService), `qs.Modules.Plugins` (PluginComponent, PluginSettings). These are not standard Qt modules — they are DMS-specific and have no external documentation.

Settings are stored via `pluginData` (a persistent key-value store injected by PluginComponent). The widget reads settings as `pluginData.<key> || <default>`.

Widgets expose two pill templates: `horizontalBarPill` (Row layout) and `verticalBarPill` (Column layout). Both must be `Component` values assigned to PluginComponent properties.
