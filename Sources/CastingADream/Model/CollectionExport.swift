import AppKit

/// Writes casting-a-dream.json for the collection site: every game in the library with its play time and
/// trophies, so the site can list them and show the launcher's play time on the matching collection games.
/// Homebrew games are left out: the file is published, and they aren't part of the collection.
///
/// It's written to the folder chosen with Library → Collection Export Folder… (the site's public/data),
/// whenever the library, play time or trophies change, and only when the content is different, so the
/// site's repository only changes when there's something new to commit.
@MainActor
enum CollectionExport {
    static let fileName = "casting-a-dream.json"
    private static let folderKey = "collectionExportFolder"

    static var folder: URL? {
        get { UserDefaults.standard.string(forKey: folderKey).map { URL(fileURLWithPath: $0, isDirectory: true) } }
        set { UserDefaults.standard.set(newValue?.path, forKey: folderKey) }
    }

    static func chooseFolder() -> Bool {
        let panel = NSOpenPanel()
        panel.message = "Choose the collection site's public/data folder. Casting a Dream keeps \(fileName) there up to date."
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        folder = url
        return true
    }

    static func write(games: [Game], stats: [String: PlayStats], trophies: TrophyStore) {
        guard let folder else { return }
        let export = Export(
            repository: "https://github.com/radovanovic-stevan/casting-a-dream",
            systems: GameSystem.allCases.map {
                .init(name: $0.displayName, platform: $0.collectionPlatform, emulator: $0.emulatorName)
            },
            games: games
                .filter { !$0.isHomebrew }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                .map { entry(for: $0, stats: stats[$0.id], trophies: trophies) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard var data = try? encoder.encode(export) else { return }
        data.append(0x0A)
        let url = folder.appendingPathComponent(fileName)
        if (try? Data(contentsOf: url)) == data { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func entry(for game: Game, stats: PlayStats?, trophies: TrophyStore) -> Export.Game {
        var list: [Export.Trophy]?
        if let set = trophies.trophySet(for: game) {
            list = set.trophies.map { trophy in
                let unlocked = trophies.unlockDate(trophy, in: set)
                // A secret trophy stays a secret on the site too until it's earned.
                if trophy.secret && unlocked == nil { return .init(title: nil, detail: nil, secret: true, unlocked: nil) }
                return .init(title: trophy.title, detail: trophy.detail, secret: trophy.secret ? true : nil,
                             unlocked: unlocked.map(day))
            }
        }
        return .init(
            title: game.title,
            platform: game.system.collectionPlatform,
            search: game.collectionQuery ?? game.title,
            // Whole minutes, as the launcher shows them.
            minutes: stats.flatMap { $0.seconds > 0 ? Int($0.seconds / 60) : nil },
            lastPlayed: stats.map { day($0.lastPlayed) },
            trophies: list
        )
    }

    /// yyyy-mm-dd in the Mac's time zone.
    private static func day(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private struct Export: Encodable {
        struct System: Encodable { let name, platform, emulator: String }
        struct Trophy: Encodable {
            let title, detail: String?
            let secret: Bool?
            let unlocked: String?
        }
        struct Game: Encodable {
            let title, platform: String
            /// The collection search that finds this game, as used by the launcher's collection link.
            let search: String
            /// Play time tracked by the launcher; nil when none has been.
            let minutes: Int?
            let lastPlayed: String?
            let trophies: [Trophy]?
        }
        let repository: String
        let systems: [System]
        let games: [Game]
    }
}
