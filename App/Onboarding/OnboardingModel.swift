import AppKit
import Observation
import RemyKit
import WidgetKit

/// State for the first-run flow: which step, which harnesses, what's been proven to work.
@MainActor @Observable
final class OnboardingModel {
    enum Status: Equatable { case idle, working, connected, failed(String), manual(String) }

    struct Row: Identifiable, Equatable {
        let harness: Harness
        var status: Status = .idle
        var verified: String?   // title of the to-do this agent added during Try It
        var id: String { harness.id }
        var isConnected: Bool { status == .connected }
    }

    enum SelfTest { case running, passed, failed }

    static let onboardedKey = "onboarded"
    static var isOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: onboardedKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardedKey) }
    }

    static let tryPrompt = "Use Remy to add \u{201C}Try Remy\u{201D} to my to-dos for today."

    var step: OnboardingStep
    var rows: [Row] = []
    var detecting = true
    var selfTest: SelfTest = .running
    var widgetPlaced = false
    var arrival: Todo?        // first agent-made to-do seen during Try It
    var forward = true        // direction of the last step change, for the slide transition
    private var tryStartedAt = Date.distantFuture
    @ObservationIgnored private var widgetPoll: Task<Void, Never>?

    var connectedCount: Int { rows.filter(\.isConnected).count }
    var anyIdle: Bool { rows.contains { $0.status == .idle } }
    var visibleSteps: [OnboardingStep] { OnboardingStep.allCases.filter { $0 != .move } }

    init(start: OnboardingStep? = nil) {
        step = start ?? (Installer.needsMove ? .move : .welcome)
    }

    func load() async {
        async let test = Installer.selfTest()
        let found = await Installer.detect()
        rows = found.map { Row(harness: $0, status: Installer.isConnected($0) ? .connected : .idle) }
        detecting = false
        selfTest = await test ? .passed : .failed
    }

    // MARK: Navigation

    func advance() { go(to: step.next(connectedCount: connectedCount)) }

    func back() {
        let order = visibleSteps
        if let i = order.firstIndex(of: step), i > 0 {
            var prev = order[i - 1]
            if prev == .tryIt && connectedCount == 0 { prev = .connect }
            go(to: prev)
        }
    }

    func go(to s: OnboardingStep) {
        forward = s.rawValue >= step.rawValue
        step = s
        if s == .tryIt { tryStartedAt = Date() }
        widgetPoll?.cancel()
        if s == .widget { pollWidget() }
    }

    // MARK: Connect

    func connectAll() async {
        await withTaskGroup(of: Void.self) { group in
            for row in rows where row.status == .idle || isFailure(row.status) {
                group.addTask { await self.connect(row.id) }
            }
        }
    }

    func toggle(_ id: String) async {
        guard let row = rows.first(where: { $0.id == id }) else { return }
        if row.isConnected {
            set(id) { $0.status = .working }
            await Installer.disconnect(row.harness)
            set(id) { $0.status = .idle; $0.verified = nil }
        } else {
            await connect(id)
        }
    }

    private func connect(_ id: String) async {
        guard let row = rows.first(where: { $0.id == id }) else { return }
        set(id) { $0.status = .working }
        let result = await Installer.connect(row.harness)
        set(id) {
            switch result {
            case .connected: $0.status = .connected
            case .failed(let m): $0.status = .failed(m)
            case .manual(let s): $0.status = .manual(s)
            }
        }
    }

    private func isFailure(_ s: Status) -> Bool { if case .failed = s { true } else { false } }

    private func set(_ id: String, _ change: (inout Row) -> Void) {
        guard let i = rows.firstIndex(where: { $0.id == id }) else { return }
        change(&rows[i])
    }

    // MARK: Try It

    /// Called whenever the store changes: the first agent-made to-do since Try It opened proves the loop.
    func observe(_ todos: [Todo]) {
        guard step == .tryIt else { return }
        let fresh = todos.filter { $0.createdAt >= tryStartedAt.addingTimeInterval(-2) && !["you", "cli"].contains($0.source) }
        guard let newest = fresh.max(by: { $0.createdAt < $1.createdAt }), newest.id != arrival?.id else { return }
        arrival = newest
        if let h = Harness.matching(source: newest.source) { set(h.id) { $0.verified = newest.title } }
    }

    // MARK: Widget

    private func pollWidget() {
        widgetPoll = Task { [weak self] in
            while !Task.isCancelled {
                if let configs = try? await WidgetCenter.shared.currentConfigurations(),
                   configs.contains(where: { $0.kind == Paths.widgetKind }) {
                    self?.widgetPlaced = true
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: Finish

    func finish() {
        Self.isOnboarded = true
        widgetPoll?.cancel()
        AppController.shared.requestNotifications()
    }
}
