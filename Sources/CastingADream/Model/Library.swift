import AppKit

/// When a game was last played and for how long in total.
struct PlayStats: Codable, Equatable {
    var lastPlayed: Date
    var seconds: TimeInterval = 0
}

/// Games found in ~/Games/<System>, plus play history per game.
@MainActor
final class Library: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var stats: [String: PlayStats] = [:]
    @Published private(set) var hasScanned = false

    var lastPlayed: [String: Date] { stats.mapValues(\.lastPlayed) }

    nonisolated static let gamesRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Games")

    private var scanTask: Task<Void, Never>?

    init() {
        stats = Self.loadStats()
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
        stats[game.id, default: PlayStats(lastPlayed: Date())].lastPlayed = Date()
        Self.saveStats(stats)
    }

    func addPlayTime(_ seconds: TimeInterval, to game: Game) {
        guard seconds > 0 else { return }
        stats[game.id, default: PlayStats(lastPlayed: Date())].seconds += seconds
        Self.saveStats(stats)
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
                    games.append(Game(system: system, url: best, folder: item, name: item.lastPathComponent,
                                      collectionQuery: collectionQuery(in: item)))
                }
            } else if system.extensions.contains(item.pathExtension.lowercased()) {
                games.append(Game(system: system, url: item, folder: nil,
                                  name: item.deletingPathExtension().lastPathComponent))
            }
        }
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// First non-empty line of collection.txt in the game's folder, if there is one.
    nonisolated private static func collectionQuery(in folder: URL) -> String? {
        guard let text = try? String(contentsOf: folder.appendingPathComponent("collection.txt"), encoding: .utf8) else {
            return nil
        }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    nonisolated private static func bestGameFile(in files: [URL], for system: GameSystem) -> URL? {
        for ext in system.extensions {
            let matches = files.filter { $0.pathExtension.lowercased() == ext }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            if let first = matches.first { return first }
        }
        return nil
    }

    // MARK: - Play history

    private static var statsURL: URL { AppPaths.support.appendingPathComponent("stats.json") }
    /// Before play time was tracked, only last-played dates were kept here.
    private static var legacyRecentsURL: URL { AppPaths.support.appendingPathComponent("recents.json") }

    private static func loadStats() -> [String: PlayStats] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: statsURL) {
            return (try? decoder.decode([String: PlayStats].self, from: data)) ?? [:]
        }
        guard let data = try? Data(contentsOf: legacyRecentsURL),
              let recents = try? decoder.decode([String: Date].self, from: data) else { return [:] }
        let migrated = recents.mapValues { PlayStats(lastPlayed: $0) }
        saveStats(migrated)
        try? FileManager.default.removeItem(at: legacyRecentsURL)
        return migrated
    }

    private static func saveStats(_ stats: [String: PlayStats]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(stats) else { return }
        try? FileManager.default.createDirectory(at: AppPaths.support, withIntermediateDirectories: true)
        try? data.write(to: statsURL, options: .atomic)
    }
}

enum AppPaths {
    /// ~/Library/Application Support/Casting a Dream
    static let support: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Casting a Dream", isDirectory: true)
}
