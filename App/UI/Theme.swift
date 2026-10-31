import SwiftUI
import WidgetKit

/// Design tokens from docs/design/visual-spec.md. Monochrome: system label colors only, red reserved for overdue.
enum Theme {
    static let overdue = Color.red

    /// Agent glyphs, drawn in the same tertiary gray as the rest of the metadata.
    static func symbol(for source: String) -> String? {
        let s = source.lowercased()
        if s == "you" { return nil }
        if s.contains("claude") { return "sparkle" }
        if s.contains("codex") { return "chevron.left.forwardslash.chevron.right" }
        if s == "cli" { return "terminal" }
        return "circle.hexagongrid"
    }

    static func label(for source: String) -> String { source }

    enum Motion {
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.65)
        static let pop = Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.72)
        static let settle = Animation.spring(response: 0.36, dampingFraction: 1.0)
        static let reduced = Animation.easeInOut(duration: 0.18)

        static func named(_ a: Animation, reduceMotion: Bool) -> Animation { reduceMotion ? reduced : a }
    }
}

/// Circular checkbox (Todoist-style legibility): open = 1.5pt ring with a faint fill, red when overdue;
/// done = solid disc with the check cut *out* of the shape, so it reads on any background,
/// including the clear/tinted widget styles where a "background-coloured" check would vanish.
struct CheckGlyph: View {
    let isOn: Bool
    var size: CGFloat = 16
    var overdue = false

    var body: some View {
        let ring: AnyShapeStyle = overdue ? AnyShapeStyle(Theme.overdue) : AnyShapeStyle(.secondary)
        ZStack {
            Circle()
                .fill(overdue ? AnyShapeStyle(Theme.overdue.opacity(0.1)) : AnyShapeStyle(.primary.opacity(0.06)))
                .overlay(Circle().strokeBorder(ring, lineWidth: 1.5))
                .opacity(isOn ? 0 : 1)
            CheckDisc()
                .fill(.primary)
                .scaleEffect(isOn ? 1 : 0.3)
                .opacity(isOn ? 1 : 0)
        }
        .frame(width: size, height: size)
        .widgetAccentable()
        .contentShape(.circle)
    }
}

/// A filled circle with a rounded checkmark punched through it (true shape subtraction; no blend modes, so it works in widgets).
struct CheckDisc: Shape {
    func path(in r: CGRect) -> Path {
        var tick = Path()
        tick.move(to: CGPoint(x: r.minX + r.width * 0.29, y: r.minY + r.height * 0.52))
        tick.addLine(to: CGPoint(x: r.minX + r.width * 0.44, y: r.minY + r.height * 0.67))
        tick.addLine(to: CGPoint(x: r.minX + r.width * 0.72, y: r.minY + r.height * 0.37))
        let cut = tick.strokedPath(StrokeStyle(lineWidth: r.width * 0.13, lineCap: .round, lineJoin: .round))
        // Subtract (not even-odd): the stroke overlaps itself at the joint, which even-odd would turn into a notch.
        return Path(Path(ellipseIn: r).cgPath.subtracting(cut.cgPath))
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
