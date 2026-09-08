import SwiftUI
import ProbablySudokuEngine

/// Small authored stationery drawings, shared by a Book's selection label and
/// its inter-stage animation. These are not SF-symbol badges: the moving part
/// depicts that particular Book's benefit, and the scene uses its printed ink.
struct BookBenefitIllustration: View {
    let book: Book
    var time: TimeInterval = 0

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 88
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            BookBenefitIllustrationDrawing.draw(book: book, in: &context, time: time)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum BookBenefitIllustrationDrawing {
    static func draw(book: Book, in context: inout GraphicsContext, time: TimeInterval) {
        let theme = BookPresentationTheme(book: book)
        let ink = theme.buttonFill
        let tint = theme.accent.opacity(0.20)
        let t = time.isFinite ? time : 0
        let wave = CGFloat(sin(t * 1.25))
        let slow = CGFloat(sin(t * 0.65))
        var lines = Path()

        switch book {
        case .probably:
            // The seventh card fans out from an otherwise ordinary hand.
            card(in: &context, center: CGPoint(x: -16, y: 4), angle: -19, digit: nil, ink: ink, tint: tint)
            card(in: &context, center: CGPoint(x: 0, y: 1), angle: -3, digit: nil, ink: ink, tint: tint)
            card(in: &context, center: CGPoint(x: 17 + wave * 3, y: -3 - abs(wave) * 4),
                 angle: 13 + Double(wave) * 4, digit: String(book.benefit.after), ink: ink, tint: tint)
            line(&lines, -30, -27, -33, -32)
            line(&lines, -23, -30, -23, -36)
            line(&lines, 29, 29, 34, 33)

        case .slightlyHarder:
            // The opening float adds a coin to a neatly pencilled stack.
            for row in 0..<3 {
                let y = CGFloat(row) * 7 + 7
                ellipse(in: &context, rect: CGRect(x: -28, y: y, width: 34, height: 12), ink: ink, tint: tint)
            }
            coin(in: &context, center: CGPoint(x: 15, y: -10 - (wave + 1) * 5), radius: 15, ink: ink, tint: tint)
            line(&lines, -26, -20, -18, -20)
            line(&lines, -22, -24, -22, -16)
            line(&lines, 29, 22, 34, 19)

        case .noPressure:
            // A desk lamp bends slightly, lighting a single useful clue.
            let lean = slow * 4
            line(&lines, -29, 29, -3, 29)
            line(&lines, -16, 29, -16, 5)
            line(&lines, -16, 5, 4 + lean, -19)
            let shade = polygon([CGPoint(x: -3 + lean, y: -26), CGPoint(x: 14 + lean, y: -27),
                                 CGPoint(x: 24 + lean, y: -11), CGPoint(x: -11 + lean, y: -10)])
            context.fill(shade, with: .color(tint))
            context.stroke(shade, with: .color(ink), lineWidth: 2)
            for ray in 0..<3 {
                let x = CGFloat(ray) * 10 - 3 + lean
                line(&lines, x, -2, x + CGFloat(ray - 1) * 3, 7 + (wave + 1) * 3)
            }
            let note = Path(roundedRect: CGRect(x: 4, y: 15, width: 27, height: 18), cornerRadius: 2)
            context.fill(note, with: .color(Paper.page))
            context.stroke(note, with: .color(ink), lineWidth: 1.5)
            line(&lines, 14, 24, 17, 27)
            line(&lines, 17, 27, 23, 19)

        case .bites:
            // A bite in the clock face; the extra turn has a real clock hand.
            let rim = polygon([CGPoint(x: 27, y: -15), CGPoint(x: 16, y: -11), CGPoint(x: 24, y: -4),
                               CGPoint(x: 14, y: 2), CGPoint(x: 23, y: 8), CGPoint(x: 28, y: 17),
                               CGPoint(x: 16, y: 30), CGPoint(x: -15, y: 30), CGPoint(x: -30, y: 14),
                               CGPoint(x: -30, y: -14), CGPoint(x: -13, y: -30), CGPoint(x: 12, y: -29)])
            context.fill(rim, with: .color(tint))
            context.stroke(rim, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            for mark in 0..<9 {
                let angle = Double(mark) * .pi / 6 + .pi / 2
                let start = point(angle, 21), end = point(angle, 24)
                line(&lines, start.x, start.y, end.x, end.y)
            }
            line(&lines, 0, 0, -11, -8)
            let hand = point(-.pi / 2 + Double(wave) * 0.25, 17)
            line(&lines, 0, 0, hand.x, hand.y)

        case .genuinely:
            // One more toss: a number leaves, another falls into the hand.
            card(in: &context, center: CGPoint(x: -15, y: 10), angle: -13, digit: nil, ink: ink, tint: tint)
            card(in: &context, center: CGPoint(x: 12 + wave * 5, y: -5 - (wave + 1) * 6),
                 angle: 12 + Double(wave) * 12, digit: nil, ink: ink, tint: tint)
            lines.addArc(center: CGPoint(x: 0, y: 1), radius: 33,
                         startAngle: .degrees(205), endAngle: .degrees(315), clockwise: false)
            line(&lines, 23, -23, 26, -33)
            line(&lines, 26, -33, 16, -31)
            heart(in: &context, center: CGPoint(x: -15, y: 10), size: 8, ink: ink)

        case .snackBreak:
            // A finished little box earns the next cup of tea.
            let cup = Path(roundedRect: CGRect(x: -25, y: 2, width: 36, height: 26), cornerRadius: 5)
            context.fill(cup, with: .color(tint))
            context.stroke(cup, with: .color(ink), lineWidth: 2)
            lines.addArc(center: CGPoint(x: 12, y: 12), radius: 9,
                         startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            line(&lines, -31, 32, 22, 32)
            for curl in 0..<2 {
                let x = CGFloat(curl) * 13 - 18
                lines.move(to: CGPoint(x: x, y: -3))
                lines.addCurve(to: CGPoint(x: x + wave * 4, y: -28),
                               control1: CGPoint(x: x + 9 + wave * 3, y: -12),
                               control2: CGPoint(x: x - 9, y: -18))
            }
            grid(in: &context, rect: CGRect(x: 20, y: -17, width: 18, height: 18), ink: ink, tint: tint)

        case .trustMe:
            // The safety net is an eraser: its one rubbed-out mistake is not
            // a promise that later mistakes are free too.
            let slide = wave * 5
            var eraser = context
            eraser.translateBy(x: slide, y: -1)
            eraser.rotate(by: .degrees(-19))
            let outline = Path(roundedRect: CGRect(x: -25, y: -13, width: 46, height: 28), cornerRadius: 5)
            eraser.fill(outline, with: .color(tint))
            eraser.stroke(outline, with: .color(ink), lineWidth: 2.6)
            var seam = Path()
            line(&seam, 4, -12, 4, 14)
            eraser.stroke(seam, with: .color(ink), lineWidth: 1.8)
            // A ribbed paper sleeve keeps the eraser readable at the real
            // 48-point interlude size, not just in its larger plaque drawing.
            var sleeve = Path()
            for rib in 0..<3 {
                let x = CGFloat(rib) * 5 - 18
                line(&sleeve, x, -6, x, 8)
            }
            eraser.stroke(sleeve, with: .color(ink),
                          style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            for crumb in 0..<5 {
                let x = CGFloat(crumb) * 8 - 20
                line(&lines, x, 29, x + 3, 28 + CGFloat(crumb % 2))
            }
            line(&lines, -31, 20, -20 - slide, 20)
            line(&lines, 18 - slide, 20, 31, 20)

        case .overthinking:
            // A pencil makes a considered check on an actual little invoice.
            let receipt = Path(roundedRect: CGRect(x: -24, y: -30, width: 37, height: 60), cornerRadius: 2)
            context.fill(receipt, with: .color(Paper.page))
            context.stroke(receipt, with: .color(ink), lineWidth: 1.5)
            for row in 0..<4 { line(&lines, -17, CGFloat(row) * 9 - 18, 5, CGFloat(row) * 9 - 18) }
            var pencil = context
            pencil.translateBy(x: 17 + wave * 4, y: 3 + wave * 2)
            pencil.rotate(by: .degrees(29))
            let body = polygon([CGPoint(x: -4, y: -30), CGPoint(x: 4, y: -30),
                                CGPoint(x: 4, y: 18), CGPoint(x: 0, y: 27), CGPoint(x: -4, y: 18)])
            pencil.fill(body, with: .color(tint))
            pencil.stroke(body, with: .color(ink), lineWidth: 2)
            line(&lines, -15, 21, -10, 25)
            line(&lines, -10, 25, -2, 16)

        case .smallVictories:
            // A modest laurel opens around a completed 3x3 box.
            grid(in: &context, rect: CGRect(x: -15, y: -14, width: 30, height: 30), ink: ink, tint: tint)
            for side: CGFloat in [-1, 1] {
                lines.move(to: CGPoint(x: side * 4, y: 32))
                lines.addQuadCurve(to: CGPoint(x: side * (25 + slow * 3), y: -30),
                                   control: CGPoint(x: side * (44 + slow * 4), y: 6))
                for leaf in 0..<4 {
                    let y = CGFloat(leaf) * 11 - 22
                    line(&lines, side * 27, y + 8, side * 35, y + 1)
                }
            }

        case .rainyDay:
            // Rain moves; the reserve stays safely under its umbrella.
            lines.move(to: CGPoint(x: -30, y: -7))
            lines.addCurve(to: CGPoint(x: 30, y: -7),
                           control1: CGPoint(x: -28, y: -37), control2: CGPoint(x: 28, y: -37))
            for section in 0..<3 {
                let x = CGFloat(30 - section * 20)
                lines.addQuadCurve(to: CGPoint(x: x - 20, y: -7),
                                   control: CGPoint(x: x - 10, y: -15))
            }
            line(&lines, 0, -29, 0, 15)
            coin(in: &context, center: CGPoint(x: 0, y: 25), radius: 11, ink: ink, tint: tint)
            for drop in 0..<4 {
                let progress = (t * 13 + Double(drop) * 12).truncatingRemainder(dividingBy: 44) / 44
                let y = CGFloat(progress * 44) - 30
                let x: CGFloat = drop.isMultiple(of: 2) ? -36 : 35
                var rain = context
                rain.opacity = sin(max(0, progress) * .pi)
                var dropPath = Path()
                line(&dropPath, x, y, x - 2, y + 5)
                rain.stroke(dropPath, with: .color(ink),
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            }

        case .secondThoughts:
            // The first draft is crossed out; the clean page turns beside it.
            card(in: &context, center: CGPoint(x: -15, y: 3), angle: -10, digit: nil, ink: ink, tint: tint)
            card(in: &context, center: CGPoint(x: 15 + slow * 3, y: -1),
                 angle: 8 + Double(slow) * 7, digit: nil, ink: ink, tint: tint)
            line(&lines, -27, -7, -5, 10)
            line(&lines, -25, 12, -5, -10)
            lines.addArc(center: CGPoint(x: 0, y: 0), radius: 34,
                         startAngle: .degrees(218), endAngle: .degrees(308), clockwise: false)
            line(&lines, 21, -27, 29, -25)
            line(&lines, 29, -25, 28, -33)

        case .wellEarned:
            // A biscuit on a little saucer, with celebratory crumbs settling.
            ellipse(in: &context, rect: CGRect(x: -33, y: 19, width: 66, height: 13), ink: ink, tint: tint)
            var biscuit = Path()
            for corner in 0..<32 {
                let angle = Double(corner) * .pi / 16
                let p = point(angle, corner.isMultiple(of: 2) ? 25 : 22.5)
                if corner == 0 { biscuit.move(to: p) } else { biscuit.addLine(to: p) }
            }
            biscuit.closeSubpath()
            context.fill(biscuit, with: .color(tint))
            context.stroke(biscuit, with: .color(ink), lineWidth: 2)
            for offset in [CGPoint(x: -8, y: -8), CGPoint(x: 8, y: -7),
                           CGPoint(x: 0, y: 3), CGPoint(x: -7, y: 10), CGPoint(x: 10, y: 10)] {
                context.fill(Path(ellipseIn: CGRect(x: offset.x, y: offset.y, width: 2, height: 2)),
                             with: .color(ink))
            }
            for side: CGFloat in [-1, 1] {
                let height = 8 + abs(wave) * 9
                line(&lines, side * 31, -height, side * 36, -height - 4)
            }
        }

        context.stroke(lines, with: .color(ink.opacity(0.92)),
                       style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }

    private static func card(in context: inout GraphicsContext, center: CGPoint, angle: Double,
                             digit: String?, ink: Color, tint: Color) {
        var card = context
        card.translateBy(x: center.x, y: center.y)
        card.rotate(by: .degrees(angle))
        let paper = Path(roundedRect: CGRect(x: -14, y: -22, width: 28, height: 44), cornerRadius: 3)
        card.fill(paper, with: .color(Paper.page))
        card.stroke(paper, with: .color(ink), lineWidth: 1.8)
        card.fill(Path(CGRect(x: -10, y: 14, width: 20, height: 4)), with: .color(tint))
        if let digit {
            card.draw(Text(digit).font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(ink), at: CGPoint(x: 0, y: -1))
        }
    }

    private static func coin(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat,
                             ink: Color, tint: Color) {
        ellipse(in: &context, rect: CGRect(x: center.x - radius, y: center.y - radius,
                                           width: radius * 2, height: radius * 2), ink: ink, tint: tint)
        context.draw(Text("N").font(.system(size: radius, weight: .heavy)).foregroundStyle(ink), at: center)
    }

    private static func grid(in context: inout GraphicsContext, rect: CGRect, ink: Color, tint: Color) {
        context.fill(Path(rect), with: .color(Paper.page))
        context.fill(Path(CGRect(x: rect.minX + rect.width / 3, y: rect.minY + rect.height / 3,
                                 width: rect.width / 3, height: rect.height / 3)), with: .color(tint))
        var grid = Path(rect)
        for index in 1...2 {
            let delta = CGFloat(index) / 3
            line(&grid, rect.minX + rect.width * delta, rect.minY, rect.minX + rect.width * delta, rect.maxY)
            line(&grid, rect.minX, rect.minY + rect.height * delta, rect.maxX, rect.minY + rect.height * delta)
        }
        context.stroke(grid, with: .color(ink), lineWidth: 1.3)
    }

    private static func heart(in context: inout GraphicsContext, center: CGPoint, size: CGFloat, ink: Color) {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y + size * 0.6))
        path.addCurve(to: center, control1: CGPoint(x: center.x - size * 1.5, y: center.y - size * 0.5),
                      control2: CGPoint(x: center.x - size * 0.4, y: center.y - size))
        path.addCurve(to: CGPoint(x: center.x, y: center.y + size * 0.6),
                      control1: CGPoint(x: center.x + size * 0.4, y: center.y - size),
                      control2: CGPoint(x: center.x + size * 1.5, y: center.y - size * 0.5))
        context.fill(path, with: .color(ink))
    }

    private static func ellipse(in context: inout GraphicsContext, rect: CGRect, ink: Color, tint: Color) {
        let ellipse = Path(ellipseIn: rect)
        context.fill(ellipse, with: .color(Paper.page))
        context.fill(ellipse, with: .color(tint))
        context.stroke(ellipse, with: .color(ink), lineWidth: 1.8)
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private static func line(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
    }

    private static func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
    }
}
