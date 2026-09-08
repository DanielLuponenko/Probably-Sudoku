import SwiftUI
import ProbablySudokuEngine

/// A little animated paper world in a space reserved by the page. It accepts
/// its parent's exact bounds and never asks the surrounding print to move.
struct BookLivingScene: View {
    let book: Book
    var isActive = true

    var body: some View {
        BookAmbientBackground(book: book, isActive: isActive, presentation: .livingScene)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Pure time-to-artwork rendering for screenshots and motion regression tests.
/// The full composition, not a single enlarged badge, belongs to this Book.
struct BookLivingSceneArtwork: View {
    let book: Book
    var time: TimeInterval = 0

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            let scale = min(size.height / 112, 1.25)
            context.translateBy(x: 0, y: (size.height - 112 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            BookLivingSceneDrawing(book: book, time: time)
                .draw(in: &context, width: size.width / scale)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BookLivingSceneDrawing {
    let book: Book
    let time: TimeInterval

    private var theme: BookPresentationTheme { BookPresentationTheme(book: book) }
    private var ink: Color { theme.buttonFill }
    private var wash: Color { theme.accent.opacity(0.20) }
    private var stock: Color { Paper.page.mixed(with: .white, by: 0.18) }
    private var t: Double { time.isFinite ? max(0, time) : 0 }

    func draw(in context: inout GraphicsContext, width w: CGFloat) {
        // Contact marks ground the paper objects, without a realistic desk,
        // decorative container, or another label competing with the route.
        var desk = Path()
        line(&desk, w * 0.08, 97, w * 0.35, 97)
        line(&desk, w * 0.67, 97, w * 0.92, 97)
        context.stroke(desk, with: .color(ink.opacity(0.18)), lineWidth: 1)
        switch book {
        case .probably: dealtHand(in: &context, width: w)
        case .slightlyHarder: rollingSavings(in: &context, width: w)
        case .noPressure: illuminatedClue(in: &context, width: w)
        case .bites: bittenDeadline(in: &context, width: w)
        case .genuinely: luckyToss(in: &context, width: w)
        case .snackBreak: teaBreak(in: &context, width: w)
        case .trustMe: chasingEraser(in: &context, width: w)
        case .overthinking: editorialCommittee(in: &context, width: w)
        case .smallVictories: modestParade(in: &context, width: w)
        case .rainyDay: shelteredSavings(in: &context, width: w)
        case .secondThoughts: secondDraft(in: &context, width: w)
        case .wellEarned: earnedBiscuit(in: &context, width: w)
        }
    }

    private func dealtHand(in context: inout GraphicsContext, width w: CGFloat) {
        closedBook(in: &context, center: CGPoint(x: w * 0.17, y: 66), width: 56, height: 57)
        let center = CGPoint(x: w * 0.61, y: 66)
        for index in 0..<6 {
            let offset = CGFloat(index) - 2.5
            card(in: &context, center: CGPoint(x: center.x + offset * 15, y: center.y + abs(offset) * 2.8),
                 width: 35, height: 48, angle: Double(offset) * 9, digit: [2, 7, 4, 6, 5, 4][index])
        }
        let p = cycle(7)
        let deal = ease(min(1, p / 0.62))
        var moving = context
        moving.opacity = appear(p)
        card(in: &moving,
             center: CGPoint(x: mix(w * 0.17, center.x + 60, deal),
                             y: 65 - 40 * sin(.pi * deal)),
             width: 35, height: 48, angle: -25 + 55 * deal, digit: 1)
        var flourish = Path()
        line(&flourish, w * 0.15, 21, w * 0.14, 12)
        line(&flourish, w * 0.18, 20, w * 0.19, 10)
        context.stroke(flourish, with: .color(ink.opacity(0.5)), lineWidth: 1.4)
    }

    private func rollingSavings(in context: inout GraphicsContext, width w: CGFloat) {
        receipt(in: &context, center: CGPoint(x: w * 0.23, y: 61), angle: -8, rows: 4)
        saucer(in: &context, center: CGPoint(x: w * 0.76, y: 86), width: 73)
        for row in 0..<3 {
            let y = 77 - CGFloat(row) * 6
            ellipse(in: &context, CGRect(x: w * 0.76 - 21, y: y, width: 42, height: 10), fill: wash)
        }
        let p = cycle(5.8), travel = ease(min(1, p / 0.8))
        var rolling = context
        rolling.opacity = appear(p)
        coin(in: &rolling, center: CGPoint(x: mix(w * 0.34, w * 0.76, travel),
                                          y: 64 - 24 * sin(.pi * travel)),
             radius: 15, angle: 480 * travel)
        var trail = Path()
        line(&trail, w * 0.39, 85, w * 0.48, 85)
        line(&trail, w * 0.43, 89, w * 0.51, 89)
        context.stroke(trail, with: .color(ink.opacity(0.35)), lineWidth: 1.3)
    }

    private func illuminatedClue(in context: inout GraphicsContext, width w: CGFloat) {
        let lean = CGFloat(sin(t * 0.7)) * 7
        let lamp = w * 0.22
        var beam = Path()
        beam.move(to: CGPoint(x: lamp + 19 + lean, y: 36))
        beam.addLine(to: CGPoint(x: w * 0.66 + 29, y: 86))
        beam.addLine(to: CGPoint(x: w * 0.55 - 28, y: 86))
        beam.closeSubpath()
        context.fill(beam, with: .color(theme.accent.opacity(0.10)))
        var frame = Path()
        line(&frame, lamp - 23, 89, lamp + 19, 89)
        line(&frame, lamp - 4, 88, lamp - 4, 57)
        line(&frame, lamp - 4, 57, lamp + 17 + lean, 27)
        context.stroke(frame, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        let shade = polygon([CGPoint(x: lamp + lean, y: 21), CGPoint(x: lamp + 26 + lean, y: 17),
                             CGPoint(x: lamp + 43 + lean, y: 40), CGPoint(x: lamp - 11 + lean, y: 43)])
        context.fill(shade, with: .color(wash))
        context.stroke(shade, with: .color(ink), lineWidth: 1.6)
        gridCard(in: &context, center: CGPoint(x: w * 0.63, y: 65), side: 56, angle: -3, completedRow: false)
        pencil(in: &context, tip: CGPoint(x: w * 0.66 + 10 * sin(t * 1.1), y: 73),
               angle: 34 + 7 * sin(t * 0.7), length: 68)
    }

    private func bittenDeadline(in context: inout GraphicsContext, width w: CGFloat) {
        let c = CGPoint(x: w * 0.25, y: 59)
        ellipse(in: &context, CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60), fill: stock)
        ellipse(in: &context, CGRect(x: c.x - 25, y: c.y - 25, width: 50, height: 50), fill: wash)
        var clock = Path()
        for tick in 0..<12 {
            let a = Double(tick) * .pi / 6
            line(&clock, c.x + CGFloat(cos(a)) * 22, c.y + CGFloat(sin(a)) * 22,
                 c.x + CGFloat(cos(a)) * 25, c.y + CGFloat(sin(a)) * 25)
        }
        let angle = t * 0.5 - .pi / 2
        line(&clock, c.x, c.y, c.x + CGFloat(cos(angle)) * 19, c.y + CGFloat(sin(angle)) * 19)
        line(&clock, c.x, c.y, c.x - 8, c.y - 10)
        line(&clock, c.x - 16, 86, c.x - 22, 94)
        line(&clock, c.x + 16, 86, c.x + 22, 94)
        context.stroke(clock, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        var ticket = context
        ticket.translateBy(x: w * 0.72, y: 58)
        ticket.rotate(by: .degrees(5 + 5 * sin(t * 0.9)))
        let bite = polygon([CGPoint(x: -35, y: -35), CGPoint(x: 35, y: -35),
                            CGPoint(x: 35, y: -20), CGPoint(x: 25, y: -14),
                            CGPoint(x: 34, y: -7), CGPoint(x: 23, y: 0),
                            CGPoint(x: 33, y: 7), CGPoint(x: 26, y: 16),
                            CGPoint(x: 35, y: 22), CGPoint(x: 35, y: 35), CGPoint(x: -35, y: 35)])
        ticket.fill(bite, with: .color(stock))
        ticket.stroke(bite, with: .color(ink), lineWidth: 1.7)
        drawText("+1", in: &ticket, at: CGPoint(x: -3, y: -3), size: 25)
        var rules = Path()
        line(&rules, -25, -24, 17, -24); line(&rules, -25, 24, 17, 24)
        ticket.stroke(rules, with: .color(theme.accent), lineWidth: 1.3)
    }

    private func luckyToss(in context: inout GraphicsContext, width w: CGFloat) {
        for index in 0..<3 {
            card(in: &context, center: CGPoint(x: w * 0.19 + CGFloat(index) * 6, y: 70 - CGFloat(index) * 3),
                 width: 36, height: 48, angle: Double(index - 1) * 8, digit: index == 2 ? 8 : nil)
        }
        clover(in: &context, center: CGPoint(x: w * 0.52, y: 48), angle: 10 * sin(t * 0.7))
        card(in: &context, center: CGPoint(x: w * 0.81, y: 72), width: 37, height: 49, angle: 8, digit: 5)
        let p = cycle(6.8), travel = ease(min(1, p / 0.77))
        var tossed = context
        tossed.opacity = appear(p)
        card(in: &tossed, center: CGPoint(x: mix(w * 0.22, w * 0.79, travel),
                                         y: 66 - 41 * sin(.pi * travel)),
             width: 35, height: 47, angle: -22 + travel * 55, digit: 3)
    }

    private func teaBreak(in context: inout GraphicsContext, width w: CGFloat) {
        gridCard(in: &context, center: CGPoint(x: w * 0.23, y: 65), side: 59, angle: -8, completedRow: true)
        cup(in: &context, center: CGPoint(x: w * 0.66, y: 70), width: 57)
        steam(in: &context, center: CGPoint(x: w * 0.66, y: 44), phase: t)
        var spoon = context
        spoon.translateBy(x: w * 0.86, y: 66)
        spoon.rotate(by: .degrees(17 + 5 * sin(t * 0.8)))
        ellipse(in: &spoon, CGRect(x: -6, y: -24, width: 12, height: 18), fill: wash)
        var handle = Path(); line(&handle, 0, -7, 0, 28)
        spoon.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
    }

    private func chasingEraser(in context: inout GraphicsContext, width w: CGFloat) {
        let eraserX = w * 0.30 + w * 0.37 * CGFloat((sin(t * 0.84 - .pi / 2) + 1) / 2)
        paper(in: &context, center: CGPoint(x: w * 0.5, y: 66), width: w * 0.75, height: 50, angle: -2)
        var scribble = Path()
        for segment in 0..<42 {
            let x = w * 0.20 + CGFloat(segment) * w * 0.014
            guard abs(x - eraserX) > 28 else { continue }
            line(&scribble, x, 72 + CGFloat(segment % 3) * 2,
                 x + w * 0.009, 65 + CGFloat(segment % 4))
        }
        context.stroke(scribble, with: .color(ink.opacity(0.52)), lineWidth: 1.4)
        pencil(in: &context, tip: CGPoint(x: w * 0.24 + 9 * sin(t * 1.3), y: 67), angle: -35, length: 65)
        var eraser = context
        eraser.translateBy(x: eraserX, y: 62)
        eraser.rotate(by: .degrees(-15 + 6 * sin(t * 0.84)))
        let shape = Path(roundedRect: CGRect(x: -27, y: -16, width: 54, height: 32), cornerRadius: 5)
        eraser.fill(shape, with: .color(stock)); eraser.stroke(shape, with: .color(ink), lineWidth: 2)
        eraser.fill(Path(CGRect(x: -24, y: -13, width: 33, height: 26)), with: .color(wash))
        var sleeve = Path(); line(&sleeve, 9, -15, 9, 15)
        for rib in 0..<4 { line(&sleeve, CGFloat(rib) * 6 - 18, -8, CGFloat(rib) * 6 - 18, 8) }
        eraser.stroke(sleeve, with: .color(ink.opacity(0.75)), lineWidth: 1.3)
        for crumb in 0..<7 {
            let x = eraserX - 37 + CGFloat(crumb) * 9
            let y = 88 + CGFloat(crumb % 2) * 3 + CGFloat(sin(t * 0.84 + Double(crumb)))
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 1.5)), with: .color(ink.opacity(0.65)))
        }
    }

    private func editorialCommittee(in context: inout GraphicsContext, width w: CGFloat) {
        receipt(in: &context, center: CGPoint(x: w * 0.27, y: 60), angle: -12, rows: 5)
        receipt(in: &context, center: CGPoint(x: w * 0.43, y: 56), angle: 5, rows: 5)
        let p = CGFloat((sin(t * 0.8) + 1) / 2)
        pencil(in: &context, tip: CGPoint(x: w * 0.39 + p * 33, y: 70), angle: 29 + Double(p) * 5, length: 78)
        var revision = Path()
        line(&revision, w * 0.39, 70, w * 0.39 + p * 33, 70)
        revision.move(to: CGPoint(x: w * 0.6, y: 57))
        revision.addQuadCurve(to: CGPoint(x: w * 0.82, y: 67), control: CGPoint(x: w * 0.74, y: 25))
        line(&revision, w * 0.82 - 9, 64, w * 0.82, 67)
        line(&revision, w * 0.82, 67, w * 0.82 - 1, 58)
        context.stroke(revision, with: .color(theme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        card(in: &context, center: CGPoint(x: w * 0.84, y: 77), width: 30, height: 37, angle: -6, digit: 3)
    }

    private func modestParade(in context: inout GraphicsContext, width w: CGFloat) {
        let lift = CGFloat((sin(t * 0.85) + 1) / 2) * 9
        gridCard(in: &context, center: CGPoint(x: w * 0.5, y: 57 - lift), side: 58, angle: 0, completedRow: true)
        var podium = Path()
        podium.addRect(CGRect(x: w * 0.5 - 43, y: 89, width: 86, height: 9))
        context.fill(podium, with: .color(stock))
        context.fill(podium, with: .color(wash))
        context.stroke(podium, with: .color(ink.opacity(0.78)), lineWidth: 1.2)
        for side: CGFloat in [-1, 1] {
            var branch = Path()
            branch.move(to: CGPoint(x: w * 0.5 + side * 45, y: 87))
            branch.addQuadCurve(to: CGPoint(x: w * 0.5 + side * 61, y: 17),
                                control: CGPoint(x: w * 0.5 + side * (80 + lift), y: 60))
            for leaf in 0..<5 {
                let y = CGFloat(leaf) * 12 + 25
                line(&branch, w * 0.5 + side * 62, y + 7,
                     w * 0.5 + side * (74 + lift * 0.35), y)
            }
            context.stroke(branch, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        confetti(in: &context, width: w, phase: cycle(6.5), color: theme.accent)
    }

    private func shelteredSavings(in context: inout GraphicsContext, width w: CGFloat) {
        let center = CGPoint(x: w * 0.3, y: 46)
        let sway = CGFloat(sin(t * 0.7)) * 6
        var rain = context
        for drop in 0..<16 {
            let p = cycle(2.8, offset: Double(drop) * 0.149)
            rain.opacity = sin(.pi * p) * 0.6
            let x = w * (0.06 + CGFloat(drop) * 0.058)
            let sheltered = abs(x - center.x) < 47
            let y = CGFloat(p) * (sheltered ? 22 : 72) + 9
            var streak = Path(); line(&streak, x + 2, y, x - 1, y + 7)
            rain.stroke(streak, with: .color(theme.accent), lineWidth: 1.4)
        }
        closedBook(in: &context, center: CGPoint(x: center.x, y: 81), width: 67, height: 27)
        var umbrella = context
        umbrella.translateBy(x: center.x + sway, y: center.y)
        let canopy = polygon([CGPoint(x: -46, y: 0), CGPoint(x: -36, y: -19), CGPoint(x: -18, y: -29),
                              CGPoint(x: 0, y: -33), CGPoint(x: 18, y: -29), CGPoint(x: 36, y: -19),
                              CGPoint(x: 46, y: 0), CGPoint(x: 25, y: -5), CGPoint(x: 10, y: 0),
                              CGPoint(x: -9, y: -5), CGPoint(x: -25, y: 0)])
        umbrella.fill(canopy, with: .color(stock)); umbrella.fill(canopy, with: .color(wash))
        umbrella.stroke(canopy, with: .color(ink), lineWidth: 1.6)
        var handle = Path(); line(&handle, 0, -32, 0, 30)
        handle.addQuadCurve(to: CGPoint(x: 14, y: 28), control: CGPoint(x: 10, y: 42))
        umbrella.stroke(handle, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        let jar = Path(roundedRect: CGRect(x: w * 0.72 - 29, y: 50, width: 58, height: 43), cornerRadius: 7)
        context.fill(jar, with: .color(stock)); context.stroke(jar, with: .color(ink), lineWidth: 1.8)
        for position in 0..<3 {
            coin(in: &context, center: CGPoint(x: w * 0.72 - 15 + CGFloat(position) * 15, y: 75),
                 radius: 11, angle: Double(position) * 17)
        }
    }

    private func secondDraft(in context: inout GraphicsContext, width w: CGFloat) {
        let shift = CGFloat(sin(t * 0.72)) * 15
        receipt(in: &context, center: CGPoint(x: w * 0.25 - shift, y: 63), angle: -12, rows: 4)
        var crossed = Path()
        line(&crossed, w * 0.25 - shift - 23, 41, w * 0.25 - shift + 18, 80)
        line(&crossed, w * 0.25 - shift - 21, 80, w * 0.25 - shift + 20, 42)
        context.stroke(crossed, with: .color(ink.opacity(0.76)), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
        receipt(in: &context, center: CGPoint(x: w * 0.73 + shift * 0.6, y: 57), angle: 5, rows: 3)
        var reconsider = Path()
        reconsider.move(to: CGPoint(x: w * 0.4, y: 49))
        reconsider.addQuadCurve(to: CGPoint(x: w * 0.6, y: 47), control: CGPoint(x: w * 0.51, y: 24))
        line(&reconsider, w * 0.6 - 10, 47, w * 0.6, 47)
        line(&reconsider, w * 0.6, 47, w * 0.6 - 2, 37)
        context.stroke(reconsider, with: .color(theme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func earnedBiscuit(in context: inout GraphicsContext, width w: CGFloat) {
        saucer(in: &context, center: CGPoint(x: w * 0.27, y: 89), width: 87)
        var biscuit = context
        biscuit.translateBy(x: w * 0.27, y: 55 + 6 * sin(t * 0.8))
        biscuit.rotate(by: .degrees(11 * sin(t * 0.8)))
        var edge = Path()
        for corner in 0..<40 {
            let a = Double(corner) * .pi / 20
            let r: CGFloat = corner.isMultiple(of: 2) ? 29 : 26
            let p = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
            if corner == 0 { edge.move(to: p) } else { edge.addLine(to: p) }
        }
        edge.closeSubpath()
        biscuit.fill(edge, with: .color(stock)); biscuit.fill(edge, with: .color(wash))
        biscuit.stroke(edge, with: .color(ink), lineWidth: 1.8)
        for dot in [CGPoint(x: -11, y: -11), CGPoint(x: 9, y: -10), CGPoint(x: 0, y: 0),
                    CGPoint(x: -9, y: 12), CGPoint(x: 13, y: 9)] {
            biscuit.fill(Path(ellipseIn: CGRect(x: dot.x, y: dot.y, width: 3, height: 3)), with: .color(ink.opacity(0.7)))
        }
        cup(in: &context, center: CGPoint(x: w * 0.75, y: 71), width: 48)
        steam(in: &context, center: CGPoint(x: w * 0.75, y: 45), phase: t + 1.4)
        for crumb in 0..<5 {
            let p = cycle(4.4, offset: Double(crumb) * 0.19)
            var falling = context; falling.opacity = sin(.pi * p)
            falling.fill(Path(CGRect(x: w * 0.39 + CGFloat(crumb) * 6, y: 59 + CGFloat(p) * 28,
                                     width: 2.8, height: 2.2)), with: .color(ink))
        }
    }

    // MARK: - Reusable paper objects, not a generic repeated scene

    @discardableResult
    private func paper(in context: inout GraphicsContext, center: CGPoint, width: CGFloat,
                       height: CGFloat, angle: Double) -> GraphicsContext {
        var page = context
        page.translateBy(x: center.x, y: center.y); page.rotate(by: .degrees(angle))
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        page.fill(Path(roundedRect: rect.offsetBy(dx: 1.5, dy: 2.5), cornerRadius: 2), with: .color(ink.opacity(0.10)))
        page.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(stock))
        page.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(ink.opacity(0.72)), lineWidth: 1.35)
        return page
    }

    private func card(in context: inout GraphicsContext, center: CGPoint, width: CGFloat,
                      height: CGFloat, angle: Double, digit: Int?) {
        var page = paper(in: &context, center: center, width: width, height: height, angle: angle)
        if let digit { drawText(String(digit), in: &page, at: .zero, size: height * 0.5) }
        else {
            page.fill(Path(CGRect(x: -width * 0.35, y: -height * 0.30, width: width * 0.7, height: height * 0.6)),
                      with: .color(wash))
        }
    }

    private func receipt(in context: inout GraphicsContext, center: CGPoint, angle: Double, rows: Int) {
        let page = paper(in: &context, center: center, width: 60, height: 76, angle: angle)
        page.fill(Path(CGRect(x: -21, y: -29, width: 42, height: 7)), with: .color(wash))
        var lines = Path()
        for row in 0..<rows {
            let y = CGFloat(row) * 10 - 12
            line(&lines, -21, y, row.isMultiple(of: 2) ? 17 : 8, y)
        }
        page.stroke(lines, with: .color(ink.opacity(0.45)), lineWidth: 1.2)
        var fold = Path(); line(&fold, 21, 28, 28, 28); line(&fold, 21, 28, 21, 36)
        page.stroke(fold, with: .color(ink.opacity(0.55)), lineWidth: 1)
    }

    private func gridCard(in context: inout GraphicsContext, center: CGPoint, side: CGFloat,
                          angle: Double, completedRow: Bool) {
        var grid = paper(in: &context, center: center, width: side, height: side, angle: angle)
        let inset: CGFloat = 5, pitch = (side - 2 * inset) / 3
        if completedRow {
            grid.fill(Path(CGRect(x: -side / 2 + inset, y: -side / 2 + inset + pitch,
                                  width: side - inset * 2, height: pitch)), with: .color(wash))
        }
        var rules = Path()
        for rule in 0...3 {
            let p = -side / 2 + inset + CGFloat(rule) * pitch
            line(&rules, -side / 2 + inset, p, side / 2 - inset, p)
            line(&rules, p, -side / 2 + inset, p, side / 2 - inset)
        }
        grid.stroke(rules, with: .color(ink.opacity(0.58)), lineWidth: 0.9)
        for cell in [0, 2, 4, 6, 8] {
            drawText(String([1, 4, 7, 3, 9][cell / 2]), in: &grid,
                     at: CGPoint(x: CGFloat(cell % 3 - 1) * pitch, y: CGFloat(cell / 3 - 1) * pitch), size: pitch * 0.67)
        }
    }

    private func closedBook(in context: inout GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat) {
        let cover = paper(in: &context, center: center, width: width, height: height, angle: -6)
        cover.fill(Path(CGRect(x: -width / 2, y: -height / 2, width: width, height: height - 5)), with: .color(wash))
        var spine = Path(); line(&spine, -width / 2 + 8, -height / 2, -width / 2 + 8, height / 2 - 5)
        for leaf in 0..<3 { line(&spine, -width / 2 + 3, height / 2 - CGFloat(leaf) * 2, width / 2 - 3, height / 2 - CGFloat(leaf) * 2) }
        cover.stroke(spine, with: .color(ink.opacity(0.55)), lineWidth: 0.8)
        cover.fill(Path(CGRect(x: width / 2 - 15, y: height / 2 - 5, width: 6, height: 12)), with: .color(theme.accent))
    }

    private func coin(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        var coin = context; coin.translateBy(x: center.x, y: center.y); coin.rotate(by: .degrees(angle))
        ellipse(in: &coin, CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), fill: stock)
        ellipse(in: &coin, CGRect(x: -radius + 3, y: -radius + 3, width: radius * 2 - 6, height: radius * 2 - 6), fill: wash)
        drawText("N", in: &coin, at: .zero, size: radius)
    }

    private func saucer(in context: inout GraphicsContext, center: CGPoint, width: CGFloat) {
        ellipse(in: &context, CGRect(x: center.x - width / 2, y: center.y - 6, width: width, height: 12), fill: stock)
        var rim = Path(); line(&rim, center.x - width * 0.30, center.y + 1, center.x + width * 0.30, center.y + 1)
        context.stroke(rim, with: .color(ink.opacity(0.25)), lineWidth: 1)
    }

    private func cup(in context: inout GraphicsContext, center: CGPoint, width: CGFloat) {
        saucer(in: &context, center: CGPoint(x: center.x, y: center.y + 22), width: width + 25)
        ellipse(in: &context, CGRect(x: center.x + width / 2 - 5, y: center.y - 12, width: 23, height: 25), fill: stock)
        let body = Path(roundedRect: CGRect(x: center.x - width / 2, y: center.y - 21, width: width, height: 41), cornerRadius: 10)
        context.fill(body, with: .color(stock)); context.stroke(body, with: .color(ink), lineWidth: 1.8)
        ellipse(in: &context, CGRect(x: center.x - width / 2, y: center.y - 23, width: width, height: 10), fill: wash)
        var heart = context; heart.translateBy(x: center.x, y: center.y + 1)
        let shape = polygon([CGPoint(x: -8, y: -5), CGPoint(x: -4, y: -8), CGPoint(x: 0, y: -4),
                             CGPoint(x: 4, y: -8), CGPoint(x: 8, y: -5), CGPoint(x: 6, y: 1),
                             CGPoint(x: 0, y: 7), CGPoint(x: -6, y: 1)])
        heart.fill(shape, with: .color(theme.accent))
    }

    private func steam(in context: inout GraphicsContext, center: CGPoint, phase: Double) {
        for curl in 0..<3 {
            var steam = Path()
            let x = center.x + CGFloat(curl - 1) * 13
            let sway = CGFloat(sin(phase * 1.1 + Double(curl))) * 10
            steam.move(to: CGPoint(x: x, y: center.y))
            steam.addCurve(to: CGPoint(x: x + sway * 0.6, y: center.y - 31),
                           control1: CGPoint(x: x + sway, y: center.y - 10),
                           control2: CGPoint(x: x - sway, y: center.y - 21))
            context.stroke(steam, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }

    private func pencil(in context: inout GraphicsContext, tip: CGPoint, angle: Double, length: CGFloat) {
        var pencil = context; pencil.translateBy(x: tip.x, y: tip.y); pencil.rotate(by: .degrees(angle))
        let silhouette = polygon([CGPoint(x: -4, y: -length), CGPoint(x: 4, y: -length),
                                  CGPoint(x: 4, y: -11), CGPoint(x: 0, y: 0), CGPoint(x: -4, y: -11)])
        pencil.fill(silhouette, with: .color(stock)); pencil.fill(silhouette, with: .color(wash))
        pencil.stroke(silhouette, with: .color(ink), lineWidth: 1.3)
        var rules = Path(); line(&rules, 0, -length + 8, 0, -12); line(&rules, -4, -length + 7, 4, -length + 7)
        line(&rules, -4, -11, 4, -11); line(&rules, -1, -3, 0, 0)
        pencil.stroke(rules, with: .color(ink.opacity(0.7)), lineWidth: 1)
    }

    private func clover(in context: inout GraphicsContext, center: CGPoint, angle: Double) {
        var plant = context; plant.translateBy(x: center.x, y: center.y); plant.rotate(by: .degrees(angle))
        for side in 0..<4 {
            let a = Double(side) * .pi / 2
            ellipse(in: &plant, CGRect(x: CGFloat(cos(a)) * 11 - 10, y: CGFloat(sin(a)) * 11 - 10,
                                      width: 20, height: 20), fill: wash)
        }
        var stem = Path(); stem.move(to: .zero)
        stem.addQuadCurve(to: CGPoint(x: 17, y: 41), control: CGPoint(x: -8, y: 27))
        plant.stroke(stem, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private func confetti(in context: inout GraphicsContext, width w: CGFloat, phase: Double, color: Color) {
        for piece in 0..<10 {
            let p = (phase + Double(piece) * 0.093).truncatingRemainder(dividingBy: 1)
            var confetti = context; confetti.opacity = sin(.pi * p) * 0.75
            let side: CGFloat = piece.isMultiple(of: 2) ? -1 : 1
            let x = w * 0.5 + side * (88 + CGFloat(piece % 3) * 10) + CGFloat(sin(p * .pi * 2)) * 6
            let y = 12 + CGFloat(p) * 75
            confetti.translateBy(x: x, y: y); confetti.rotate(by: .degrees(p * 100 + Double(piece) * 17))
            confetti.fill(Path(CGRect(x: -3, y: -1, width: 6, height: 2)), with: .color(color))
        }
    }

    private func ellipse(in context: inout GraphicsContext, _ rect: CGRect, fill: Color) {
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(fill)); context.stroke(path, with: .color(ink), lineWidth: 1.4)
    }

    private func drawText(_ value: String, in context: inout GraphicsContext, at point: CGPoint, size: CGFloat) {
        context.draw(Text(value).font(.system(size: size, weight: .semibold, design: .serif)).foregroundStyle(ink), at: point)
    }

    private func line(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2))
    }

    private func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first); points.dropFirst().forEach { path.addLine(to: $0) }; path.closeSubpath()
        return path
    }

    private func cycle(_ duration: Double, offset: Double = 0) -> Double {
        (t / duration + offset).truncatingRemainder(dividingBy: 1)
    }
    private func ease(_ value: Double) -> Double { value * value * (3 - 2 * value) }
    private func appear(_ value: Double) -> Double { min(1, min(value / 0.08, (1 - value) / 0.12)) }
    private func mix(_ from: CGFloat, _ to: CGFloat, _ progress: Double) -> CGFloat { from + (to - from) * progress }
}
