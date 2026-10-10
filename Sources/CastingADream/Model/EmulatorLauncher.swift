import AppKit

/// Opens a game in its system's emulator, as an ordinary app with its own window, Dock icon and menus,
/// and keeps track of it until it quits.
@MainActor
final class EmulatorLauncher: ObservableObject {
    @Published private(set) var running: Game?
    @Published var errorMessage: String?

    private var runningApp: NSRunningApplication?
    private var terminationObserver: NSObjectProtocol?
    private var quitObserver: NSObjectProtocol?
    /// System uptime when the emulator started. Uptime stops while the Mac sleeps,
    /// so a game left open overnight doesn't count the night.
    private var sessionStart: TimeInterval?
    private var onSessionEnded: ((TimeInterval) -> Void)?

    /// How long Stop Game waits for the emulator to quit on its own before forcing it.
    private static let stopTimeout: TimeInterval = 5

    init() {
        // Quitting the launcher also quits the game it started, so nothing keeps running unseen.
        // The session is recorded now: the launcher won't be around to see the emulator quit.
        quitObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let app = self.runningApp else { return }
                self.endSession()
                app.terminate()
            }
        }
    }

    /// The installed copy in /Applications or ~/Applications. macOS also knows about copies in build
    /// folders and the Trash, and its default pick can be one of those.
    static func emulatorURL(for system: GameSystem) -> URL? {
        let copies = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: system.emulatorBundleID)
            .filter { !$0.path.contains("/.Trash/") }
        let applicationFolders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
            .map { $0.standardizedFileURL.path + "/" }
        return copies.first { url in applicationFolders.contains { url.standardizedFileURL.path.hasPrefix($0) } }
            ?? copies.first
    }

    /// `onStarted` runs once the emulator is up; `onEnded` gets the session's play time when it quits.
    func launch(_ game: Game, fullScreen: Bool,
                onStarted: @escaping () -> Void, onEnded: @escaping (TimeInterval) -> Void) {
        if running != nil {
            showRunningGame()
            return
        }
        let system = game.system
        guard let emulator = Self.emulatorURL(for: system) else {
            errorMessage = "\(system.emulatorName) isn't installed. Put \(system.emulatorName).app in Applications and try again."
            return
        }
        // A copy opened by hand would ignore the game we pass, and two copies would share one config.
        if !NSRunningApplication.runningApplications(withBundleIdentifier: system.emulatorBundleID).isEmpty {
            errorMessage = "\(system.emulatorName) is already open. Quit it first, then start the game again."
            return
        }
        guard FileManager.default.fileExists(atPath: game.url.path) else {
            errorMessage = "The game file is no longer there:\n\(game.url.path)"
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = system.launchArguments(for: game.url, fullScreen: fullScreen)
        configuration.activates = true
        configuration.addsToRecentItems = false

        running = game
        NSWorkspace.shared.openApplication(at: emulator, configuration: configuration) { app, error in
            Task { @MainActor in
                guard let app else {
                    self.running = nil
                    self.errorMessage = "\(game.title) couldn't be started: \(error?.localizedDescription ?? "unknown error")."
                    return
                }
                self.sessionStart = ProcessInfo.processInfo.systemUptime
                self.onSessionEnded = onEnded
                onStarted()
                self.track(app)
            }
        }
    }

    func showRunningGame() {
        guard let runningApp else { return }
        NSApp.yieldActivation(to: runningApp)
        runningApp.activate()
    }

    /// Asks the emulator to quit like Cmd+Q would, and forces it if it hasn't after a few seconds.
    func stopRunningGame() {
        guard let app = runningApp else { return }
        app.terminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopTimeout) {
            if !app.isTerminated {
                app.forceTerminate()
            }
        }
    }

    private func track(_ app: NSRunningApplication) {
        runningApp = app
        let pid = app.processIdentifier
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let ended = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  ended.processIdentifier == pid else { return }
            MainActor.assumeIsolated { self?.emulatorDidQuit() }
        }
        // It may already have quit (e.g. a broken image) before the observer was in place.
        if app.isTerminated {
            emulatorDidQuit()
        }
    }

    /// Reports the play time once per session.
    private func endSession() {
        guard let start = sessionStart else { return }
        sessionStart = nil
        let callback = onSessionEnded
        onSessionEnded = nil
        callback?(ProcessInfo.processInfo.systemUptime - start)
    }

    private func emulatorDidQuit() {
        endSession()
        if let terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver)
        }
        terminationObserver = nil
        runningApp = nil
        running = nil
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }
}
