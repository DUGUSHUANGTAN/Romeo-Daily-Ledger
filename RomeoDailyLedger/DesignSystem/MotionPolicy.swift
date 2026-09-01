import Foundation

struct MotionPolicy: Equatable, Sendable {
    let requestedIntensity: Int
    let systemReduceMotion: Bool

    init(slider: Int, systemReduceMotion: Bool) {
        requestedIntensity = min(max(slider, 0), 100)
        self.systemReduceMotion = systemReduceMotion
    }

    var effectiveIntensity: Int { systemReduceMotion ? 0 : requestedIntensity }
    var duration: TimeInterval { effectiveIntensity == 0 ? 0 : 0.12 + (Double(effectiveIntensity) / 100 * 0.16) }
    var usesSpring: Bool { effectiveIntensity >= 50 }

    static func navigation(systemReduceMotion: Bool) -> MotionPolicy {
        MotionPolicy(slider: 42, systemReduceMotion: systemReduceMotion)
    }
}
