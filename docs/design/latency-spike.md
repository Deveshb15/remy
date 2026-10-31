# U6 latency spike: agent write to widget

## Measured (2026-10-31, macOS 26.6.2, Release build in `~/Applications`)

- Agent call to app response: `reagentr add` round-trips through the Unix socket in under 50 ms, including JSON encode, the coordinated store write, and the response.
- App to chronod: `WidgetCenter.reloadTimelines(ofKind:)` reaches chronod about 26 ms after the write (system log timestamps).
- With no widget placed, chronod logs `Ignoring restricted or unknown extension`. It does the same for other installed apps with no placed widget, so this is expected. It also logs `purging instead because we shouldn't cache it` for this development-signed build, and fetches widget descriptors on demand.

## Not yet measured

On-screen latency needs a widget instance on the desktop, which can only be placed by hand. To check it:

1. Right-click the desktop, choose Edit Widgets, search for "Reagentr", and add the Medium size.
2. Run `~/Applications/Reagentr.app/Contents/Helpers/reagentr add "Latency check"` and watch the widget.
3. To see the reload timeline, use `log stream --style compact --predicate 'process == "chronod" AND eventMessage CONTAINS[c] "reagentr"'`.

Gate: pass if the median is 5 seconds or less. Mitigations, in order, if not: coalesce bursts, briefly activate the app before reloading, then relax R12 with sign-off.
