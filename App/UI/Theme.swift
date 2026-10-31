import SwiftUI
import WidgetKit

/// Design tokens from docs/design/visual-spec.md. Shared by the app and the widget extension.
enum Theme {
    static let accent = Color(light: 0xFF6A1F, dark: 0xFF8A47)
    static let done = Color(light: 0x1DB980, dark: 0x34D399)
    static let overdue = Color(light: 0xE5484D, dark: 0xFF6369)
    static let marigold = Color(light: 0xFFB224, dark: 0xFFC53D)

    struct Source {
        let color: Color
        let symbol: String
        let label: String
    }

    static func source(_ name: String) -> Source {
        switch name.lowercased() {
        case "claude": Source(color: Color(light: 0xD97757, dark: 0xE58B6D), symbol: "sparkle", label: "Claude")
        case "codex": Source(color: Color(light: 0x3E7BFA, dark: 0x6C9BFF), symbol: "chevron.left.forwardslash.chevron.right", label: "Codex")
        case "you": Source(color: accent, symbol: "person.fill", label: "You")
        default: Source(color: Color(light: 0x8B5CF6, dark: 0xA78BFA), symbol: "cpu", label: name)
        }
    }

    enum Motion {
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.6)
        static let pop = Animation.spring(response: 0.32, dampingFraction: 0.55)
        static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.68)
        static let settle = Animation.spring(response: 0.38, dampingFraction: 1.0)
        static let reduced = Animation.easeInOut(duration: 0.18)

        static func named(_ a: Animation, reduceMotion: Bool) -> Animation { reduceMotion ? reduced : a }
    }
}

extension Color {
    /// Dynamic light/dark color from hex literals.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

/// Source mark: tinted circle with the agent's glyph.
struct SourceMark: View {
    let source: String
    var size: CGFloat = 16

    var body: some View {
        let s = Theme.source(source)
        Image(systemName: s.symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(s.color)
            .frame(width: size, height: size)
            .background(s.color.opacity(0.16), in: .circle)
            .widgetAccentable()
            .accessibilityLabel("Added by \(s.label)")
    }
}

/// Capsule date chip (Todoist-style). Overdue chips are rose.
struct DateChip: View {
    let text: String
    var overdue = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(overdue ? Theme.overdue : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(overdue ? Theme.overdue.opacity(0.12) : Color.primary.opacity(0.06), in: .capsule)
            .lineLimit(1)
            .fixedSize()
    }
}

/// The checkbox glyph used by both the widget toggle and the popover row.
struct CheckGlyph: View {
    let isOn: Bool
    let tint: Color
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().strokeBorder(tint.opacity(0.7), lineWidth: 1.75)
                .opacity(isOn ? 0 : 1)
            Circle().fill(Theme.done)
                .opacity(isOn ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
                .opacity(isOn ? 1 : 0)
                .scaleEffect(isOn ? 1 : 0.4)
        }
        .frame(width: size, height: size)
        .widgetAccentable()
        .contentShape(.circle)
    }
}
