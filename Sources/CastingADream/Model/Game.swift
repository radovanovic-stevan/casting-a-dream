import Foundation

struct Game: Identifiable, Hashable {
    let system: GameSystem
    /// The file handed to the emulator (.cue, .gdi, .iso, ...).
    let url: URL
    /// The game's own folder, or nil for a file loose in the system folder.
    let folder: URL?
    /// Folder name, or file name without extension for loose files, e.g. "Frame Gride (English)".
    let name: String
    /// Search for this game on the collection site, from collection.txt in its folder; nil means the title.
    var collectionQuery: String? = nil
    /// One of my own ROM hacks, marked by a homebrew.txt in its folder. Listed in its own section
    /// and kept out of the collection site, which only has games I own.
    var isHomebrew = false

    var id: String { url.path }

    /// Name without "(...)" and "[...]" groups: "Frame Gride".
    var title: String {
        let stripped = name.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? name : stripped
    }

    /// Names to try on thumbnails.libretro.com, which uses Redump / No-Intro names such as
    /// "Frame Gride (Japan)" or "Sonic Rivals (USA)".
    var thumbnailCandidates: [String] {
        let regions = ["USA", "Europe", "Japan", "USA, Europe", "Japan, USA", "World"]
        var names = [name, url.deletingPathExtension().lastPathComponent]
        names += regions.map { "\(title) (\($0))" }
        names.append(title)
        var seen = Set<String>()
        return names
            .map(Self.libretroSafe)
            .filter { seen.insert($0).inserted }
    }

    /// libretro-thumbnails replaces these characters with "_" in file names.
    private static func libretroSafe(_ name: String) -> String {
        String(name.map { "&*/:`<>?\\|\"".contains($0) ? "_" : $0 })
    }
}
