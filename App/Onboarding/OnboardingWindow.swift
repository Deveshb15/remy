import AppKit
import RemyKit
import SwiftUI

/// Hosts onboarding in a titled window with a transparent titlebar. The app shows in the Dock only while it's open.
@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindow()
    private var window: NSWindow?
    var isOpen: Bool { window != nil }

    func show(at step: OnboardingStep? = nil) {
        if let window {
            if let step { (window.contentViewController as? NSHostingController<OnboardingRoot>)?.rootView.model.go(to: step) }
            activate(window)
            return
        }
        let model = OnboardingModel(start: step)
        let host = NSHostingController(rootView: OnboardingRoot(model: model, close: { [weak self] in self?.window?.close() }))
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 560),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.contentViewController = host
        w.setContentSize(CGSize(width: 620, height: 560))
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false
        window = w
        Task { await model.load() }
        activate(w)
    }

    private func activate(_ w: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        AppController.shared.requestNotifications() // even if they closed early, reminders must still notify
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Root view bound to the shared app controller so Try It sees agent writes live.
struct OnboardingRoot: View {
    let model: OnboardingModel
    let close: () -> Void

    var body: some View {
        OnboardingView(model: model, close: close)
            .environment(AppController.shared)
            .onChange(of: AppController.shared.todos) { _, todos in model.observe(todos) }
    }
}
