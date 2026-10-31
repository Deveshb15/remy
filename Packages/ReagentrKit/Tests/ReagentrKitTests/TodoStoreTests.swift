import Foundation
import Testing
@testable import ReagentrKit

@Suite struct TodoStoreTests {
    @Test func roundTripsInOrder() throws {
        let store = tempStore()
        let todos = [todo("aaa", date: "2026-11-03", time: "17:00"), todo("bbb"), todo("ccc", done: Date(timeIntervalSince1970: 100))]
        try store.mutate { $0 = todos }
        #expect(try store.load() == todos)
    }

    @Test func missingFileIsEmpty() throws {
        #expect(try tempStore().load().isEmpty)
    }

    @Test func corruptFileIsMovedAsideNotOverwritten() throws {
        let store = tempStore()
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)
        #expect(try store.load().isEmpty)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: store.url.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.hasPrefix("todos.corrupt-") })
    }

    @Test func mutateDoesNotWriteWhenBodyThrows() throws {
        struct Boom: Error {}
        let store = tempStore()
        try store.mutate { $0 = [todo("keep")] }
        #expect(throws: Boom.self) { try store.mutate { $0 = []; throw Boom() } }
        #expect(try store.load().map(\.id) == ["keep"])
    }

    @Test func unreadableFileThrowsInsteadOfBeingOverwritten() throws {
        let store = tempStore()
        try store.mutate { $0 = [todo("keep")] }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: store.url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: store.url.path) }
        #expect(throws: (any Error).self) { try store.mutate { $0.append(todo("new")) } }
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: store.url.path)
        #expect(try store.load().map(\.id) == ["keep"])
    }

    @Test func rejectsInvalidDatesAndTimes() {
        #expect(LocalDate("2026-13-01") == nil)
        #expect(LocalDate("2026-02-30") == nil)
        #expect(LocalDate("2026-2-3") == nil)
        #expect(LocalTime("25:00") == nil)
        #expect(LocalTime("9:00") == nil)
        #expect(LocalDate("2028-02-29") != nil)
    }

    @Test func idsAreUniqueAndUnambiguous() {
        var seen = Set<String>()
        for _ in 0..<10_000 { seen.insert(Todo.newID(avoiding: seen)) }
        #expect(seen.count == 10_000)
        #expect(seen.allSatisfy { $0.count == 6 && !$0.contains(where: { "ilou01".contains($0) }) })
    }
}
