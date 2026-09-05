import CoreGraphics
import simd

/// One measured destination for the physical cover and its interactive view.
/// The plaque is deliberately outside the moving Book's coordinate system.
struct BookstoreSelectionLayout {
    let viewport: CGSize

    var bookWidth: CGFloat { viewport.width * 0.80 }
    var canvasSize: CGSize {
        CGSize(width: bookWidth * 1.20, height: bookWidth * 1.445)
    }
    var coverCenter: CGPoint {
        CGPoint(x: viewport.width * 0.5 + bookWidth * 0.10,
                y: viewport.height * 0.478)
    }
    func plaqueFrame(height: CGFloat) -> CGRect {
        CGRect(x: viewport.width * 0.02,
               y: coverCenter.y + canvasSize.height * 0.5 + 10,
               width: viewport.width * 0.96, height: height)
    }
}

enum BookstoreBookFocus: Equatable {
    case shelf
    case extracting(String)
    case presented(String)

    var editionID: String? {
        switch self {
        case .shelf: nil
        case .extracting(let id), .presented(let id): id
        }
    }
    var isPresented: Bool {
        if case .presented = self { return true }
        return false
    }
}

/// The retaining rail is at y = -0.39 in each pocket. Clear it vertically
/// before moving outward; the second leg bows away from the rack, then settles.
struct BookstoreExtractionPath {
    static let duration = 0.78
    static let liftFraction: Float = 0.32
    static let railTop: Float = -0.39 + 0.023
    static let clearance: Float = 0.07

    let origin: SIMD3<Float>
    let lifted: SIMD3<Float>
    let destination: SIMD3<Float>
    let outward: SIMD3<Float>
    let up: SIMD3<Float>

    static func liftDistance(lowestPoint: Float) -> Float {
        max(0, railTop + clearance - lowestPoint)
    }

    func presentationProgress(at progress: Float) -> Float {
        Self.smooth((progress - Self.liftFraction) / (1 - Self.liftFraction))
    }

    func position(at progress: Float) -> SIMD3<Float> {
        if progress <= Self.liftFraction {
            return simd_mix(origin, lifted,
                            SIMD3(repeating: Self.smooth(progress / Self.liftFraction)))
        }
        let t = presentationProgress(at: progress)
        let remaining = 1 - t
        let control1 = lifted + outward * 1.1
        let control2 = destination + up * 0.20
        return remaining * remaining * remaining * lifted
            + 3 * remaining * remaining * t * control1
            + 3 * remaining * t * t * control2
            + t * t * t * destination
    }

