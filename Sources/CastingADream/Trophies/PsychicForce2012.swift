import Foundation

/// Psychic Force 2012 (Europe, Dreamcast, T-8106D-50).
///
/// Save layout, worked out by disassembling 1ST_READ.BIN (loaded at $8C010000) around the
/// "PSYCHIC_2012" save code:
/// - The game saves one file, PSYCHIC_2012, on the VMU: a 0x80-byte VMS header, 3 icons (0x600) and a
///   16-colour eyecatch (0x800), then 0x2E8 bytes of game data at 0xE80. The last byte (0x2E7) is the
///   low byte of the sum of the bytes before it. Loading copies the game data to $8C3DF25C.
/// - Characters are numbered as in the game's name tables: Burn, Keith, Might, Genshin, Gudeath, Wendy,
///   Emilio, Wong, Gates, Setsuna, Patty, Carlo, Regina (0–12).
/// - 0x04: u32 frames spent in battle (the fight loop adds one per frame outside demos).
/// - 0x28, 0x2A: u16 masks, bit = character, set by the ending routine when a 1P game is beaten
///   (which one depends on the mode; with 1 round per match most clears aren't recorded).
/// - 0x2E: u16 per character, how many times they've been picked (used for the VMU icon).
/// - 0x50–0x54: unlocks, set by the routine at $8C0E36AC after an ending:
///   0x50 Wong (0x28 holds all ten starting characters, or 6 hours), 0x51 Keith (0x2A holds them, or
///   12 hours), 0x52 Burn (both masks hold all but Burn, or 14 hours), 0x53 / 0x54 Emilio's second and
///   third forms (Emilio picked 50 / 30 times, or 18 / 16 hours). The character select screen hides
///   Emilio's forms 2 and 3 until 0x53 / 0x54 are set.
struct PsychicForce2012Trophies: TrophySet {
    let id = "psychic-force-2012"
    let system = GameSystem.dreamcast
    /// Redump .cue of Psychic Force 2012 (Europe).
    let romSHA1: Set<String> = ["32e751e1abe148a16a5d45587a8ff8076d7e923a"]

    private static let productNumber = "T-8106D-50"
    private static let fileName = "PSYCHIC_2012"
    private static let gameData = 0xE80
    private static let gameDataSize = 0x2E8

    private enum Character {
        static let burn = 0, keith = 1, wong = 7
        static let count = 13
        /// Everyone but Burn, Keith and Wong.
        static let starting = [2, 3, 4, 5, 6, 8, 9, 10, 11, 12]
    }

    private enum Offset {
        static let battleFrames = 0x04
        static let clears = [0x28, 0x2A]
        static let picks = 0x2E
        static let wong = 0x50, keith = 0x51, burn = 0x52
        static let emilioSecondForm = 0x53, emilioThirdForm = 0x54
    }

    private static let hour = 60 * 60 * 60

    let trophies = [
        Trophy(id: "first-ending", title: "Psychic Awakening",
               detail: "Beat the game with any character.", symbol: "flag.checkered"),
        Trophy(id: "full-roster", title: "Full Roster",
               detail: "Fight as each of the ten starting characters.", symbol: "person.3.fill"),
        Trophy(id: "warming-up", title: "Warming Up",
               detail: "Spend 1 hour in battle.", symbol: "clock"),
        Trophy(id: "five-endings", title: "Five Stories",
               detail: "Beat the game with 5 different characters.", symbol: "book.fill"),
        Trophy(id: "wong", title: "Wong Steps In",
               detail: "Unlock Wong.", symbol: "person.badge.plus"),
        Trophy(id: "keith", title: "Leader of Noah",
               detail: "Unlock Keith.", symbol: "crown.fill"),
        Trophy(id: "emilio-transformed", title: "Emilio Transformed",
               detail: "Unlock one of Emilio's other forms.", symbol: "sparkles"),
        Trophy(id: "emilio-complete", title: "Every Side of Emilio",
               detail: "Unlock both of Emilio's other forms.", symbol: "wand.and.stars"),
        Trophy(id: "signature-style", title: "Signature Style",
               detail: "Pick the same character 100 times.", symbol: "hand.raised.fill"),
        Trophy(id: "wong-ending", title: "Amplified",
               detail: "Beat the game as Wong.", symbol: "bolt.fill"),
        Trophy(id: "keith-ending", title: "Psychiccer Utopia",
               detail: "Beat the game as Keith.", symbol: "snowflake"),
        Trophy(id: "seasoned", title: "Seasoned Psychiccer",
               detail: "Spend 10 hours in battle.", symbol: "clock.fill"),
        Trophy(id: "burn-ending", title: "Wanderer in Time",
               detail: "Beat the game as Burn.", symbol: "flame",
               secret: true),
        Trophy(id: "every-story", title: "Every Psychiccer's Story",
               detail: "Beat the game with all 13 characters.", symbol: "star.circle.fill"),
        Trophy(id: "marathon", title: "Twenty Hours of Psychic Force",
               detail: "Spend 20 hours in battle.", symbol: "hourglass"),
        Trophy(id: "burn", title: "The Hero Returns",
               detail: "Unlock Burn, the hero of the first Psychic Force.", symbol: "flame.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        FlycastSaves.vmu(productNumber: Self.productNumber)
    }

    func earned(from save: Data) -> Set<String> {
        guard let file = DreamcastVMU.file(named: Self.fileName, in: save),
              file.count >= Self.gameData + Self.gameDataSize else { return [] }
        let bytes = [UInt8](file[(file.startIndex + Self.gameData)..<(file.startIndex + Self.gameData + Self.gameDataSize)])
        let sum = bytes.dropLast().reduce(0) { ($0 + Int($1)) & 0xFF }
        guard sum == Int(bytes[bytes.count - 1]) else { return [] }

        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }
        let cleared = Offset.clears.reduce(0) { $0 | u16($1) }
        func beaten(_ character: Int) -> Bool { cleared & (1 << character) != 0 }
        let picks = (0..<Character.count).map { u16(Offset.picks + $0 * 2) }
        let hours = u32(Offset.battleFrames) / Self.hour
        let endings = (0..<Character.count).filter(beaten).count

        var earned = Set<String>()
        if endings >= 1 { earned.insert("first-ending") }
        if endings >= 5 { earned.insert("five-endings") }
        if endings == Character.count { earned.insert("every-story") }
        if beaten(Character.wong) { earned.insert("wong-ending") }
        if beaten(Character.keith) { earned.insert("keith-ending") }
        if beaten(Character.burn) { earned.insert("burn-ending") }
        if Character.starting.allSatisfy({ picks[$0] > 0 }) { earned.insert("full-roster") }
        if picks.contains(where: { $0 >= 100 }) { earned.insert("signature-style") }
        if hours >= 1 { earned.insert("warming-up") }
        if hours >= 10 { earned.insert("seasoned") }
        if hours >= 20 { earned.insert("marathon") }
        if bytes[Offset.wong] != 0 { earned.insert("wong") }
        if bytes[Offset.keith] != 0 { earned.insert("keith") }
        if bytes[Offset.burn] != 0 { earned.insert("burn") }
        let emilioForms = [Offset.emilioSecondForm, Offset.emilioThirdForm].filter { bytes[$0] != 0 }.count
        if emilioForms >= 1 { earned.insert("emilio-transformed") }
        if emilioForms == 2 { earned.insert("emilio-complete") }
        return earned
    }
}
