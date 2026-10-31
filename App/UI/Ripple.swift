import SwiftUI

/// One-shot ripple from the checkbox: a thin ring that grows and fades. Monochrome; skipped under Reduce Motion.
struct Ripple: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion && trigger > 0 {
            Circle()
                .stroke(.primary, lineWidth: 1)
                .keyframeAnimator(initialValue: Wave(), trigger: trigger) { view, w in
                    view.scaleEffect(w.scale).opacity(w.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1, duration: 0.04)
                        SpringKeyframe(2.4, duration: 0.55, spring: .smooth)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.35, duration: 0.04)
                        CubicKeyframe(0, duration: 0.5)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private struct Wave { var scale: CGFloat = 1; var opacity: Double = 0 }
}
