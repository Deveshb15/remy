# Remy

A Mac desktop widget for dated to-dos that your agents (Claude Code, Codex, any MCP client, or a shell script) can write to. A to-do set for a future day stays hidden until that day, then shows up on the widget and notifies you.

## Install

Open `Remy.dmg` and drag Remy to Applications. On first launch, onboarding takes over from there:

1. **Move.** If Remy is running from the disk image, it moves itself to Applications first.
2. **Connect.** Remy finds Claude Code, Codex, Gemini CLI, opencode, Claude, Cursor, Windsurf, VS Code, and LM Studio, and connects them in one click. Every settings file it edits gets a one-time `.remy-backup` copy, and files it can't safely parse are left alone, with a copy-paste fallback.
3. **Try it.** Paste the suggested prompt into any connected agent and watch the to-do arrive.
4. **Widget.** Add the desktop widget. Remy notices when it's placed.

Reopen these steps from the menu bar (… → Connect Agents…), or with `open remy://connect` or `open remy://widget`.

## Build

Requires macOS 26, Xcode 26, and XcodeGen.

```sh
./scripts/make-dmg.sh          # build/Remy.dmg
```

Signing uses `DEVELOPMENT_TEAM` in `project.yml`. With a **Developer ID Application** certificate for that team, the script exports a Developer ID build. It also notarizes when `REMY_NOTARY_PROFILE` names a `notarytool store-credentials` profile. Without those, it produces a development DMG that runs only on this Mac.

To review design changes, render every surface to PNG: build the `Snapshots` scheme, then run `Snapshots <dir>`.

## Shell

```sh
remy add "Renew the domain" --date 2026-11-03 [--time 17:00] [--source NAME]
remy list [today|upcoming|done|all]
remy done <id> | undo <id> | rm <id>
remy edit <id> [--title T] [--date D | --no-date] [--time T | --no-time]
```

## Layout

- `Packages/RemyKit`: the model, JSON store, date logic, wire protocol, and CLI parsing. Run its tests with `swift test`.
- `App/`: the menu bar app. It's the single writer for agents and owns the Unix socket, notifications, and widget reloads.
- `Widget/`: the WidgetKit extension, with an interactive check-off.
- `CLI/`: the `remy` binary (CLI and stdio MCP server), embedded at `Remy.app/Contents/Helpers/remy`.
- `App/Onboarding/`: first-run onboarding (detect, connect, verify, add the widget).
- `Snapshots/`: a dev-only renderer for design review.
- `scripts/make-dmg.sh`: packaging.
- `docs/`: requirements, plans, and the visual/motion spec.
