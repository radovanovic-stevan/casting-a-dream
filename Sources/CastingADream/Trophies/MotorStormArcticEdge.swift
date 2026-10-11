import Foundation

/// MotorStorm: Arctic Edge (Europe, PSP, UCES01250).
///
/// The game profile is DATA.BIN in PPSSPP's UCES01250* save folder. PPSSPP encrypts it the way a PSP does
/// (mode 5) with the game's own key, which sits at 0x2755D8 in the decrypted EBOOT.BIN; it was found by
/// trying every 16 bytes of the EBOOT against the file hash in PARAM.SFO. Decrypted, the profile is:
/// - 0x00: u32 0x21100018, the save format's magic (the EBOOT returns it from a function at 0xB3EFC).
/// - 0x04: profile name.
/// - 0x18: u32 Festival points (100 for gold, 75 for silver, 50 for bronze; PARAM.SFO shows it as "N POINTS").
/// - 0x220: u32 per Festival race (128 slots, races 1–90 used): 1 gold, 2 silver, 3 bronze,
///   0xFFFFFFFF not raced yet.
/// - 0x420: u32 per race, best time in milliseconds.
/// Worked out by decrypting a profile after the first race (a gold, 100 points), using the race list in
/// FE.PAK (Championship_Race01–90) and the point values for each medal.
struct MotorStormArcticEdgeTrophies: TrophySet {
    let id = "motorstorm-arctic-edge"
    let system = GameSystem.psp
    let romSHA1: Set<String> = ["628261971367a334c95456d0c2a3cf665e459dfa"]

    private static let gameID = "UCES01250"
    private static let gameKey: [UInt8] = [0x6E, 0x0B, 0x70, 0x0D, 0x72, 0x0F, 0x74, 0x01,
                                           0x66, 0x03, 0x68, 0x05, 0x6A, 0x07, 0x6C, 0x09]
    private static let magic: UInt32 = 0x2110_0018
    private static let races = 90

    private enum Offset {
        static let points = 0x18
        static let results = 0x220
    }

    private enum Medal {
        static let gold: UInt32 = 1, silver: UInt32 = 2, bronze: UInt32 = 3
    }

    let trophies = [
        Trophy(id: "on-the-podium", title: "On the Podium",
               detail: "Earn a medal in a Festival race.", symbol: "medal"),
        Trophy(id: "first-gold", title: "First Gold",
               detail: "Win a Festival race.", symbol: "flag.checkered"),
        Trophy(id: "contender", title: "Contender",
               detail: "Score 1,000 Festival points.", symbol: "chart.line.uptrend.xyaxis"),
        Trophy(id: "hot-streak", title: "Hot Streak",
               detail: "Win 10 Festival races.", symbol: "flame.fill"),
        Trophy(id: "halfway", title: "Halfway Up the Mountain",
               detail: "Earn a medal in 45 Festival races.", symbol: "mountain.2.fill"),
        Trophy(id: "festival-favourite", title: "Festival Favourite",
               detail: "Score 4,000 Festival points.", symbol: "star.fill"),
        Trophy(id: "gold-rush", title: "Gold Rush",
               detail: "Win 30 Festival races.", symbol: "dollarsign.circle.fill"),
        Trophy(id: "every-ticket", title: "Every Ticket Stamped",
               detail: "Earn a medal in all 90 Festival races.", symbol: "ticket.fill"),
        Trophy(id: "arctic-veteran", title: "Arctic Veteran",
               detail: "Score 7,000 Festival points.", symbol: "snowflake"),
        Trophy(id: "silver-lining", title: "Silver Lining",
               detail: "Earn silver or better in all 90 Festival races.", symbol: "rosette"),
        Trophy(id: "arctic-edge", title: "King of the Arctic Edge",
               detail: "Win all 90 Festival races.", symbol: "crown.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        PPSSPPSaves.file(named: "DATA.BIN", gameID: Self.gameID)
    }

    func earned(from save: Data) -> Set<String> {
        // Encrypted as PPSSPP writes it by default, or plain when its "Encrypt save data" is off.
        guard let profile = [save, PSPSavedata.decrypt(save, gameKey: Self.gameKey)]
            .compactMap({ $0 })
            .first(where: { $0.count >= Offset.results + Self.races * 4 && u32($0, 0) == Self.magic })
        else { return [] }

        let points = Int(u32(profile, Offset.points))
        let results = (0..<Self.races).map { u32(profile, Offset.results + $0 * 4) }
        let golds = results.filter { $0 == Medal.gold }.count
        let silverOrBetter = results.filter { $0 == Medal.gold || $0 == Medal.silver }.count
        let medals = results.filter { (Medal.gold...Medal.bronze).contains($0) }.count

        var earned = Set<String>()
        if medals >= 1 { earned.insert("on-the-podium") }
        if medals >= 45 { earned.insert("halfway") }
        if medals == Self.races { earned.insert("every-ticket") }
        if silverOrBetter == Self.races { earned.insert("silver-lining") }
        if golds >= 1 { earned.insert("first-gold") }
        if golds >= 10 { earned.insert("hot-streak") }
        if golds >= 30 { earned.insert("gold-rush") }
        if golds == Self.races { earned.insert("arctic-edge") }
        if points >= 1_000 { earned.insert("contender") }
        if points >= 4_000 { earned.insert("festival-favourite") }
        if points >= 7_000 { earned.insert("arctic-veteran") }
        return earned
    }

    private func u32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
    }
}
