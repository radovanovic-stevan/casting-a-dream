import AppKit
import CryptoKit

/// Cover art per game: a cover image in the game's folder if there is one, otherwise box art
/// downloaded once from thumbnails.libretro.com and cached in Application Support.
@MainActor
final class CoverArtStore: ObservableObject {
    @Published private(set) var images: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    func load(_ game: Game) {
        guard images[game.id] == nil, !inFlight.contains(game.id) else { return }
        inFlight.insert(game.id)
        Task {
            let data = await Self.resolve(game)
            inFlight.remove(game.id)
            if let data, let image = NSImage(data: data) {
                images[game.id] = image
            }
        }
    }

    // MARK: - Lookup

    nonisolated private static let localNames = ["cover", "boxart", "folder"]
    nonisolated private static let imageExtensions = ["png", "jpg", "jpeg", "webp"]
    /// After a failed download, don't ask the server again for this long.
    nonisolated private static let missRetryInterval: TimeInterval = 7 * 24 * 3600

    nonisolated private static func resolve(_ game: Game) async -> Data? {
        if let local = localCover(for: game), let data = try? Data(contentsOf: local) {
            return data
        }
        let cached = cacheURL(for: game)
        if let data = try? Data(contentsOf: cached) {
            return data
        }
        let miss = cached.appendingPathExtension("miss")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: miss.path),
           let date = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < missRetryInterval {
            return nil
        }

        try? FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
        for name in game.thumbnailCandidates {
            guard let url = thumbnailURL(system: game.system, name: name) else { continue }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  NSImage(data: data) != nil else { continue }
            try? data.write(to: cached, options: .atomic)
            try? FileManager.default.removeItem(at: miss)
            return data
        }
        FileManager.default.createFile(atPath: miss.path, contents: nil)
        return nil
    }

    /// cover.png / boxart.jpg / ... in the game's folder, or "<game file name>.png" next to the game file.
    nonisolated private static func localCover(for game: Game) -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let folder = game.folder {
            for name in localNames {
                candidates += imageExtensions.map { folder.appendingPathComponent(name).appendingPathExtension($0) }
            }
        }
        let stem = game.url.deletingPathExtension()
        candidates += imageExtensions.map { stem.appendingPathExtension($0) }
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    nonisolated private static func cacheURL(for game: Game) -> URL {
        let digest = SHA256.hash(data: Data(game.id.utf8)).map { String(format: "%02x", $0) }.joined()
        return AppPaths.support
            .appendingPathComponent("Covers", isDirectory: true)
            .appendingPathComponent(String(digest.prefix(32)))
            .appendingPathExtension("png")
    }

    nonisolated private static func thumbnailURL(system: GameSystem, name: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "thumbnails.libretro.com"
        components.path = "/\(system.thumbnailSystem)/Named_Boxarts/\(name).png"
        return components.url
    }
}
