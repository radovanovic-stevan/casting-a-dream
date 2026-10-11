import Foundation

/// Frame Gride (English translation of the Japanese release, Dreamcast, T34201M).
///
/// Save layout, worked out by disassembling 1ST_READ.BIN (loaded at $8C010000):
/// - Each knight is its own file on the VMU, F_GRIDE.0 plus a three-digit number (the first free one):
///   F_GRIDE.0000, F_GRIDE.0001, ... It's a 0x80-byte VMS header and one icon (0x200), then 0x15C bytes
///   of knight data at 0x280. The VMS header's data size (0x48) is 0x15C.
/// - The game keeps two knights in memory, 0x3D8 bytes each from $8C3C8694, and every field goes through
///   accessors at $8C08E500–$8C08FA40. The save copies them (routine at $8C0A0564):
///   - 0x2B: 60 bytes, how many of each frame part are owned: Normal, Heavy and Light frames ×
///     head, core, arms, legs × 5 (the 15 heads, cores, arms and legs in PARAM.TXT).
///   - 0xA7: 32 bytes, how many of each squire are owned (capped at 99).
///   - 0xC7: 13 bytes, how many of each material are held (capped at 99; making parts and squires
///     uses them up).
///   - 0x10C: battle record, four rows of u32 wins / losses / battles (capped at 9999): one row per
///     mode, then the totals at 0x130 / 0x134 / 0x138. 0x130 is the win count in the VMU file name.
///   - 0x140: rank. After a won battle the routine at $8C08F2F4 raises it by one, to at most 10, when the
///     opponent was the one the current rank calls for.
struct FrameGrideTrophies: TrophySet {
    let id = "frame-gride"
    let system = GameSystem.dreamcast
    /// English translation, final version (DiscJuggler image).
    let romSHA1: Set<String> = ["6f52468fe2485dfcf9e48b37144e4c3fbccd3054"]

    private static let productNumber = "T34201M"
    private static let filePrefix = "F_GRIDE.0"
    private static let knightData = 0x280
    private static let knightDataSize = 0x15C

    private enum Offset {
        static let parts = 0x2B, partCount = 60
        static let squires = 0xA7, squireCount = 32
        static let materials = 0xC7, materialCount = 13
        static let wins = 0x130
        static let battles = 0x138
        static let rank = 0x140
    }

    let trophies = [
        Trophy(id: "first-victory", title: "First Victory",
               detail: "Win a battle.", symbol: "flag.checkered"),
        Trophy(id: "squire-bound", title: "Squire Bound",
               detail: "Own a squire.", symbol: "pawprint.fill"),
        Trophy(id: "rising-knight", title: "Rising Knight",
               detail: "Reach rank 3.", symbol: "chevron.up.circle"),
        Trophy(id: "proven", title: "Proven in the Arena",
               detail: "Win 10 battles.", symbol: "shield.lefthalf.filled"),
        Trophy(id: "spare-parts", title: "Spare Parts",
               detail: "Own 30 frame parts.", symbol: "wrench.and.screwdriver.fill"),
        Trophy(id: "retinue", title: "Retinue",
               detail: "Own 10 different squires.", symbol: "person.3.fill"),
        Trophy(id: "alchemist", title: "Alchemist's Shelf",
               detail: "Hold every kind of material at once.", symbol: "flask.fill"),
        Trophy(id: "seasoned", title: "Seasoned Knight",
               detail: "Reach rank 6.", symbol: "chevron.up.2"),
        Trophy(id: "veteran", title: "Veteran",
               detail: "Win 50 battles.", symbol: "shield.fill"),
        Trophy(id: "tireless", title: "Tireless",
               detail: "Fight 200 battles.", symbol: "figure.fencing"),
        Trophy(id: "full-armory", title: "Full Armory",
               detail: "Own all 60 frame parts.", symbol: "gearshape.2.fill"),
        Trophy(id: "master-of-squires", title: "Master of Squires",
               detail: "Own all 32 squires.", symbol: "crown.fill"),
        Trophy(id: "champion", title: "Champion",
               detail: "Win 100 battles.", symbol: "trophy.fill"),
        Trophy(id: "frame-gride", title: "Knight of the Highest Rank",
               detail: "Reach rank 10, the highest.", symbol: "star.circle.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        FlycastSaves.vmu(productNumber: Self.productNumber)
    }

    /// Every knight on the VMU counts; a trophy is earned when any of them qualifies.
    func earned(from save: Data) -> Set<String> {
        DreamcastVMU.files(in: save)
            .filter { $0.name.hasPrefix(Self.filePrefix) }
            .reduce(into: Set<String>()) { $0.formUnion(earned(fromKnight: $1.data)) }
    }

    private func earned(fromKnight file: Data) -> Set<String> {
        let bytes = [UInt8](file)
        func u32(_ bytes: [UInt8], _ offset: Int) -> Int {
            (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
        }
        guard bytes.count >= Self.knightData + Self.knightDataSize,
              u32(bytes, 0x48) == Self.knightDataSize else { return [] }
        let knight = Array(bytes[Self.knightData..<(Self.knightData + Self.knightDataSize)])
        func owned(_ offset: Int, _ count: Int) -> Int {
            knight[offset..<(offset + count)].filter { $0 > 0 }.count
        }
        let wins = u32(knight, Offset.wins)
        let battles = u32(knight, Offset.battles)
        let rank = Int(knight[Offset.rank])
        let parts = owned(Offset.parts, Offset.partCount)
        let squires = owned(Offset.squires, Offset.squireCount)
        let materials = owned(Offset.materials, Offset.materialCount)

        var earned = Set<String>()
        if wins >= 1 { earned.insert("first-victory") }
        if wins >= 10 { earned.insert("proven") }
        if wins >= 50 { earned.insert("veteran") }
        if wins >= 100 { earned.insert("champion") }
        if battles >= 200 { earned.insert("tireless") }
        if rank >= 3 { earned.insert("rising-knight") }
        if rank >= 6 { earned.insert("seasoned") }
        if rank >= 10 { earned.insert("frame-gride") }
        if parts >= 30 { earned.insert("spare-parts") }
        if parts == Offset.partCount { earned.insert("full-armory") }
        if squires >= 1 { earned.insert("squire-bound") }
        if squires >= 10 { earned.insert("retinue") }
        if squires == Offset.squireCount { earned.insert("master-of-squires") }
        if materials == Offset.materialCount { earned.insert("alchemist") }
        return earned
    }
}
