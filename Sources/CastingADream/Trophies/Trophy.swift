import Foundation

struct Trophy: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    /// SF Symbol name.
    let symbol: String
    /// Secret trophies show only "Secret trophy" until they're earned.
    var secret = false
}

/// Trophies for one game, worked out from the save file the emulator writes when the game closes.
protocol TrophySet {
    /// Stable key for storing unlocks; survives renaming the game's folder.
    var id: String { get }
    var system: GameSystem { get }
    /// SHA-1 of the exact game files the save layout was worked out on.
    var romSHA1: Set<String> { get }
    var trophies: [Trophy] { get }
    /// Where the emulator keeps this game's save.
    func saveURL(for game: Game) -> URL?
    /// IDs of the trophies the save data earns.
    func earned(from save: Data) -> Set<String>
}

enum TrophySets {
    static let all: [any TrophySet] = [DestinyOfAnEmperorIITrophies()]
    static let systems = Set(all.map(\.system))
}

/// Mesen keeps battery saves as <ROM file name>.sav in its home folder's Saves directory.
enum MesenSaves {
    static func saveFile(for game: Game) -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let homes = [
            home.appendingPathComponent("Library/Application Support/Mesen2"),
            home.appendingPathComponent("Documents/Mesen2"),
        ]
        let name = game.url.deletingPathExtension().lastPathComponent + ".sav"
        return homes
            .map { $0.appendingPathComponent("Saves").appendingPathComponent(name) }
            .filter { fm.fileExists(atPath: $0.path) }
            .max { modified($0) < modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
