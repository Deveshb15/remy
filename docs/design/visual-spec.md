# Remy visual and motion spec

Direction: **quiet and monochrome.** The look follows the restraint of Things 3, Amie, Superlist, and Numo on Mobbin: hairline circular checkboxes, regular-weight titles, and metadata in quiet gray. Color appears only when it carries meaning, and the only color is red for overdue. Delight comes from motion and feel, not from color.

References (Mobbin):
- [Things 3 Today](https://mobbin.com/screens/feadd020-045b-477e-b54f-d4c405995a58)
- [Amie to-dos](https://mobbin.com/screens/c162a13d-b728-4171-a438-9c4dd29b69c8)
- [Superlist Today](https://mobbin.com/screens/3e9c7d4b-c7cc-4251-bbb3-4aea6b29d40d)
- [Numo](https://mobbin.com/screens/fba734f4-c060-4985-ae29-0e37cb086c17)

To review changes, render every surface with `build/dd/Build/Products/Debug/Snapshots <dir>` (Snapshots scheme).

## Rules

- System label colors only: `.primary`, `.secondary`, `.tertiary`. `Color.red` is used for overdue text only. There are no brand colors, gradients, or tinted pills.
- Rows sit directly on the surface with no cards. There's one hairline divider under the add row, and hover gives a 4.5% primary wash.
- Agent attribution is a 9 pt tertiary SF Symbol after the time (Claude `sparkle`, Codex `</>`, CLI `terminal`). Your own to-dos have none. The context menu names the agent.
- SF Pro (default design). Titles use regular weight, headers semibold, and counts sit in tertiary next to the header ("Today 5").
- Dates use the user's locale in the UI. Agent-facing strings stay in fixed en_US.

## Surfaces

- **Popover (340 pt wide):** a "Today N" header with an ellipsis button that opens Connect. Below it are the add row, then Today rows, then each upcoming day as "Monday 2 Nov" with its rows, then "Show N done". It hugs its content up to a 440 pt scroll area.
- **Add row:** a `+` sits in the checkbox column with the placeholder "New to-do". Typing reveals Today / Tomorrow / Next week / Date… plus a clock toggle, aligned under the title text. Return adds the to-do.
- **Widget, medium:** "Today N" on the left and "Sat 31" on the right, up to 4 rows, and the footer "1 more · 2 upcoming".
- **Widget, large:** up to 9 rows. Spare rows preview Upcoming, dimmed, with the weekday as metadata.
- **Widget, small:** the weekday, a large count, "to-dos today", and the next to-do with its checkbox.
- **Empty:** a light `checkmark.circle` in tertiary, "All clear", and "Nothing due today." The widget names the next day that has something due.

## Motion

| Name | Spring (response / damping) | Use |
|---|---|---|
| `press` | 0.22 / 0.65 | buttons scale to 0.92 on mouse-down |
| `pop` | 0.30 / 0.60 | checkbox fill, option selection |
| `bouncy` | 0.42 / 0.72 | row insert, add-row options revealing |
| `settle` | 0.36 / 1.0 | removal, reorder, panel switch |

Check-off: the ring squeezes to 0.8, then springs back filled (a solid label-colored disc with a knocked-out check). A thin ring ripples out to 2.4x and fades, the strike draws through the title text, and a success haptic fires. After 650 ms the row fades out. Clicking again before then undoes it.

Widget: counts use `.numericText()`, rows use `.push(from: .bottom)`, and `Toggle(isOn:intent:)` flips the checkbox instantly.

Reduce Motion: all springs become a 0.18 s ease, with no ripple, squeeze, or strike draw.
