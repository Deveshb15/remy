import SwiftUI
import WidgetKit

/// Design tokens from docs/design/visual-spec.md. Monochrome: system label colors only, red reserved for overdue.
enum Theme {
    static let overdue = Color.red

    /// Agent glyphs, drawn in the same tertiary gray as the rest of the metadata.
    static func symbol(for source: String) -> String? {
        switch source.lowercased() {
        case "you": nil
        case "claude": "sparkle"
        case "codex": "chevron.left.forwardslash.chevron.right"
        case "cli": "terminal"
        default: "circle.hexagongrid"
        }
    }

    static func label(for source: String) -> String {
        switch source.lowercased() {
        case "claude": "Claude"
        case "codex": "Codex"
        case "you": "you"
        default: source
        }
    }

    enum Motion {
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.65)
        static let pop = Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.72)
        static let settle = Animation.spring(response: 0.36, dampingFraction: 1.0)
        static let reduced = Animation.easeInOut(duration: 0.18)

        static func named(_ a: Animation, reduceMotion: Bool) -> Animation { reduceMotion ? reduced : a }
    }
}

/// Circular checkbox: hairline ring when open, solid label-colored disc with a knocked-out check when done.
struct CheckGlyph: View {
    let isOn: Bool
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.25)
                .opacity(isOn ? 0 : 1)
            Circle()
                .fill(.primary)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.background)
                .scaleEffect(isOn ? 1 : 0.2)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: size, height: size)
        .contentShape(.circle)
    }
}

/// Trailing metadata: time or day (red when overdue), then the agent glyph. All quiet gray.
struct RowMeta: View {
    let text: String?
    var overdue = false
    let source: String

    var body: some View {
        HStack(spacing: 5) {
            if let text {
                Text(text)
                    .foregroundStyle(overdue ? AnyShapeStyle(Theme.overdue) : AnyShapeStyle(.tertiary))
                    .monospacedDigit()
            }
            if let symbol = Theme.symbol(for: source) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
                    .accessibilityLabel("Added by \(Theme.label(for: source))")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .lineLimit(1)
        .fixedSize()
    }
}
