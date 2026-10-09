import Foundation

struct Game: Identifiable, Hashable {
    let system: GameSystem
    /// The file handed to the emulator (.cue, .gdi, .iso, ...).
    let url: URL
    /// The game's own folder, or nil for a file loose in the system folder.
    let folder: URL?
    /// Folder name, or file name without extension for loose files, e.g. "Frame Gride (English)".
    let name: String

    var id: String { url.path }

    /// Name without "(...)" and "[...]" groups: "Frame Gride".
    var title: String {
        let stripped = name.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*[\)\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty ? name : stripped
    }

    /// Contents of the "(...)" groups: ["English"], ["USA"], ["Japan", "Disc 1"].
    var tags: [String] {
        let regex = try! NSRegularExpression(pattern: #"\(([^\)]*)\)"#)
        let range = NSRange(name.startIndex..., in: name)
        return regex.matches(in: name, range: range).compactMap { match in
            Range(match.range(at: 1), in: name).map { String(name[$0]) }
        }
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
