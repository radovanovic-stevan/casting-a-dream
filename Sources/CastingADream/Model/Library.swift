import AppKit

/// Games found in ~/Games/<System>, plus when each was last played.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var lastPlayed: [String: Date] = [:]
    @Published private(set) var hasScanned = false

    nonisolated static let gamesRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games")

    private var scanTask: Task<Void, Never>?

    init() {
        lastPlayed = Self.loadRecents()
    }

    nonisolated static func folder(for system: GameSystem) -> URL {
        gamesRoot.appendingPathComponent(system.folderName, isDirectory: true)
    }

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            let found = await Task.detached(priority: .userInitiated) {
                GameSystem.allCases.flatMap { Self.scan(system: $0, in: Self.folder(for: $0)) }
            }.value
            guard !Task.isCancelled else { return }
            if found != games { games = found }
            hasScanned = true
        }
    }

    func markPlayed(_ game: Game) {
        lastPlayed[game.id] = Date()
        Self.saveRecents(lastPlayed)
    }

    func openFolder(_ system: GameSystem) {
        let folder = Self.folder(for: system)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    // MARK: - Scanning

    /// One game per subfolder (its best playable file), plus playable files loose in the system folder.
    nonisolated static func scan(system: GameSystem, in root: URL) -> [Game] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles]) else { return [] }
        var games: [Game] = []
        for item in items {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                let files = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil,
                                                         options: [.skipsHiddenFiles])) ?? []
                if let best = bestGameFile(in: files, for: system) {
                    games.append(Game(system: system, url: best, folder: item, name: item.lastPathComponent))
                }
            } else if system.extensions.contains(item.pathExtension.lowercased()) {
                games.append(Game(system: system, url: item, folder: nil,
                                  name: item.deletingPathExtension().lastPathComponent))
            }
        }
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func bestGameFile(in files: [URL], for system: GameSystem) -> URL? {
        for ext in system.extensions {
            let matches = files.filter { $0.pathExtension.lowercased() == ext }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            if let first = matches.first { return first }
        }
        return nil
    }

    // MARK: - Recently played

    private static var recentsURL: URL {
        AppPaths.support.appendingPathComponent("recents.json")
    }

    private static func loadRecents() -> [String: Date] {
        guard let data = try? Data(contentsOf: recentsURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: Date].self, from: data)) ?? [:]
    }

    private static func saveRecents(_ recents: [String: Date]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(recents) else { return }
        try? FileManager.default.createDirectory(at: AppPaths.support, withIntermediateDirectories: true)
        try? data.write(to: recentsURL, options: .atomic)
    }
}

enum AppPaths {
    /// ~/Library/Application Support/Casting a Dream
    static let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Casting a Dream", isDirectory: true)
}
