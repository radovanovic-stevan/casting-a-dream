import Foundation

/// Sonic Rivals (Europe, PSP, ULES00622).
///
/// The save is GAMEDATA.BIN in PPSSPP's ULES00622RVSAVEDATA<n> folder, encrypted like a PSP save (mode 5,
/// or mode 3 from older firmware) with the key "RIVALSZ" padded with zeros. The EBOOT copies it into the
/// savedata parameters from offset 0x4D of its own save settings; it was found by trying every short string
/// in the EBOOT against the file hash in PARAM.SFO. Decrypted (same layout in US saves):
/// - 0x08, 0x0C: u32 2 and 1 in every save, used to check the decryption.
/// - 0x4ED8: 150 cards, 12 bytes each; a card is collected when its first byte isn't 0. The EBOOT counts
///   them this way for PARAM.SFO's "Card Collection: N/150" (code at 0x68D58, from $F5510 + 0x8218).
/// - 0x5BC4: u32 per character (Sonic, Shadow, Knuckles, Silver), one bit per story stage; the percentage in
///   PARAM.SFO is the 17 low bits set ÷ 17 (code at 0x103DFC).
/// File offset = memory − 0xF8850; both fields were checked against six GameFAQs saves (89–150 cards).
struct SonicRivalsTrophies: TrophySet {
    let id = "sonic-rivals"
    let system = GameSystem.psp
    let romSHA1: Set<String> = ["b46d1b2456129ed25ce66ca93d295c4f505e0283"]

    private static let saveFolder = "ULES00622RVSAVEDATA"
    private static let gameKey: [UInt8] = Array("RIVALSZ".utf8) + [UInt8](repeating: 0, count: 9)

    private enum Offset {
        static let cards = 0x4ED8, cardSize = 12, cardCount = 150
        static let stories = 0x5BC4
    }

    private enum Character {
        static let sonic = 0, shadow = 1, knuckles = 2, silver = 3
        static let all = [sonic, shadow, knuckles, silver]
    }

    private static let storyComplete: UInt32 = 0x1FFFF

    let trophies = [
        Trophy(id: "first-stage", title: "Rivalry Begins",
               detail: "Clear a story stage.", symbol: "flag.checkered"),
        Trophy(id: "first-cards", title: "Starter Deck",
               detail: "Collect 10 cards.", symbol: "rectangle.stack"),
        Trophy(id: "sonic-story", title: "Fastest Thing Alive",
               detail: "Finish every stage of Sonic's story.", symbol: "hare.fill"),
        Trophy(id: "shadow-story", title: "Ultimate Life Form",
               detail: "Finish every stage of Shadow's story.", symbol: "bolt.fill"),
        Trophy(id: "knuckles-story", title: "Guardian of the Emerald",
               detail: "Finish every stage of Knuckles' story.", symbol: "diamond.fill"),
        Trophy(id: "silver-story", title: "From the Future",
               detail: "Finish every stage of Silver's story.", symbol: "sparkles"),
        Trophy(id: "half-deck", title: "Half the Deck",
               detail: "Collect 75 cards.", symbol: "rectangle.stack.fill"),
        Trophy(id: "all-stories", title: "No More Rivals",
               detail: "Finish all four stories.", symbol: "person.3.fill"),
        Trophy(id: "card-sharp", title: "Card Sharp",
               detail: "Collect 120 cards.", symbol: "suit.spade.fill"),
        Trophy(id: "full-collection", title: "Complete Collection",
               detail: "Collect all 150 cards.", symbol: "crown.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        PPSSPPSaves.file(named: "GAMEDATA.BIN", gameID: Self.saveFolder)
    }

    func earned(from save: Data) -> Set<String> {
        // Encrypted as PPSSPP writes it (whichever mode), or plain when its "Encrypt save data" is off.
        let candidates = [save] + PSPSavedata.Mode.allCases.compactMap {
            PSPSavedata.decrypt(save, gameKey: Self.gameKey, mode: $0)
        }
        guard let profile = candidates.first(where: isProfile).map({ [UInt8]($0) }) else { return [] }

        let cards = (0..<Offset.cardCount).filter { profile[Offset.cards + $0 * Offset.cardSize] != 0 }.count
        let finished = Character.all.filter { u32(profile, Offset.stories + $0 * 4) & Self.storyComplete == Self.storyComplete }
        let anyStage = Character.all.contains { u32(profile, Offset.stories + $0 * 4) & Self.storyComplete != 0 }

        var earned = Set<String>()
        if anyStage { earned.insert("first-stage") }
        if cards >= 10 { earned.insert("first-cards") }
        if cards >= 75 { earned.insert("half-deck") }
        if cards >= 120 { earned.insert("card-sharp") }
        if cards == Offset.cardCount { earned.insert("full-collection") }
        if finished.contains(Character.sonic) { earned.insert("sonic-story") }
        if finished.contains(Character.shadow) { earned.insert("shadow-story") }
        if finished.contains(Character.knuckles) { earned.insert("knuckles-story") }
        if finished.contains(Character.silver) { earned.insert("silver-story") }
        if finished.count == Character.all.count { earned.insert("all-stories") }
        return earned
    }

    /// The two constant words, and story words that only use their 17 stage bits.
    private func isProfile(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        guard bytes.count >= Offset.stories + 16 else { return false }
        return u32(bytes, 0x08) == 2 && u32(bytes, 0x0C) == 1
            && Character.all.allSatisfy { u32(bytes, Offset.stories + $0 * 4) & ~Self.storyComplete == 0 }
    }

    private func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(bytes[offset + $1]) << (8 * $1) }
    }
}
