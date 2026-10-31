---
date: 2026-10-31
topic: agent-todo-widget
---

# Remy: an agent-fed to-do widget for the Mac desktop

## Summary

A native Mac app whose centerpiece is a desktop widget showing today's to-dos. Any agent (Claude Code, Codex, or any MCP- or CLI-capable harness) can add, list, complete, reschedule, and delete dated to-dos. Future-dated to-dos stay off the widget until their day, then appear on their own with a notification.

---

## Problem Frame

When working with agents, "remind me to do X in three days" has nowhere good to land. The agent's session ends, and the reminder dies with it. Apple Reminders could hold it, but its widget is static and plain, it mixes agent-made items into personal lists, and it gives no sense of which agent put what there. The user wants a single, fun, glanceable place that every agent can write to and that only surfaces things when they are relevant.

---

## Actors

- A1. You: glance at the widget, check items off, add or manage items in the menu bar popover.
- A2. Agent: any harness that can call an MCP server or run a shell command. It turns natural-language dates into concrete dates and manages to-dos on your behalf.
- A3. Remy app: stores to-dos, schedules their appearance and notifications, and renders the widget and popover.

---

## Key Decisions

- **Own local store, not Apple Reminders.** Full control over data shape, look, and motion matters more than iPhone sync for v1. Data lives on this Mac only.
- **The agent resolves dates; the app echoes them back.** Agents turn "in three days" or "next Friday at 5" into an absolute date/time. Every write responds with the resolved date in plain words ("Tue, Nov 3 · 5:00 PM") so a wrong date is visible in the agent's reply.
- **Future to-dos are hidden, not listed.** The widget shows only what's relevant now, plus a small "N upcoming" hint. The full upcoming list lives in the popover.
- **Bouncy motion lives in the popover; the widget uses native transitions.** macOS widgets can't run free-form animations. The widget uses system transitions (check-off, number roll, content swaps). The popover carries the spring-heavy, playful motion.
- **Agent badge on every to-do.** Each to-do records and shows its source (Claude, Codex, other agent, or you). It's cheap personality and builds trust in what landed.
- **Personal build, not App Store.** Distribution is a locally signed build for the user's own Mac.

---

## Requirements

**Dated to-dos**

- R1. A to-do has a title, an optional date, an optional time, a source, and a done state.
- R2. A to-do with no date is due today and appears immediately.
- R3. A to-do with a future date stays off the widget until the start of that day (local time), then appears without the app needing to be opened.
- R4. A to-do with a time also triggers a notification at that time. A date-only to-do triggers a notification at 9:00 AM on its day.
- R5. An incomplete to-do whose date has passed stays on the widget, marked overdue, sorted above today's items.
- R6. Completed to-dos leave the widget after their completion transition and remain viewable in the popover's Done list.

**Agent interface**

- R7. Agents can add, list, complete, reschedule, edit, and delete to-dos.
- R8. Listing supports at least: today (including overdue), upcoming, and done.
- R9. Agents can reach the app through an MCP server and through a CLI that does the same things, so harnesses without MCP still work.
- R10. Every write echoes back the stored to-do, including its resolved date in human-readable form.
- R11. The interface tells the agent the current local date, time, and timezone so relative dates resolve correctly.
- R12. Changes made by an agent show on the widget within a few seconds.
- R13. Setup for a new agent is one copy-pasteable config snippet or command, shown in the app.

**Widget**

- R14. The widget comes in small, medium, and large sizes. Small shows the count and next item. Medium shows a short list. Large shows a longer list plus the upcoming hint.
- R15. You can check off a to-do directly from the widget without opening the app.
- R16. Each row shows the title, a time or date chip when set, an overdue state when applicable, and the source badge.
- R17. The empty state is delightful, not blank ("All clear" moment).
- R18. Clicking the widget, outside a checkbox, opens the popover.
- R19. The widget looks right in light mode, dark mode, and the system's tinted and clear widget styles.

**Menu bar popover**

- R20. The popover shows Today (with overdue), Upcoming (grouped by day), and Done.
- R21. You can add a to-do by hand with quick date chips (Today, Tomorrow, Next week, Pick a date) and an optional time.
- R22. You can complete, edit, reschedule, and delete to-dos in the popover.
- R23. The popover shows agent setup instructions (R13).

**Delight and motion**

- R24. Checking off a to-do has a satisfying moment: a springy check, a strike-through, and a short celebratory beat in the popover. The widget uses the native transition equivalent.
- R25. List insertions, removals, and reorders animate with spring physics in the popover. Nothing pops in or out abruptly.
- R26. Visual design is modern, warm, and playful, built with the design skill and informed by references from Mobbin.
- R27. All motion honors the system Reduce Motion setting.

