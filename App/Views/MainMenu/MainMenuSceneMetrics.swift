import SwiftUI

/// Where everything in the club room is, in one place.
///
/// The room was composed at 941 × 1672, and it is placed on the screen by one
/// transform: a single scale and a single origin, exactly as a photograph is
/// fitted to a frame. That is the whole point of this type.
///
/// It used to size objects from the screen's *width* and anchor them from its
/// *height*, which is a subtler mistake than it sounds: two objects that
/// touched in the composition stop touching on any device whose proportions
/// differ from the reference, because their sizes and their positions are
/// being scaled by different numbers. Every phone tested was tall, so every
/// phone reproduced the same wrong answer, and the room read as a stack of
/// cards floating over a picture of a room.
///
/// Extra screen is absorbed by showing more wall and cabinet — the scene fills
/// the frame and is cropped — never by opening up the gaps between objects.
struct MainMenuSceneMetrics: Equatable {

    /// The composition the reference artwork was drawn at.
    static let reference = CGSize(width: 941, height: 1672)

    let size: CGSize
    let safeArea: EdgeInsets

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }

    private var top: CGFloat { safeArea.top }
    private var band: CGFloat { max(1, height - safeArea.top - safeArea.bottom) }

    // MARK: The one transform

    /// Aspect-*fit*, not fill.
    ///
    /// Both are single transforms and either would fix the grounding bug; the
    /// difference is where the surplus goes. Filling a phone that is much
    /// taller than the composition crops four per cent off each side, and what
    /// lives at the sides of this composition is the gear, the note and the
    /// pencil pot — content, not scenery. Fitting instead leaves slack on the
    /// long axis, and that slack is absorbed by the two neutral areas that
    /// already stretch to the screen edges: more wall above, more cabinet
    /// below. No gap between objects ever changes.
    var sceneScale: CGFloat {
        min(width / Self.reference.width, band / Self.reference.height)
    }

    /// Where reference (0, 0) lands.
    var sceneOrigin: CGPoint {
        CGPoint(x: (width - Self.reference.width * sceneScale) / 2,
                y: top + (band - Self.reference.height * sceneScale) / 2)
    }

    /// Everything that draws detail inside an object — a bevel, a screw, a
    /// grain line — measures itself against this, so detail scales with the
    /// object it belongs to.
    var scale: CGFloat { sceneScale }

    /// Converts a rect in reference coordinates into one on this screen.
    /// Position and size come from the same number, which is the only reason
    /// two things that touched in the composition still touch here.
    func frame(_ reference: CGRect) -> CGRect {
        CGRect(x: sceneOrigin.x + reference.minX * sceneScale,
               y: sceneOrigin.y + reference.minY * sceneScale,
               width: reference.width * sceneScale,
               height: reference.height * sceneScale)
    }

    func x(_ reference: CGFloat) -> CGFloat { sceneOrigin.x + reference * sceneScale }
    func y(_ reference: CGFloat) -> CGFloat { sceneOrigin.y + reference * sceneScale }
    func length(_ reference: CGFloat) -> CGFloat { reference * sceneScale }

    /// How much room there is, judged against the composition rather than
    /// against a device list. Below this the props start standing down.
    var isCompact: Bool { width < 380 || height < 760 }
    var isVeryCompact: Bool { width < 360 || height < 700 }

    // MARK: The surfaces things rest on
    //
    // Named planes, not rectangles that happen to end at roughly the same
    // height. Anything standing on the desk takes its base from `deskContactY`
    // and cannot drift off it.

    /// Reference-space landmarks. The composition, written down once.
    private enum Ref {
        static let deskBack: CGFloat = 1006       // where the desk meets the wall
        static let deskSurface: CGFloat = 66      // the depth of the top, seen at an angle
        static let deskEdge: CGFloat = 18         // the bullnose along the front
        /// The two drawers, and what is mounted to each. Their tops are below
        /// the desk's front edge, because a drawer is in the carcass and the
        /// carcass is under the worktop.
        static let drawerOne = CGRect(x: 14, y: 1078, width: 913, height: 296)
        static let drawerTwo = CGRect(x: 14, y: 1372, width: 913, height: 258)
        /// Sized to leave room inside the drawer for the plate they are
        /// screwed to. A face that fills its drawer edge to edge has nowhere
        /// for a mount to show, and reads as a card again.
        static let play = CGSize(width: 520, height: 230)
        static let shop = CGSize(width: 490, height: 180)
    }

    /// The back of the desk top, against the wall.
    var deskBackY: CGFloat { y(Ref.deskBack) }

    /// The line objects standing on the desk have their feet on. Not the back
    /// of the surface and not its front edge: a little forward of the back,
    /// where the eye reads the plane as being.
    var deskContactY: CGFloat { y(Ref.deskBack + Ref.deskSurface * 0.62) }

    /// The front edge of the top, where the bullnose begins.
    var deskEdgeY: CGFloat { y(Ref.deskBack + Ref.deskSurface) }
    var deskEdgeHeight: CGFloat { length(Ref.deskEdge) }
    var deskSurfaceHeight: CGFloat { length(Ref.deskSurface) }

    /// Kept for the room's own drawing: the top of the wooden mass.
    var cabinetTop: CGFloat { deskBackY }
    /// Where the carcass — and therefore the drawers — begins.
    var drawerTop: CGFloat { deskEdgeY + deskEdgeHeight }

    /// The wall, from the top of the screen down to the desk.
    var wallPlane: CGRect {
        CGRect(x: 0, y: 0, width: width, height: max(0, deskBackY))
    }

    var drawerOneRect: CGRect { frame(Ref.drawerOne) }
    var drawerTwoRect: CGRect { frame(Ref.drawerTwo) }

    // MARK: The objects

    var lampFrame: CGRect { frame(CGRect(x: -8, y: 0, width: 268, height: 310)) }

    /// Clamped up to a comfortable target: the gear is 89 units in the
    /// composition, which lands under 44 on a small phone, and 44 is not
    /// negotiable. Also kept on screen when the scene is cropped horizontally.
    var settingsFrame: CGRect {
        let rect = frame(CGRect(x: 817, y: 47, width: 89, height: 89))
        let side = max(rect.width, 46)
        let x = min(max(rect.midX - side / 2, 12), width - side - 12)
        let y = max(top + 6, rect.midY - side / 2)
        return CGRect(x: x, y: y, width: side, height: side)
    }

    var titlePlaqueFrame: CGRect { frame(CGRect(x: 202, y: 239, width: 530, height: 265)) }
    var subtitlePlaqueFrame: CGRect { frame(CGRect(x: 234, y: 531, width: 476, height: 84)) }

    /// The board stands on the desk. Its height comes from the composition and
    /// its *bottom* comes from the plane it rests on — never from a reference
    /// rectangle that happens to end near one.
    var boardFrame: CGRect {
        var rect = frame(CGRect(x: 272, y: 656, width: 396, height: 414))
        rect.origin.y = deskContactY - rect.height
        return rect
    }

    /// The pencil pot and the succulent, standing on the same plane.
    var leftPropsFrame: CGRect {
        var rect = frame(CGRect(x: 0, y: 646, width: 218, height: 420))
        rect.origin.y = deskContactY - rect.height
        return rect
    }

    /// The shelf and the books under it. The shelf hangs on the wall, so this
    /// one keeps its composed top and stretches down to the desk instead.
    var rightPropsFrame: CGRect {
        var rect = frame(CGRect(x: 705, y: 118, width: 236, height: 950))
        rect.size.height = max(1, deskContactY - rect.minY)
        return rect
    }

    /// Both controls are mounted to a drawer, and take their place from it.
    var playFrame: CGRect { mounted(size: Ref.play, on: drawerOneRect, minimumHeight: 64) }
    var shopFrame: CGRect { mounted(size: Ref.shop, on: drawerTwoRect, minimumHeight: 56) }

    /// The plate a control is screwed to: the drawer's own recess, a little
    /// larger than the face that moves inside it.
    func mountingPlate(for face: CGRect) -> CGRect {
        face.insetBy(dx: -length(24), dy: -length(22))
    }

    private func mounted(size faceSize: CGSize, on drawer: CGRect,
                         minimumHeight: CGFloat) -> CGRect {
        let w = length(faceSize.width)
        let h = max(length(faceSize.height), minimumHeight)
        return CGRect(x: drawer.midX - w / 2, y: drawer.midY - h / 2, width: w, height: h)
    }

    /// Taped to the cabinet beside the Shop panel, and kept fully on screen
    /// when the scene is cropped in from the sides.
    var humourNoteFrame: CGRect {
        var rect = frame(CGRect(x: 726, y: 1331, width: 203, height: 238))
        if isVeryCompact { rect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06) }
        rect.origin.x = min(rect.origin.x, width - rect.width - 8)
        return rect
    }

    /// The bulb, in screen coordinates. Every light in the room is aimed from
    /// this one point, so nothing can disagree about where the lamp is.
    var bulbCentre: CGPoint {
        CGPoint(x: lampFrame.midX + lampFrame.width * 0.04,
                y: lampFrame.maxY - lampFrame.height * 0.10)
    }
}
