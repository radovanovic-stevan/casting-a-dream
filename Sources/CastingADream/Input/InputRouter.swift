import AppKit
import GameController

/// Keyboard and game controller navigation for the library.
/// Both only act while the launcher is the active app; controllers deliver input to the
/// foreground app only, so the launcher ignores them while an emulator is playing.
@MainActor
final class InputRouter {
    private weak var model: AppModel?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var repeaters: [ObjectIdentifier: DirectionRepeater] = [:]

    func install(model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        installKeyboard()
        installControllers()
    }

    // MARK: - Keyboard

    private enum Key {
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let escape: UInt16 = 53
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    private func installKeyboard() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model, model.launcher.running == nil else { return event }
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty { return event }

            // Typing in the search field: leave the keys to it, except to step out into the grid.
            let editingText = NSApp.keyWindow?.firstResponder is NSTextView
            if editingText {
                switch event.keyCode {
                case Key.down, Key.returnKey, Key.enter:
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    model.selectFirstIfNeeded()
                    return nil
                case Key.escape:
                    model.search = ""
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    return nil
                default:
                    return event
                }
            }

            switch event.keyCode {
            case Key.left: model.moveSelection(dx: -1, dy: 0)
            case Key.right: model.moveSelection(dx: 1, dy: 0)
            case Key.up: model.moveSelection(dx: 0, dy: -1)
            case Key.down: model.moveSelection(dx: 0, dy: 1)
            case Key.returnKey, Key.enter: model.playSelected()
            case Key.escape:
                if !model.search.isEmpty { model.search = "" } else { model.selectedID = nil }
            default: return event
            }
            return nil
        }
    }

    // MARK: - Controllers

    private func installControllers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.configure(controller) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.repeaters[ObjectIdentifier(controller)] = nil }
        })
        GCController.controllers().forEach(configure)
    }

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        controller.handlerQueue = .main
        let repeater = DirectionRepeater { [weak self] dx, dy in self?.model?.moveSelection(dx: dx, dy: dy) }
        repeaters[ObjectIdentifier(controller)] = repeater

        pad.dpad.valueChangedHandler = { _, x, y in
            MainActor.assumeIsolated { repeater.update(source: 0, x: x, y: y) }
        }
        pad.leftThumbstick.valueChangedHandler = { _, x, y in
            MainActor.assumeIsolated { repeater.update(source: 1, x: x, y: y) }
        }
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            MainActor.assumeIsolated { self?.ifIdle { $0.playSelected() } }
        }
        pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            MainActor.assumeIsolated { self?.ifIdle { $0.search.isEmpty ? ($0.selectedID = nil) : ($0.search = "") } }
        }
        pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            MainActor.assumeIsolated { self?.ifIdle { $0.cycleFilter(by: -1) } }
        }
        pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            MainActor.assumeIsolated { self?.ifIdle { $0.cycleFilter(by: 1) } }
        }
    }

    private func ifIdle(_ action: (AppModel) -> Void) {
        guard let model, model.launcher.running == nil, NSApp.isActive else { return }
        action(model)
    }
}

/// Turns stick / D-pad positions into single steps, repeating while held.
@MainActor
private final class DirectionRepeater {
    private let step: (Int, Int) -> Void
    private var directions: [Int: (Int, Int)] = [:]
    private var timer: Timer?
    private var current: (Int, Int) = (0, 0)

    init(step: @escaping (Int, Int) -> Void) {
        self.step = step
    }

    func update(source: Int, x: Float, y: Float) {
        // Dominant axis only, with a dead zone. Controller "up" is +y, but the grid's up is -1.
        var direction = (0, 0)
        if abs(x) > 0.5 || abs(y) > 0.5 {
            direction = abs(x) >= abs(y) ? (x > 0 ? 1 : -1, 0) : (0, y > 0 ? -1 : 1)
        }
        directions[source] = direction
        let combined = directions.values.first { $0 != (0, 0) } ?? (0, 0)
        guard combined != current else { return }
        current = combined
        timer?.invalidate()
        timer = nil
        guard combined != (0, 0), NSApp.isActive else { return }

        step(combined.0, combined.1)
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.startRepeating() }
        }
    }

    private func startRepeating() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.current != (0, 0), NSApp.isActive else { return }
                self.step(self.current.0, self.current.1)
            }
        }
    }
}