---

## Key Flows

- F1. Agent schedules a future to-do
  - **Trigger:** You tell an agent "remind me to renew the domain in three days."
  - **Actors:** A1, A2, A3
  - **Steps:** The agent reads the current date from the interface, resolves "three days" to a date, and adds the to-do with itself as the source. The app stores it and schedules its appearance and notification. The agent repeats the resolved date back to you.
  - **Outcome:** Nothing changes on the widget today, except the upcoming hint goes up by one.
  - **Covered by:** R3, R4, R10, R11, R16

- F2. A to-do surfaces on its day
  - **Trigger:** Local midnight on the to-do's date.
  - **Actors:** A3
  - **Steps:** The widget shows the to-do with no app interaction. A notification fires at its time, or at 9:00 AM if it has no time.
  - **Outcome:** The to-do is on the widget alongside today's items.
  - **Covered by:** R3, R4

- F3. Check off from the widget
  - **Trigger:** You click a row's checkbox on the widget.
  - **Actors:** A1, A3
  - **Steps:** The to-do is marked done, the native completion transition plays, and the row leaves the list.
  - **Outcome:** An agent listing today's to-dos no longer sees it. It shows under Done in the popover.
  - **Covered by:** R6, R15, R24

---

## Acceptance Examples

- AE1. **Covers R3, R14.** Given today is Sat Oct 31, when an agent adds "Renew domain" for Tue Nov 3, the widget doesn't show it on Oct 31, Nov 1, or Nov 2, and its upcoming hint counts it. On Nov 3 it appears without the app being opened.
- AE2. **Covers R4.** Given a to-do for Nov 3 with no time, a notification fires at 9:00 AM Nov 3. Given a to-do for Nov 3 at 5:00 PM, the notification fires at 5:00 PM and the to-do is on the widget from the start of Nov 3.
- AE3. **Covers R5.** Given "Call bank" was due Oct 30 and isn't done, on Oct 31 it shows on the widget, marked overdue, above today's items.
- AE4. **Covers R10.** When an agent adds a to-do "next Friday," the response includes "Fri, Nov 6," so if the agent meant a different Friday, you see it in the agent's reply.
- AE5. **Covers R12, R15.** When you check off an item on the widget and an agent lists today's to-dos seconds later, the item is absent from today and present in done.

---

## Success Criteria

- Telling any configured agent "remind me to X on/in Y" results in the right to-do appearing on the right day, with no manual cleanup.
- An agent's add or complete is visible on the widget within a few seconds.
- The widget is good enough that the user keeps it on the desktop permanently. The popover feels fun to use, not merely functional.

---

## Scope Boundaries

**Deferred for later**

- iPhone app and iCloud sync.
- Repeating to-dos ("every Monday").
- Multiple lists, tags, or projects.
- Natural-language date parsing typed into the app itself (agents handle language; manual add uses chips).

**Outside this product's identity**

- An agent inbox where agents raise their own requests or approvals. Remy holds things you asked to be reminded of.
- Team or shared to-dos.
- App Store distribution.

---

## Dependencies / Assumptions

- Requires a macOS version with interactive desktop widgets (macOS 14 or later); the exact floor is a planning decision.
- WidgetKit limits widget animation to system-provided transitions; free-form spring motion is popover-only.
- The user didn't say what they use today. We assume no existing system is in use and this replaces nothing.
- Agents are trusted local processes; there is no authentication between agent and app beyond running on the same Mac as the same user.

---

## Outstanding Questions

**Deferred to Planning**

- Can a write from an agent refresh the widget within seconds when the app isn't in the foreground? This is the biggest feasibility risk for R12.
- How the MCP server and CLI reach the app's store (for example, a shared store versus talking to the running app), and what happens when the app isn't running.
- Storage format and location for to-dos.
- How timezone changes and travel affect already-scheduled to-dos.
- Final app name; "Remy" is a working name from the project folder.

---

## Sources / Research

- Mobbin widget references (iOS; Mobbin has no macOS widgets):
  - Todoist: date chips and an overdue section. https://mobbin.com/screens/e3664e12-9fd4-4240-aca2-522f44003b9e
  - Me+: playful, colored completion states. https://mobbin.com/screens/64d3a0fd-6639-4638-a576-ebb7cf2c3d93
  - Tiimo: soft rows with emoji icons. https://mobbin.com/screens/328f199c-2624-429a-aa4f-60ebf1ada74d
  - Abode: a fun to-do card with a progress line. https://mobbin.com/screens/b3fbd884-220f-4bd3-9867-4bde38143430
