import AppKit
import Sparkle
import UserNotifications

/// Sparkle auto-updates. Release process and policy: docs/releasing.md.
/// Remy is a menu bar app, so scheduled updates use Sparkle's "gentle reminders": instead of a window popping over
/// whatever you're doing, Remy shows up in the Dock with a badge and posts a notification.
@MainActor
final class Updater: NSObject {
    static let shared = Updater()
    nonisolated static let notificationID = "remy-update-available"

    /// Testing hooks (both off by default):
    ///   defaults write dev.devesh.remy RemyBetaUpdates -bool YES      # also receive <sparkle:channel>beta</sparkle:channel> items
    ///   defaults write dev.devesh.remy RemyFeedURL file:///path/appcast.xml   # try a release before publishing it
    static let betaKey = "RemyBetaUpdates", feedOverrideKey = "RemyFeedURL"

    private var controller: SPUStandardUpdaterController!

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}

extension Updater: @preconcurrency SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UserDefaults.standard.bool(forKey: Self.betaKey) ? ["beta"] : []
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: Self.feedOverrideKey)
    }
}

extension Updater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        NSApp.setActivationPolicy(.regular)
        guard !state.userInitiated else { return }
        NSApp.dockTile.badgeLabel = "1"
        let content = UNMutableNotificationContent()
        content.title = "Remy \(update.displayVersionString) is available"
        content.body = "Click to see what\u{2019}s new and update."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil))
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        NSApp.dockTile.badgeLabel = ""
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }

    func standardUserDriverWillFinishUpdateSession() {
        // Onboarding also keeps Remy in the Dock while its window is open; don't yank that away.
        if !OnboardingWindow.shared.isOpen { NSApp.setActivationPolicy(.accessory) }
    }
}
