# Reagentr visual and motion spec

Direction: **"warm paper, candy accents."** Calm system neutrals and SF Pro Rounded, with one warm brand accent. Each to-do carries a small colored source mark, so the list reads as a friendly conversation between you and your agents. Delight comes from motion and color at the moment of completion, not from decoration at rest.

Sources applied: the `design` skill (ui.sh) rules and `apple-design` (WWDC fluid-interface principles), translated to SwiftUI. Mobbin references are listed in `docs/brainstorms/2026-10-31-agent-todo-widget-requirements.md`: Todoist (date chips, overdue section), Me+ (colored completion), Tiimo (soft rows), and Abode (playful card).

## Rules carried from the design skills

- No indigo as the accent. Neutrals are system label colors, not hard-coded grays.
- Use the lightest separation that works. Rows sit directly on the surface with whitespace between them, with no per-row cards. Dividers, where any are needed, use opacity (`primary.opacity(0.06)`).
- Concentric radii: inner radius = outer radius - padding (the widget container and the popover field).
- Headings use `.semibold`, never `.bold`. Display numbers get negative tracking; small labels stay at 0.
- Copy has no emoji. Standalone sentences end with a period ("All clear.", "Nothing due today."). Labels and chips have no period.
- Feedback happens on press: buttons scale on mouse-down, not on release.
- Springs start from the current value and are always interruptible (SwiftUI's default for spring animations).
- Reduce Motion replaces springs and travel with short cross-fades, and Reduce Transparency is honored (handled by system materials).

## Color tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `accent` (Tangerine) | `#FF6A1F` | `#FF8A47` | brand, "you" source, today count, quick-add focus |
| `done` (Mint) | `#1DB980` | `#34D399` | checkbox fill, celebration |
| `overdue` (Rose) | `#E5484D` | `#FF6369` | overdue chip, overdue section label |
| `claude` (Clay) | `#D97757` | `#E58B6D` | Claude source mark and ring |
| `codex` (Sky) | `#3E7BFA` | `#6C9BFF` | Codex source mark and ring |
| `other` (Iris) | `#8B5CF6` | `#A78BFA` | any other agent or CLI |
| `chipFill` | `primary @ 6%` | `primary @ 10%` | neutral date chips |
| `hairline` | `primary @ 6%` | `primary @ 8%` | dividers |

Tinted, accented, and clear widget modes: the rings, count, and source marks are `.widgetAccentable()`, so the system recolors them. Everything else uses `.primary` or `.secondary`, so vibrant mode stays legible.

## Type (SF Pro Rounded via `.fontDesign(.rounded)`)

| Role | Size / weight | Notes |
|---|---|---|
| Display count (widget) | 34 / semibold | `.numericText()` transition, tracking -0.5 |
| Section header | 13 / semibold | "Today", "Overdue", day names in Upcoming |
| Row title | 13 / medium | 1 line on medium, 2 lines on large and popover |
| Chip / meta | 11 / medium | date chips, upcoming hint, source name |

## Spacing and shape

- 4-pt grid. Row height in the widget is 22 pt with 6 pt between rows. Popover rows are 32 pt with 8 pt horizontal padding.
- Checkbox: an 18 pt circle with a 1.75 pt stroke in the source color at 70% opacity. When done, it's filled with `done` and shows a white `checkmark` (10 pt, bold).
- Source mark: a 16 pt circle filled with the source color at 16%, holding an 8 pt SF Symbol in the source color. Claude uses `sparkle`, Codex `chevron.left.forwardslash.chevron.right`, you `person.fill`, and other agents `cpu`.
- Date chip: a capsule with 6 pt horizontal and 2 pt vertical padding. If it has an icon, the padding on the icon side equals the vertical padding (badge rule).
- The popover is 360 pt wide with a 560 pt max height on the system Liquid Glass popover background. The quick-add field is a 12 pt continuous rounded rect inside 16 pt content padding.

## Widget layouts

- **Small:** weekday on the first line (11, secondary), a large count of open items today, the next item's title (2 lines) with its chip, and a check toggle for that item at the trailing bottom.
- **Medium:** a header with "Today", a count capsule, and a trailing "N upcoming" hint. Up to 4 rows, with overdue rows first under a rose "Overdue" label if any exist.
- **Large:** the same header, up to 9 rows, and a footer reading "N upcoming · next Tue".
- **Empty (all sizes):** a `sun.max.fill` glyph with an accent-to-marigold gradient, "All clear." (13 semibold), and on medium and large "Nothing due today." (11 secondary). If items are upcoming, the hint line reads "Next: Tue, Nov 3."
- **Check:** `Toggle(isOn:intent:)`, so the system flips the checkbox at once (optimistic), before the intent finishes.

## Motion

Named springs (SwiftUI `response` / `dampingFraction`):

| Name | Value | Use |
|---|---|---|
| `press` | 0.22 / 0.6 | button and row press scale (0.94) |
| `pop` | 0.32 / 0.55 | checkbox fill and checkmark, chip selection |
| `bouncy` | 0.45 / 0.68 | row insert, quick-add submit, empty-state glyph arrival |
| `settle` | 0.38 / 1.0 | removal, reorder, section height changes |

Check-off choreography (popover):

1. At 0 ms, the checkbox scales 0.82, then 1.18, then 1.0 (keyframes over `pop`). The fill changes to `done`, and the checkmark trims in over 220 ms.
2. At 60 ms, a strike-through line draws across the title from the leading edge, and the title fades to secondary.
3. At 60 ms, a burst of 10 dots and 4 tiny star sparkles radiates 18 to 34 pt from the checkbox in `done`, `accent`, and the source color, then fades over 650 ms. A `.sensoryFeedback(.success)` fires on the same frame as the fill.
4. At 700 ms, the row leaves with `settle`: it moves up, scales to 0.96, and fades, and the rows below close the gap.

Undo, by clicking the checkbox again within the 700 ms window, cancels step 4 and reverses the fill. This is the interruptible design.

Insert: new rows enter from the top edge with `.scale(0.92, anchor: .top) + .opacity` on `bouncy`. Quick-add chips share a `matchedGeometryEffect` selection capsule, so the highlight slides between chips.

Widget: the count uses `.contentTransition(.numericText())`. Rows use `.transition(.push(from: .bottom))`, and the system animates entry changes. The toggle supplies the instant check.

Reduce Motion: every named spring becomes `.easeInOut(duration: 0.18)`. There is no keyframe scale or burst. The strike-through appears without drawing, and insert and removal become opacity-only.
