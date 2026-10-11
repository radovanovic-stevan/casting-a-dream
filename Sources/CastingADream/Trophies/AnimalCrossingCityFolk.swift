import Foundation

/// Animal Crossing: City Folk (USA, Wii, RUUE01).
///
/// The town is one 0x40F340-byte file (RVFOREST.DAT) in Dolphin's data folder, big endian. Offsets are from
/// two independent save editors that agree on them, ACToolkit (game_profiles.py, save_handler.py) and
/// ACSE (PlayerInfo.cs, Museum.cs); no unmodified City Folk save was available online to check them against:
/// - Four players, 0x86C0 bytes each from 0: Bells on hand at +0x1154, savings at +0x115C (u32),
///   name at +0x7EFA (UTF-16, empty when unused).
/// - Museum from 0x7352A, one nibble per exhibit holding the donating player (1–4) or 0:
///   30 bytes of fossils, 32 of fish, 32 of insects, 14 of paintings. City Folk has 64 fish and 64 insects,
///   so those can be completed; the fossil and painting areas have spare slots, so only counts are used.
struct AnimalCrossingCityFolkTrophies: TrophySet {
    let id = "animal-crossing-city-folk"
    let system = GameSystem.wii
    let romSHA1: Set<String> = ["2fba8c6564d9c90da968babb6deeafb676b2f379"]

    private static let gameID = "RUUE"
    private static let saveSize = 0x40F340

    private enum Player {
        static let count = 4, size = 0x86C0
        static let wallet = 0x1154, savings = 0x115C, name = 0x7EFA
    }

    private enum Museum {
        static let base = 0x7352A
        static let fossils = (offset: 0, bytes: 30)
        static let fish = (offset: 30, bytes: 32)
        static let insects = (offset: 62, bytes: 32)
        static let paintings = (offset: 94, bytes: 14)
        static let completeFish = 64, completeInsects = 64
    }

    let trophies = [
        Trophy(id: "first-donation", title: "Blathers Is Delighted",
               detail: "Donate something to the museum.", symbol: "building.columns"),
        Trophy(id: "fish-10", title: "Gone Fishing",
               detail: "Donate 10 fish.", symbol: "fish"),
        Trophy(id: "insects-10", title: "Bug Off",
               detail: "Donate 10 insects.", symbol: "ladybug"),
        Trophy(id: "fossils-10", title: "Dig It",
               detail: "Donate 10 fossils.", symbol: "fossil.shell"),
        Trophy(id: "paintings-5", title: "Art Lover",
               detail: "Donate 5 paintings.", symbol: "photo.artframe"),
        Trophy(id: "nest-egg", title: "Nest Egg",
               detail: "Have 100,000 Bells between your pockets and the bank.", symbol: "dollarsign.circle"),
        Trophy(id: "curator", title: "Curator's Pride",
               detail: "Donate 100 exhibits.", symbol: "building.columns.fill"),
        Trophy(id: "fossils-25", title: "Paleontologist",
               detail: "Donate 25 fossils.", symbol: "fossil.shell.fill"),
        Trophy(id: "millionaire", title: "Millionaire",
               detail: "Have 1,000,000 Bells between your pockets and the bank.", symbol: "banknote.fill"),
        Trophy(id: "all-fish", title: "Full Aquarium",
               detail: "Donate all 64 fish.", symbol: "drop.fill"),
        Trophy(id: "all-insects", title: "Full Insect Exhibit",
               detail: "Donate all 64 insects.", symbol: "leaf.fill"),
        Trophy(id: "museum-150", title: "Museum Benefactor",
               detail: "Donate 150 exhibits.", symbol: "star.circle.fill"),
        Trophy(id: "tycoon", title: "Bell Tycoon",
               detail: "Have 10,000,000 Bells between your pockets and the bank.", symbol: "crown.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        DolphinWiiSaves.file(gameID: Self.gameID) { url in
            ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) == Self.saveSize
        }
    }

    func earned(from save: Data) -> Set<String> {
        guard save.count == Self.saveSize else { return [] }
        let bytes = [UInt8](save)

        func donated(_ area: (offset: Int, bytes: Int)) -> Int? {
            let nibbles = bytes[(Museum.base + area.offset)..<(Museum.base + area.offset + area.bytes)]
                .flatMap { [$0 >> 4, $0 & 0xF] }
            // A donor is player 1–4; anything else means this isn't a City Folk town.
            guard nibbles.allSatisfy({ $0 <= 4 }) else { return nil }
            return nibbles.filter { $0 != 0 }.count
        }
        guard let fossils = donated(Museum.fossils), let fish = donated(Museum.fish),
              let insects = donated(Museum.insects), let paintings = donated(Museum.paintings) else { return [] }
        let exhibits = fossils + fish + insects + paintings

        let richest = (0..<Player.count)
            .map { $0 * Player.size }
            .filter { bytes[$0 + Player.name] != 0 || bytes[$0 + Player.name + 1] != 0 }
            .map { Int(save.bigEndianU32(at: $0 + Player.wallet)) + Int(save.bigEndianU32(at: $0 + Player.savings)) }
            .max() ?? 0

        var earned = Set<String>()
        if exhibits >= 1 { earned.insert("first-donation") }
        if exhibits >= 100 { earned.insert("curator") }
        if exhibits >= 150 { earned.insert("museum-150") }
        if fish >= 10 { earned.insert("fish-10") }
        if fish >= Museum.completeFish { earned.insert("all-fish") }
        if insects >= 10 { earned.insert("insects-10") }
        if insects >= Museum.completeInsects { earned.insert("all-insects") }
        if fossils >= 10 { earned.insert("fossils-10") }
        if fossils >= 25 { earned.insert("fossils-25") }
        if paintings >= 5 { earned.insert("paintings-5") }
        if richest >= 100_000 { earned.insert("nest-egg") }
        if richest >= 1_000_000 { earned.insert("millionaire") }
        if richest >= 10_000_000 { earned.insert("tycoon") }
        return earned
    }
}
