# Reagentr

A Mac desktop widget for dated to-dos that your agents (Claude Code, Codex, any MCP client, or a shell script) can write to. A to-do set for a future day stays hidden until that day, then shows up on the widget and notifies you.

## Build and install

Requires macOS 26, Xcode 26, and XcodeGen.

```sh
xcodegen generate
xcodebuild -project Reagentr.xcodeproj -scheme Reagentr -configuration Release \
  -derivedDataPath build/dd -clonedSourcePackagesDirPath build/spm -allowProvisioningUpdates build
ditto build/dd/Build/Products/Release/Reagentr.app ~/Applications/Reagentr.app
open ~/Applications/Reagentr.app
```

Signing uses `DEVELOPMENT_TEAM` in `project.yml`. Widgets and App Groups need a real team, so a "Sign to Run Locally" build won't load the widget.

Then right-click the desktop, choose Edit Widgets, and add Reagentr.

## Connect an agent

Open the menu bar popover and click the bolt button for copy-paste snippets, or use these:

```sh
claude mcp add --scope user reagentr -- ~/Applications/Reagentr.app/Contents/Helpers/reagentr mcp
codex mcp add reagentr -- ~/Applications/Reagentr.app/Contents/Helpers/reagentr mcp
```

MCP tools: `add_todo`, `list_todos`, `update_todo`, `complete_todo`, `delete_todo`, and `current_time`.

## Shell

```sh
reagentr add "Renew the domain" --date 2026-11-03 [--time 17:00] [--source NAME]
reagentr list [today|upcoming|done|all]
reagentr done <id> | undo <id> | rm <id>
reagentr edit <id> [--title T] [--date D | --no-date] [--time T | --no-time]
```

## Layout

- `Packages/ReagentrKit`: the model, JSON store, date logic, wire protocol, and CLI parsing. Run its tests with `swift test`.
- `App/`: the menu bar app. It's the single writer for agents and owns the Unix socket, notifications, and widget reloads.
- `Widget/`: the WidgetKit extension, with an interactive check-off.
- `CLI/`: the `reagentr` binary (CLI and stdio MCP server), embedded at `Reagentr.app/Contents/Helpers/reagentr`.
- `docs/`: requirements, plan, and the visual/motion spec.
