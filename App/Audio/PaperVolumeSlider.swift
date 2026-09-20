import SwiftUI
import UIKit

/// A printed reading beside a local UIKit control. UIKit owns the adjustable
/// accessibility element; the visible label is not a second VoiceOver stop.
struct PaperVolumeSlider: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    let title: String
    @Binding var value: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                name.frame(width: 86 * textScale, alignment: .leading)
                control.frame(minWidth: 80)
                reading.frame(width: 38 * textScale, alignment: .trailing)
            }
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    name
                    Spacer(minLength: 0)
                    reading
                }
                control
            }
        }
        .foregroundStyle(theme.paper.ink)
    }

    private var name: some View {
        Text(title).font(Print.body(14 * textScale))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    private var reading: some View {
        Text(PaperVolumeValue.label(value))
            .font(Print.numeral(12 * textScale, weight: .semibold))
            .monospacedDigit().fixedSize()
            .accessibilityHidden(true)
    }

    private var control: some View {
        PaperVolumeControl(title: title, value: $value).frame(height: 44)
    }
}

/// One policy for pointer, keyboard/VoiceOver and the printed value. Reading a
/// legacy volume never rounds or rewrites it; deliberate pointer seeks use 5%.
enum PaperVolumeValue {
    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    static func label(_ value: Double) -> String {
        let clamped = clamped(value)
        guard clamped > 0 else { return "Muted" }
        let percent = Int((clamped * 100).rounded())
        return percent == 0 ? "<1%" : "\(percent)%"
    }

    static func seek(x: CGFloat, in track: CGRect, rightToLeft: Bool) -> Double? {
        guard x.isFinite, track.width.isFinite, track.width > 0 else { return nil }
        let fraction = clamped(Double((x - track.minX) / track.width))
        let directed = rightToLeft ? 1 - fraction : fraction
        return (directed * 20).rounded() / 20
    }

    static func adjusted(_ value: Double, by steps: Int) -> Double {
        clamped((clamped(value) * 100 + Double(steps * 5)).rounded() / 100)
    }

    static func isHorizontal(_ velocity: CGPoint) -> Bool {
        velocity.x.isFinite && velocity.y.isFinite && abs(velocity.x) > abs(velocity.y)
    }
}

struct PaperVolumeControl: UIViewRepresentable {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.layoutDirection) private var layoutDirection
    let title: String
    @Binding var value: Double

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeUIView(context: Context) -> PaperVolumeUIKitSlider {
        let slider = PaperVolumeUIKitSlider()
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: PaperVolumeUIKitSlider, context: Context) {
        // Refresh the binding too: this UIKit instance can outlive its parent's
        // current binding/selection. Never retain the first update's destination.
        context.coordinator.value = $value
        slider.isEnabled = isEnabled
        slider.semanticContentAttribute = layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
        slider.accessibilityLabel = "\(title) volume"
        slider.accessibilityIdentifier = "settings.volume.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))"
        slider.setDisplayedValue(value)
        slider.setPaperColors(ink: UIColor(theme.paper.ink), sage: UIColor(Paper.sageDeep),
                              ivory: UIColor(theme.paper.warm))
    }

    final class Coordinator: NSObject {
        var value: Binding<Double>
        init(value: Binding<Double>) { self.value = value }
        @objc func changed(_ sender: PaperVolumeUIKitSlider) {
            value.wrappedValue = (Double(sender.value) * 100).rounded() / 100
        }
    }
}

