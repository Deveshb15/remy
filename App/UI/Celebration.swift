import SwiftUI

/// A one-shot burst of dots and sparkles from the checkbox. Skipped entirely under Reduce Motion.
struct Celebration: View {
    let trigger: Int
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Particle { let angle: Double, distance: CGFloat, size: CGFloat, color: Color, star: Bool }

    private var particles: [Particle] {
        let palette = [Theme.done, Theme.accent, tint, Theme.marigold]
        return (0..<14).map { i in
            let star = i % 4 == 3
            return Particle(angle: Double(i) / 14 * 2 * .pi + Double(trigger) * 0.37,
                            distance: CGFloat(18 + (i * 7) % 17), size: star ? 7 : CGFloat(3 + i % 3),
                            color: palette[i % palette.count], star: star)
        }
    }

    var body: some View {
        if !reduceMotion && trigger > 0 {
            ZStack {
                ForEach(Array(particles.enumerated()), id: \.offset) { _, p in
                    Group {
                        if p.star { Image(systemName: "sparkle").font(.system(size: p.size, weight: .bold)) }
                        else { Circle().frame(width: p.size, height: p.size) }
                    }
                    .foregroundStyle(p.color)
                    .keyframeAnimator(initialValue: Burst(), trigger: trigger) { view, b in
                        view
                            .offset(x: cos(p.angle) * p.distance * b.progress, y: sin(p.angle) * p.distance * b.progress)
                            .scaleEffect(b.scale)
                            .opacity(b.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.progress) {
                            CubicKeyframe(0, duration: 0.06)
                            SpringKeyframe(1, duration: 0.5, spring: .smooth)
                        }
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(0, duration: 0.06)
                            SpringKeyframe(1.1, duration: 0.2, spring: .bouncy)
                            CubicKeyframe(0.4, duration: 0.4)
                        }
                        KeyframeTrack(\.opacity) {
                            CubicKeyframe(0, duration: 0.05)
                            LinearKeyframe(1, duration: 0.05)
                            LinearKeyframe(1, duration: 0.25)
                            CubicKeyframe(0, duration: 0.3)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private struct Burst { var progress: CGFloat = 0; var scale: CGFloat = 0; var opacity: Double = 0 }
}
