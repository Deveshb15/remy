import Foundation
import Testing
@testable import ReagentrKit

@Suite struct CommandHandlerTests {
    let c = cal()
    func handler(_ store: TodoStore = tempStore(), now: Date? = nil) -> CommandHandler {
        let instant = now ?? at("2026-10-31", "14:05")
        return CommandHandler(store: store, calendar: c, now: { instant })
    }

    // AE4: writes echo the resolved date and the current date.
    @Test func addEchoesHumanDateAndNow() {
        let (r, changed) = handler().handle(Request(op: .add, title: "Pay rent", date: "2026-11-06", source: "Claude"))
        #expect(changed && r.ok)
        #expect(r.item?.human == "Fri, Nov 6")
        #expect(r.item?.bucket == .upcoming)
        #expect(r.item?.source == "Claude")
        #expect(r.now == Now(date: "2026-10-31", weekday: "Saturday", time: "14:05", timezone: "America/Los_Angeles"))
    }

    @Test func listViews() {
        let h = handler()
        _ = h.handle(Request(op: .add, title: "later", date: "2026-11-03"))
        _ = h.handle(Request(op: .add, title: "now"))
        _ = h.handle(Request(op: .add, title: "late", date: "2026-10-29"))
        #expect(h.handle(Request(op: .list, view: .today)).response.items?.map(\.title) == ["late", "now"])
        #expect(h.handle(Request(op: .list, view: .upcoming)).response.items?.map(\.title) == ["later"])
        #expect(h.handle(Request(op: .list)).response.items?.count == 2) // default view is today
        #expect(h.handle(Request(op: .list, view: .all)).response.items?.count == 3)
    }

    // AE5 at the handler level.
    @Test func completeMovesToDoneAndUndoRestores() throws {
        let h = handler()
        let id = try #require(h.handle(Request(op: .add, title: "x")).response.item?.id)
        #expect(h.handle(Request(op: .complete, id: id)).response.item?.done == true)
        #expect(h.handle(Request(op: .list, view: .today)).response.items?.isEmpty == true)
        #expect(h.handle(Request(op: .list, view: .done)).response.items?.map(\.id) == [id])
        _ = h.handle(Request(op: .complete, id: id, done: false))
        #expect(h.handle(Request(op: .list, view: .today)).response.items?.map(\.id) == [id])
    }

    @Test func updateReschedulesEditsAndClears() throws {
        let h = handler()
        let id = try #require(h.handle(Request(op: .add, title: "x", date: "2026-11-03", time: "09:30")).response.item?.id)
        var r = h.handle(Request(op: .update, id: id, title: "y", date: "2026-11-05")).response
        #expect(r.item?.title == "y" && r.item?.date == "2026-11-05" && r.item?.time == "09:30")
        r = h.handle(Request(op: .update, id: id, clearTime: true)).response
        #expect(r.item?.time == nil && r.item?.date == "2026-11-05")
        r = h.handle(Request(op: .update, id: id, clearDate: true)).response
        #expect(r.item?.date == nil && r.item?.bucket == .today)
    }

    @Test func deleteRemoves() throws {
        let h = handler()
        let id = try #require(h.handle(Request(op: .add, title: "x")).response.item?.id)
        #expect(h.handle(Request(op: .delete, id: id)).response.ok)
        #expect(h.handle(Request(op: .list, view: .all)).response.items?.isEmpty == true)
    }

    @Test func pastDateIsAllowedWithNote() {
        let r = handler().handle(Request(op: .add, title: "x", date: "2026-10-01")).response
        #expect(r.ok && r.item?.bucket == .overdue && r.note != nil)
    }

    @Test(arguments: [
        (Request(op: .add, title: "   "), "invalid_title"),
        (Request(op: .add, title: String(repeating: "a", count: 201)), "invalid_title"),
        (Request(op: .add, title: "x", date: "11/03/2026"), "invalid_date"),
        (Request(op: .add, title: "x", time: "5pm"), "invalid_time"),
        (Request(op: .add, title: "x", time: "17:00"), "time_without_date"),
        (Request(op: .complete, id: "nope00"), "not_found"),
        (Request(op: .delete), "missing_id"),
        (Request(op: .update, id: "nope00", title: "y"), "not_found"),
    ])
    func errorsLeaveStoreUnchanged(req: Request, code: String) throws {
        let store = tempStore()
        let h = handler(store)
        _ = h.handle(Request(op: .add, title: "seed"))
        let before = try store.load()
        let (r, changed) = h.handle(req)
        #expect(!r.ok && !changed && r.error?.code == code)
        #expect(try store.load() == before)
    }

    @Test func updateRejectsTimeOnUndated() throws {
        let h = handler()
        let id = try #require(h.handle(Request(op: .add, title: "x")).response.item?.id)
        #expect(h.handle(Request(op: .update, id: id, time: "10:00")).response.error?.code == "time_without_date")
    }

    @Test func wireRoundTripEveryOp() throws {
        let h = handler()
        let id = try #require(h.handle(Request(op: .add, title: "x")).response.item?.id)
        let reqs: [Request] = [
            Request(op: .now), Request(op: .list, view: .upcoming), Request(op: .add, title: "y", date: "2026-11-03", time: "08:00", source: "Codex"),
            Request(op: .update, id: id, title: "z"), Request(op: .complete, id: id, done: true), Request(op: .delete, id: id),
        ]
        for req in reqs {
            let decoded = try Wire.decode(Request.self, from: Wire.encode(req))
            #expect(decoded == req)
            let resp = h.handle(decoded).response
            #expect(try Wire.decode(Response.self, from: Wire.encode(resp)) == resp)
            #expect(resp.ok)
        }
    }
}
