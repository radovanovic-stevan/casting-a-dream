import Foundation
import CryptoKit

struct TrophyUnlock: Identifiable, Equatable {
    let id = UUID()
    let game: Game
    let trophy: Trophy
}

/// Which games have trophies, which trophies are unlocked (and when), and new unlocks to announce.
@MainActor
final class TrophyStore: ObservableObject {
    /// Trophy set id -> trophy id -> when it was unlocked.
    @Published private(set) var unlocked: [String: [String: Date]] = [:]
    /// Newly unlocked trophies, shown as a pop-up until dismissed.
    @Published var announcements: [TrophyUnlock] = []

    private var setsByGame: [Game.ID: any TrophySet] = [:]
    /// SHA-1 per game file, keyed by path + modification date so unchanged files aren't hashed again.
    private var hashCache: [String: String] = [:]

    init() {
        unlocked = Self.load()
    }

    func trophySet(for game: Game) -> (any TrophySet)? {
        setsByGame[game.id]
    }

    func progress(for game: Game) -> (earned: Int, total: Int)? {
        guard let set = setsByGame[game.id] else { return nil }
        let earned = set.trophies.filter { unlocked[set.id]?[$0.id] != nil }.count
        return (earned, set.trophies.count)
    }

    func unlockDate(_ trophy: Trophy, in set: any TrophySet) -> Date? {
        unlocked[set.id]?[trophy.id]
    }

    /// Matches games to trophy sets by file hash, then checks their saves.
    func refresh(_ games: [Game]) async {
        let candidates = games.filter { TrophySets.systems.contains($0.system) }
        let cache = hashCache
        let hashed = await Task.detached(priority: .utility) {
            candidates.map { game -> (Game, String, String?) in
                let key = Self.cacheKey(for: game.url)
                return (game, key, cache[key] ?? Self.sha1(of: game.url))
            }
        }.value

        var matched: [Game.ID: any TrophySet] = [:]
        for (game, key, hash) in hashed {
            guard let hash else { continue }
            hashCache[key] = hash
            if let set = TrophySets.all.first(where: { $0.system == game.system && $0.romSHA1.contains(hash) }) {
                matched[game.id] = set
            }
        }
        setsByGame = matched
        evaluate(games.filter { matched[$0.id] != nil })
    }

    /// Reads the saves of these games and unlocks anything newly earned.
    func evaluate(_ games: [Game]) {
        var newUnlocks: [TrophyUnlock] = []
        for game in games {
            guard let set = setsByGame[game.id],
                  let url = set.saveURL(for: game),
                  let save = try? Data(contentsOf: url) else { continue }
            let earned = set.earned(from: save)
            for trophy in set.trophies where earned.contains(trophy.id) && unlocked[set.id]?[trophy.id] == nil {
                unlocked[set.id, default: [:]][trophy.id] = Date()
                newUnlocks.append(TrophyUnlock(game: game, trophy: trophy))
            }
        }
        guard !newUnlocks.isEmpty else { return }
        Self.save(unlocked)
        announcements += newUnlocks
    }

    // MARK: - Hashing

    nonisolated private static func cacheKey(for url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        return "\(url.path)|\(date.timeIntervalSince1970)"
    }

    nonisolated private static func sha1(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Storage

    private static var url: URL { AppPaths.support.appendingPathComponent("trophies.json") }

    private static func load() -> [String: [String: Date]] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: [String: Date]].self, from: data)) ?? [:]
    }

    private static func save(_ unlocked: [String: [String: Date]]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(unlocked) else { return }
        try? FileManager.default.createDirectory(at: AppPaths.support, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
