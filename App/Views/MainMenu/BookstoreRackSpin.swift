import Foundation

/// A flick loses momentum continuously and lands on a face without a second
/// snap/reacceleration. Absolute-time samples behave identically at any cadence.
struct BookstoreRackSpin: Sendable {
    let startAngle: Double
    let initialVelocity: Double
    let coastDuration: Double
    let destinationAngle: Double
    let duration: Double

    private static let friction = 1.6
    private static let captureSpeed = 0.4
    private static let settleRate = 12.0
    private static let settleDuration = 1.05
    private let coastEnd: Double
    private let captureVelocity: Double
    private let coastExponent: Double?

    init(startAngle: Double, releaseVelocity: Double, homeAngle: Double) {
        self.startAngle = startAngle.isFinite ? startAngle : 0
        initialVelocity = releaseVelocity.isFinite ? min(16, max(-16, releaseVelocity)) : 0
        let naturalEnd = self.startAngle + initialVelocity / Self.friction
        let home = homeAngle.isFinite ? homeAngle : 0
        let faceStep = Double.pi / 2
        var destination = home + ((naturalEnd - home) / faceStep).rounded() * faceStep
        if abs(initialVelocity) >= 2 {
            // Quantization must never send a physical flick back the way it came.
            if (destination - self.startAngle) * initialVelocity <= 0 {
                destination += initialVelocity > 0 ? faceStep : -faceStep
            }
            let travel = abs(destination - self.startAngle)
            let naturalDuration = log(abs(initialVelocity) / Self.captureSpeed) / Self.friction
                + Self.settleDuration
            duration = max(naturalDuration, 2 * travel / abs(initialVelocity))
            coastDuration = duration
            // Match finger speed at release and reach zero speed/acceleration at
            // rest. Larger flicks last longer; alignment is part of deceleration.
            coastExponent = abs(initialVelocity) * duration / travel
            coastEnd = destination
            captureVelocity = 0
        } else {
            coastDuration = 0
            duration = Self.settleDuration
            coastExponent = nil
            coastEnd = self.startAngle
            captureVelocity = initialVelocity
        }
        destinationAngle = destination
    }

    static func radiansPerPoint(viewportWidth: Double) -> Double {
        let width = viewportWidth.isFinite && viewportWidth > 0 ? viewportWidth : 402
        return 0.009 * 402 / max(240, width)
    }

    func angle(at elapsed: Double) -> Double {
        guard elapsed > 0 else { return startAngle }
        guard elapsed < duration else { return destinationAngle }
        if let exponent = coastExponent {
            return startAngle + (destinationAngle - startAngle)
                * (1 - pow(1 - elapsed / duration, exponent))
        }
        let t = elapsed - coastDuration
        let offset = coastEnd - destinationAngle
        let coefficient = captureVelocity + Self.settleRate * offset
        return destinationAngle + (offset + coefficient * t) * exp(-Self.settleRate * t)
    }

    func velocity(at elapsed: Double) -> Double {
        guard elapsed > 0 else { return initialVelocity }
        guard elapsed < duration else { return 0 }
        if let exponent = coastExponent {
            return initialVelocity * pow(1 - elapsed / duration, exponent - 1)
        }
        let t = elapsed - coastDuration
        let coefficient = captureVelocity + Self.settleRate * (coastEnd - destinationAngle)
        return (captureVelocity - Self.settleRate * coefficient * t) * exp(-Self.settleRate * t)
    }
}
