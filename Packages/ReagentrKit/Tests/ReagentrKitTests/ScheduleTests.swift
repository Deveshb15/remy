import Foundation
import Testing
@testable import ReagentrKit

@Suite struct ScheduleTests {
    let c = cal()

    // AE1: hidden until its day, then appears; timeline has that midnight.
    @Test func futureTodoHiddenUntilItsDay() {
        let t = todo("renew", date: "2026-11-03")
        for day in ["2026-10-31", "2026-11-01", "2026-11-02"] {
            #expect(Schedule.bucket(t, on: d(day)) == .upcoming)
            #expect(Schedule.visible([t], on: d(day)).isEmpty)
        }
        #expect(Schedule.bucket(t, on: d("2026-11-03")) == .today)
        #expect(Schedule.timelineDates([t], now: at("2026-10-31"), calendar: c).contains(d("2026-11-03").start(in: c)))
    }

    // AE2: notification at 9:00 for date-only, at its time otherwise.
    @Test func fireDates() {
        let now = at("2026-10-31")
        #expect(Schedule.fireDate(todo("a", date: "2026-11-03"), now: now, calendar: c) == at("2026-11-03", "09:00"))
        #expect(Schedule.fireDate(todo("b", date: "2026-11-03", time: "17:00"), now: now, calendar: c) == at("2026-11-03", "17:00"))
        #expect(Schedule.bucket(todo("b", date: "2026-11-03", time: "17:00"), on: d("2026-11-03")) == .today)
        #expect(Schedule.fireDate(todo("c"), now: now, calendar: c) == nil)
        #expect(Schedule.fireDate(todo("d", date: "2026-10-30"), now: now, calendar: c) == nil)
        #expect(Schedule.fireDate(todo("e", date: "2026-11-03", done: now), now: now, calendar: c) == nil)
    }

    // AE3: overdue stays and sorts above today.
    @Test func overdueSortsFirst() {
        let today = todo("today", date: "2026-10-31", time: "08:00")
        let overdue = todo("bank", date: "2026-10-30")
        #expect(Schedule.bucket(overdue, on: d("2026-10-31")) == .overdue)
        #expect(Schedule.visible([today, overdue], on: d("2026-10-31")).map(\.id) == ["bank", "today"])
    }

    @Test func todayOrderingTimedThenUntimedThenCreated() {
        let list = [
            todo("untimed2", created: Date(timeIntervalSince1970: 2)),
            todo("late", date: "2026-10-31", time: "18:00"),
            todo("untimed1", created: Date(timeIntervalSince1970: 1)),
            todo("early", date: "2026-10-31", time: "07:30"),
        ]
        #expect(Schedule.visible(list, on: d("2026-10-31")).map(\.id) == ["early", "late", "untimed1", "untimed2"])
    }

    @Test func undatedIsAlwaysToday() {
        #expect(Schedule.bucket(todo("x"), on: d("2030-01-01")) == .today)
    }

    @Test func doneOverridesDateAndUndoRestores() {
        var t = todo("x", date: "2026-11-05", done: Date())
        #expect(Schedule.bucket(t, on: d("2026-10-31")) == .done)
        t.completedAt = nil
        #expect(Schedule.bucket(t, on: d("2026-10-31")) == .upcoming)
    }

    @Test func dstDayMidnightIsCorrect() {
        let ny = cal("America/New_York")
        let dates = Schedule.timelineDates([todo("x", date: "2026-11-02")], now: at("2026-10-31", "12:00", ny), calendar: ny)
        let comps = dates.dropFirst().map { ny.dateComponents([.day, .hour, .minute], from: $0) }
        #expect(comps.allSatisfy { $0.hour == 0 && $0.minute == 0 })
        #expect(comps.map(\.day) == [1, 2])
    }

    @Test func timelineWithNoFutureItemsHasNowAndNextMidnight() {
        let now = at("2026-10-31")
        #expect(Schedule.timelineDates([todo("x")], now: now, calendar: c) == [now, d("2026-11-01").start(in: c)])
    }

    @Test func timelineIsCapped() {
        let many = (1...30).map { todo("t\($0)", date: d("2026-10-31").adding(days: $0 + 1, calendar: c).description) }
        #expect(Schedule.timelineDates(many, now: at("2026-10-31"), calendar: c).count == 14)
    }

    @Test func humanStrings() {
        let today = d("2026-10-31")
        #expect(Schedule.human(date: d("2026-11-07"), time: nil, today: today, calendar: c) == "Sat, Nov 7")
        #expect(Schedule.human(date: d("2026-11-06"), time: nil, today: today, calendar: c) == "Fri, Nov 6")
        #expect(Schedule.human(date: today, time: LocalTime("17:00"), today: today, calendar: c) == "Today · 5:00 PM")
        #expect(Schedule.human(date: d("2026-11-01"), time: nil, today: today, calendar: c) == "Tomorrow")
        #expect(Schedule.human(date: nil, time: nil, today: today, calendar: c) == "Today")
        #expect(Schedule.human(date: d("2027-01-04"), time: nil, today: today, calendar: c) == "Mon, Jan 4, 2027")
    }

    @Test func chips() {
        let today = d("2026-10-31")
        #expect(Schedule.chip(todo("a", date: "2026-10-30"), today: today, calendar: c) == "Yesterday")
        #expect(Schedule.chip(todo("b", date: "2026-10-31", time: "17:00"), today: today, calendar: c) == "5:00 PM")
        #expect(Schedule.chip(todo("c"), today: today, calendar: c) == nil)
        #expect(Schedule.chip(todo("d", date: "2026-11-03"), today: today, calendar: c) == nil)
        #expect(Schedule.chip(todo("e", date: "2026-11-03", time: "08:15"), today: today, calendar: c) == "8:15 AM")
    }

    @Test func nextWeekChip() {
        #expect(Schedule.nextWeek(from: d("2026-10-31"), calendar: c) == d("2026-11-02"))
        #expect(Schedule.nextWeek(from: d("2026-11-02"), calendar: c) == d("2026-11-09"))
    }

    @Test func notificationDiff() {
        let nine = at("2026-11-03", "09:00"), ten = at("2026-11-03", "10:00"), five = at("2026-11-03", "17:00")
        var r = Schedule.notificationDiff(pending: ["a": nine], desired: ["a": nine, "b": five])
        #expect(r.add == ["b"] && r.remove.isEmpty)
        r = Schedule.notificationDiff(pending: ["a": nine], desired: ["a": ten])
        #expect(r.add == ["a"] && r.remove == ["a"])
        r = Schedule.notificationDiff(pending: ["a": nine], desired: [:])
        #expect(r.add.isEmpty && r.remove == ["a"])
    }
}