    private static func smooth(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Lower pockets have a Book immediately above them. They cannot use the
/// top pocket's vertical lift. Work in pocket coordinates so this also holds
/// after rotating the stand to any of its four faces.
struct BookstoreLowerPocketPath {
    static let duration = 1.02
    static let seatEnd: Float = 0.06
    static let tipEnd: Float = 0.26
    static let slideEnd: Float = 0.46
    static let clearEnd: Float = 0.56
    static let clearDepth: Float = 0.36

    let origin: BookstoreExtractionPose
    let destination: BookstoreExtractionPose
    let corners: [SIMD3<Float>]
    let seated: BookstoreExtractionPose
    let pivot: SIMD3<Float>
    let originalTop: Float

    init(origin: BookstoreExtractionPose, destination: BookstoreExtractionPose,
         minimum: SIMD3<Float>, maximum: SIMD3<Float>) {
        self.origin = origin
        self.destination = destination
        corners = [minimum.x, maximum.x].flatMap { x in
            [minimum.y, maximum.y].flatMap { y in
                [minimum.z, maximum.z].map { SIMD3<Float>(x, y, $0) }
            }
        }
        originalTop = corners.map { origin.point($0).y }.max()!
        let railY: Float = -0.39
        // Stay behind BOTH front wires while the Book still leans inward.
        // A pivot at the upper wire's tangent would cross the lower wire first.
        let contactZ: Float = 0.19
        let frontBottom = origin.point(SIMD3(0, minimum.y, maximum.z))
        let frontTop = origin.point(SIMD3(0, maximum.y, maximum.z))
        let fraction = (railY - frontBottom.y) / (frontTop.y - frontBottom.y)
        let frontZ = frontBottom.z + fraction * (frontTop.z - frontBottom.z)
        var contact = origin
        contact.position.z += max(0, contactZ - frontZ)
        seated = contact
        pivot = SIMD3(0, railY, contactZ)
    }

    func tipped(at amount: Float) -> BookstoreExtractionPose {
        // A shallow tip clears the upper Book while keeping the retained tail
        // inside the pocket; a dramatic tilt would hit the rear support wire.
        let rotation = simd_quatf(angle: 0.45 * amount, axis: SIMD3(1, 0, 0))
        var pose = seated
        pose.orientation = rotation * seated.orientation
        pose.position = pivot + rotation.act(seated.position - pivot)
        let top = corners.map { pose.point($0).y }.max()!
        let spine = pose.orientation.act(SIMD3<Float>(0, 1, 0))
        // The back/top corner initially rises slightly around the front rail.
        // Feed it down its spine by that measured amount, never into the Book above.
        pose.position -= spine * (max(0, top - originalTop) / spine.y)
        return pose
    }

    var released: BookstoreExtractionPose {
        var pose = tipped(at: 1)
        let lowest = corners.map { pose.point($0).y }.min()!
        let spine = pose.orientation.act(SIMD3<Float>(0, 1, 0))
        let lift = BookstoreExtractionPath.liftDistance(lowestPoint: lowest)
        // The bottom tier's taller Book automatically receives a longer slide.
        pose.position += spine * (lift / spine.y)
        return pose
    }

    var cleared: BookstoreExtractionPose {
        var pose = released
        let back = corners.map { pose.point($0).z }.min()!
        pose.position.z += max(0, Self.clearDepth - back)
        return pose
    }

    func pose(at progress: Float) -> BookstoreExtractionPose {
        if progress < Self.seatEnd {
            return origin.interpolated(to: seated, amount: smooth(progress / Self.seatEnd))
        }
        if progress < Self.tipEnd {
            return tipped(at: smooth((progress - Self.seatEnd) / (Self.tipEnd - Self.seatEnd)))
        }
        if progress < Self.slideEnd {
            return tipped(at: 1).interpolated(to: released,
                amount: smooth((progress - Self.tipEnd) / (Self.slideEnd - Self.tipEnd)))
        }
        if progress < Self.clearEnd {
            return released.interpolated(to: cleared,
                amount: smooth((progress - Self.slideEnd) / (Self.clearEnd - Self.slideEnd)))
        }
        let t = smooth((progress - Self.clearEnd) / (1 - Self.clearEnd))
        var result = cleared.interpolated(to: destination, amount: t)
        let start = cleared.position
        let end = destination.position
        let remaining = 1 - t
        result.position = remaining * remaining * remaining * start
            + 3 * remaining * remaining * t * (start + SIMD3(0, 0, 1.1))
            + 3 * remaining * t * t * (end + SIMD3(0, 0.20, 0))
            + t * t * t * end
        return result
    }

    private func smooth(_ value: Float) -> Float {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

struct BookstoreExtractionPose {
    var position: SIMD3<Float>
    var orientation: simd_quatf
    var scale: SIMD3<Float>

    init(transform: simd_float4x4) {
        position = SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let axes = simd_float3x3(
            SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        scale = SIMD3(simd_length(axes.columns.0), simd_length(axes.columns.1), simd_length(axes.columns.2))
        orientation = simd_quatf(simd_float3x3(
            axes.columns.0 / scale.x, axes.columns.1 / scale.y, axes.columns.2 / scale.z))
    }

    var transform: simd_float4x4 {
        var matrix = simd_float4x4(orientation)
        matrix.columns.0 *= scale.x
        matrix.columns.1 *= scale.y
        matrix.columns.2 *= scale.z
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }

    func point(_ point: SIMD3<Float>) -> SIMD3<Float> {
        position + orientation.act(point * scale)
    }

    func interpolated(to destination: Self, amount: Float) -> Self {
        var result = self
        result.position = simd_mix(position, destination.position, SIMD3(repeating: amount))
        result.orientation = simd_slerp(orientation, destination.orientation, amount)
        result.scale = simd_mix(scale, destination.scale, SIMD3(repeating: amount))
        return result
    }
}