/// Custom imagery without UISlider.appearance or an invisible SwiftUI drag
/// layer. A direction-tested pan lets vertical gestures reach the article.
final class PaperVolumeUIKitSlider: UISlider, UIGestureRecognizerDelegate {
    let volumePan = UIPanGestureRecognizer()
    let trackTap = UITapGestureRecognizer()
    private var acceptsCurrentPan = false
    private var previousColors: [UIColor] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumValue = 0
        maximumValue = 1
        isContinuous = true
        isAccessibilityElement = true
        accessibilityTraits = [.adjustable]
        accessibilityHint = "Swipe up or down to change by five percent. Zero mutes."
        volumePan.maximumNumberOfTouches = 1
        volumePan.delegate = self
        volumePan.addTarget(self, action: #selector(handlePan(_:)))
        addGestureRecognizer(volumePan)
        trackTap.delegate = self
        trackTap.addTarget(self, action: #selector(handleTap(_:)))
        trackTap.require(toFail: volumePan)
        addGestureRecognizer(trackTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 44) }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + 14, y: bounds.midY - 5,
               width: max(0, bounds.width - 28), height: 10)
    }

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let fraction = CGFloat(PaperVolumeValue.clamped(Double(value)))
        let directed = effectiveUserInterfaceLayoutDirection == .rightToLeft ? 1 - fraction : fraction
        return CGRect(x: rect.minX + rect.width * directed - 17, y: rect.midY - 18,
                      width: 34, height: 36)
    }

    // UISlider's eager tracking would otherwise claim a vertical gesture before
    // its direction is known. The pan/tap recognizers below are the sole writers.
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { false }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard isEnabled else { return false }
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            return PaperVolumeValue.isHorizontal(pan.velocity(in: self))
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The enclosing ScrollView waits only until this pan knows its axis.
        // A vertical start fails our pan and therefore scrolls without a seek.
        guard gestureRecognizer === volumePan,
              let scroll = otherGestureRecognizer.view as? UIScrollView,
              otherGestureRecognizer === scroll.panGestureRecognizer else { return false }
        return isDescendant(of: scroll)
    }

    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            acceptsCurrentPan = isEnabled && PaperVolumeValue.isHorizontal(pan.velocity(in: self))
            if acceptsCurrentPan { seek(at: pan.location(in: self)) }
        case .changed, .ended:
            if acceptsCurrentPan && isEnabled { seek(at: pan.location(in: self)) }
            if pan.state == .ended { acceptsCurrentPan = false }
        case .cancelled, .failed:
            acceptsCurrentPan = false
        default: break
        }
    }

    @objc func handleTap(_ tap: UITapGestureRecognizer) {
        guard isEnabled, tap.state == .ended else { return }
        seek(at: tap.location(in: self))
    }

    private func seek(at point: CGPoint) {
        guard let next = PaperVolumeValue.seek(x: point.x, in: trackRect(forBounds: bounds),
                    rightToLeft: effectiveUserInterfaceLayoutDirection == .rightToLeft) else { return }
        commit(next)
    }

    func setDisplayedValue(_ next: Double) {
        setValue(Float(PaperVolumeValue.clamped(next)), animated: false)
        accessibilityValue = PaperVolumeValue.label(next)
    }

    private func commit(_ next: Double) {
        guard isEnabled else { return }
        let next = Float(PaperVolumeValue.clamped(next))
        guard next != value else { return }
        setDisplayedValue(Double(next))
        sendActions(for: .valueChanged)
    }

    override func accessibilityIncrement() { commit(PaperVolumeValue.adjusted(Double(value), by: 1)) }
    override func accessibilityDecrement() { commit(PaperVolumeValue.adjusted(Double(value), by: -1)) }

    func setPaperColors(ink: UIColor, sage: UIColor, ivory: UIColor) {
        let colors = [ink, sage, ivory]
        guard colors != previousColors else { return }
        previousColors = colors
        let filled = Self.rail(color: sage, outline: ink.withAlphaComponent(0.5))
        let empty = Self.rail(color: ink.withAlphaComponent(0.55), outline: ink.withAlphaComponent(0.6))
        let knob = Self.knob(ivory: ivory, ink: ink, sage: sage)
        for state in [UIControl.State.normal, .highlighted, .disabled] {
            setMinimumTrackImage(filled, for: state)
            setMaximumTrackImage(empty, for: state)
            setThumbImage(knob, for: state)
        }
    }

    private static func rail(color: UIColor, outline: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 12)).image { context in
            let rect = CGRect(x: 1, y: 2, width: 22, height: 8)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
            color.setFill(); path.fill()
            outline.setStroke(); path.lineWidth = 1; path.stroke()
            context.cgContext.saveGState()
            path.addClip()
            UIColor.black.withAlphaComponent(0.13).setStroke()
            let inset = UIBezierPath(roundedRect: rect.offsetBy(dx: 0, dy: -1), cornerRadius: 4)
            inset.lineWidth = 2; inset.stroke()
            context.cgContext.restoreGState()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
    }

    private static func knob(ivory: UIColor, ink: UIColor, sage: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 34, height: 36)).image { context in
            let circle = UIBezierPath(ovalIn: CGRect(x: 3, y: 2, width: 28, height: 28))
            context.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 2,
                                        color: ink.withAlphaComponent(0.22).cgColor)
            ivory.setFill(); circle.fill()
            context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            ink.withAlphaComponent(0.35).setStroke(); circle.lineWidth = 1; circle.stroke()
            let rim = UIBezierPath(ovalIn: CGRect(x: 5, y: 4, width: 24, height: 24))
            UIColor.white.withAlphaComponent(0.6).setStroke(); rim.lineWidth = 1; rim.stroke()
            sage.setStroke()
            for x in [14.0, 17.0, 20.0] {
                let grip = UIBezierPath()
                grip.move(to: CGPoint(x: x, y: 12)); grip.addLine(to: CGPoint(x: x, y: 20))
                grip.lineWidth = 1.4; grip.lineCapStyle = .round; grip.stroke()
            }
        }
    }
}
