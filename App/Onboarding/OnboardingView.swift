import RemyKit
import SwiftUI

/// Onboarding shell: title, content, and a footer with progress dots and actions.
struct OnboardingView: View {
    let model: OnboardingModel
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moveError: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                content
                    .id(model.step)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: model.forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: model.forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 44)
            .padding(.top, 52)
            .clipped()

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .frame(width: 620, height: 560)
        .animation(Theme.Motion.named(Theme.Motion.settle, reduceMotion: reduceMotion), value: model.step)
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .move: MoveStep(error: moveError)
        case .welcome: WelcomeStep()
        case .connect: ConnectStep(model: model)
        case .tryIt: TryStep(model: model)
        case .widget: WidgetStep(model: model)
        case .done: DoneStep()
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if model.step != .move { ProgressDots(steps: model.visibleSteps, current: model.step) }
            Spacer()
            if let secondary { Button(secondary.label, action: secondary.action).buttonStyle(QuietButtonStyle()) }
            Button(action: primary.action) {
                HStack(spacing: 6) {
                    if busy { ProgressView().controlSize(.mini) }
                    Text(primary.label).contentTransition(.opacity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy)
            .keyboardShortcut(.defaultAction)
        }
        .animation(Theme.Motion.named(Theme.Motion.pop, reduceMotion: reduceMotion), value: primary.label)
    }

    private struct Action { let label: String; let action: () -> Void }

    private var primary: Action {
        switch model.step {
        case .move:
            Action(label: "Move to Applications") {
                do { try Installer.moveToApplications() } catch { moveError = error.localizedDescription }
            }
        case .welcome: Action(label: "Get started") { model.advance() }
        case .connect:
            if model.anyIdle && !model.detecting {
                Action(label: "Connect all") { run { await model.connectAll() } }
            } else {
                Action(label: "Continue") { model.advance() }
            }
        case .tryIt: Action(label: model.arrival == nil ? "Skip" : "Continue") { model.advance() }
        case .widget: Action(label: model.widgetPlaced ? "Continue" : "I added it") { model.advance() }
        case .done: Action(label: "Finish") { model.finish(); close() }
        }
    }

    private var secondary: Action? {
        switch model.step {
        case .move, .welcome: nil
        case .widget where !model.widgetPlaced: Action(label: "Skip") { model.advance() }
        default: Action(label: "Back") { model.back() }
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        busy = true
        Task { await work(); busy = false }
    }
}

private struct ProgressDots: View {
    let steps: [OnboardingStep]
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(steps, id: \.self) { s in
                Capsule()
                    .fill(s == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: s == current ? 16 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \((steps.firstIndex(of: current) ?? 0) + 1) of \(steps.count)")
    }
}

/// Inverse capsule: label-colored fill, background-colored text. The only filled control in the app.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.background)
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(.primary, in: .capsule)
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(Theme.Motion.named(Theme.Motion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Title + subtitle every step shares.
struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.6)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440, alignment: .leading)
        }
    }
}
