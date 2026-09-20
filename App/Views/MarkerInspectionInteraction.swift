import SwiftUI
import UIKit

/// Two mutually exclusive native recognizers own a cell's entire touch. A
/// successful hold makes the tap recognizer fail, including on cancellation.
/// No SwiftUI Button is underneath it to receive the eventual finger-up.
struct MarkerCellTouchSurface: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    var canInspect: () -> Bool
    var onTap: () -> Void
    var onBegin: () -> Void
    var onEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(canInspect: canInspect, onTap: onTap, onBegin: onBegin, onEnd: onEnd)
    }

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isAccessibilityElement = false
        view.backgroundColor = .clear
        view.addGestureRecognizer(context.coordinator.holdRecognizer)
        view.addGestureRecognizer(context.coordinator.tapRecognizer)
        view.onDetach = { [weak coordinator = context.coordinator] in coordinator?.invalidate() }
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        let coordinator = context.coordinator
        coordinator.canInspect = canInspect
        coordinator.onTap = onTap
        coordinator.onBegin = onBegin
        coordinator.onEnd = onEnd
        if !isEnabled || !canInspect() { coordinator.invalidate() }
        view.isUserInteractionEnabled = isEnabled
    }

    static func dismantleUIView(_ view: TouchView, coordinator: Coordinator) {
        coordinator.invalidate()
        view.onDetach = nil
    }

    final class TouchView: UIView {
        var onDetach: (() -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { onDetach?() }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var canInspect: () -> Bool
        var onTap: () -> Void
        var onBegin: () -> Void
        var onEnd: () -> Void
        private var consumed = false
        private var inspecting = false
        let tapRecognizer = UITapGestureRecognizer()
        let holdRecognizer = UILongPressGestureRecognizer()

        init(canInspect: @escaping () -> Bool, onTap: @escaping () -> Void,
             onBegin: @escaping () -> Void, onEnd: @escaping () -> Void) {
            self.canInspect = canInspect
            self.onTap = onTap
            self.onBegin = onBegin
            self.onEnd = onEnd
            super.init()
            holdRecognizer.minimumPressDuration = 0.4
            holdRecognizer.allowableMovement = 10
            holdRecognizer.cancelsTouchesInView = true
            holdRecognizer.delegate = self
            holdRecognizer.addTarget(self, action: #selector(hold(_:)))
            tapRecognizer.delegate = self
            tapRecognizer.addTarget(self, action: #selector(tap(_:)))
            tapRecognizer.require(toFail: holdRecognizer)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            // Called at the start of a new physical touch, never on release.
            if gestureRecognizer === holdRecognizer, gestureRecognizer.state == .possible { beginTouch() }
            return true
        }

        func beginTouch() {
            guard !inspecting else { return }
            consumed = false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer !== holdRecognizer || canInspect()
        }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, !consumed else { return }
            onTap()
        }

        @objc func hold(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                guard !consumed else { return }
                // Even an eligibility change at recognition must consume this
                // hold; it must never become a late placement instead.
                consumed = true
                guard canInspect() else { return }
                inspecting = true
                onBegin()
            case .changed:
                if !canInspect() || recognizer.view.map({ !$0.bounds.insetBy(dx: -10, dy: -10)
                    .contains(recognizer.location(in: $0)) }) == true { invalidate() }
            case .ended, .cancelled, .failed:
                invalidate()
            default: break
            }
        }

        func invalidate() {
            guard inspecting else { return }
            inspecting = false
            onEnd()
            // Deliberately retain consumed until the next touch begins.
        }
    }
}
