import Foundation

/// Dolphin keeps Wii saves unencrypted in its emulated NAND, as files in
/// Wii/title/00010000/<game ID's first four characters in hex>/data/.
enum DolphinWiiSaves {
    /// The most recently written file in the game's save folder that `matches` accepts.
    static func file(gameID: String, matching matches: (URL) -> Bool = { _ in true }) -> URL? {
        let fm = FileManager.default
        let titleID = gameID.prefix(4).utf8.map { String(format: "%02x", $0) }.joined()
        let homes = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Dolphin"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/dolphin-emu"),
        ]
        return homes
            .map { $0.appendingPathComponent("Wii/title/00010000/\(titleID)/data") }
            .flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] }
            .filter(matches)
            .max { modified($0) < modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

extension Data {
    /// Big-endian u32 at `offset` (relative to the start of the data).
    func bigEndianU32(at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 << 8 | UInt32(self[startIndex + offset + $1]) }
    }
}
