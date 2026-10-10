import Foundation

/// Destiny of an Emperor II (English translation of Tenchi o Kurau II, Famicom).
///
/// Save layout, worked out by playing the game headless in Mesen and comparing battery RAM:
/// - Battery RAM is 8 KB at $6000; the game keeps its live state at $6000–$64FF.
/// - $6200 + general id holds one status byte per general; bit 0x40 is set when he joins your army
///   (seen for Zhu Ling, Lu Zhao, Guan Yu and Zhang Fei as they joined). Liu Bei, the leader, only gets
///   it after a defeat sends the party back, so he's left out of recruit counts.
/// - $6028–$602A: experience (3 bytes, little endian); only victories add to it.
/// - $602B: party level (the level-up routine increments it and then shows its message).
/// - $602C–$602E: gold (3 bytes, little endian; the game caps it at 9,999,999).
/// - General ids come from the ROM's general table: pointer low bytes at ROM $6DE00, high bytes at
///   $6DF00, each entry 22 stat bytes + name + $FF. Its ids match the status bytes that changed in play.
///
/// The .sav holds the live state when the game was closed, so progress counts even if it wasn't
/// recorded at Headquarters before quitting.
struct DestinyOfAnEmperorIITrophies: TrophySet {
    let id = "destiny-of-an-emperor-ii"
    let system = GameSystem.famicom
    /// English translation v1.12 by Dark Force, Dynamic Designs, Jair and Taskforce.
    let romSHA1: Set<String> = ["d02cc267e0b350b2dc84f087fbc04a778f976973"]

    private enum General {
        static let liuBei = 0x01
        static let guanYu = [0x02]
        static let zhangFei = [0x03]
        static let zhugeLiang = [0x08]
        static let zhaoYun = [0x0B]
        static let pangTong = [0x0F]
        static let jiangWei = [0x12]
        static let maChao = [0x7B]
        /// The table has two Huang Zhong entries; either one joining counts.
        static let huangZhong = [0x46, 0x6A]
        /// Zhang Lu has an entry for each battle he appears in.
        static let zhangLu = Array(0x6E...0x77)
    }

    private static let statusBase = 0x200   // $6200 within battery RAM
    private static let joinedBit: UInt8 = 0x40
    private static let experience = 0x028   // $6028
    private static let level = 0x02B        // $602B
    private static let gold = 0x02C         // $602C

    let trophies = [
        Trophy(id: "first-victory", title: "First Victory",
               detail: "Win a battle.", symbol: "flag.checkered"),
        Trophy(id: "first-recruits", title: "First Recruits",
               detail: "Have a general join Liu Bei's army.", symbol: "person.badge.plus"),
        Trophy(id: "peach-garden", title: "Oath of the Peach Garden",
               detail: "Reunite with both sworn brothers, Guan Yu and Zhang Fei.", symbol: "person.3.fill"),
        Trophy(id: "growing-army", title: "Growing Army",
               detail: "Recruit 10 generals.", symbol: "flag.fill"),
        Trophy(id: "full-coffers", title: "Full Coffers",
               detail: "Hold 1,000 gold at once.", symbol: "dollarsign.circle"),
        Trophy(id: "seasoned", title: "Seasoned Commander",
               detail: "Reach level 10.", symbol: "chevron.up.circle"),
        Trophy(id: "sleeping-dragon", title: "The Sleeping Dragon",
               detail: "Win over Zhuge Liang.", symbol: "moon.stars.fill"),
        Trophy(id: "phoenix", title: "Phoenix Fledgling",
               detail: "Recruit Pang Tong.", symbol: "bird.fill"),
        Trophy(id: "grand-army", title: "Grand Army",
               detail: "Recruit 30 generals.", symbol: "flag.2.crossed.fill"),
        Trophy(id: "veteran", title: "Veteran Commander",
               detail: "Reach level 20.", symbol: "chevron.up.2"),
        Trophy(id: "imperial-treasury", title: "Imperial Treasury",
               detail: "Hold 10,000 gold at once.", symbol: "building.columns.fill"),
        Trophy(id: "five-tigers", title: "The Five Tigers",
               detail: "Command Guan Yu, Zhang Fei, Zhao Yun, Ma Chao and Huang Zhong.", symbol: "crown.fill"),
        Trophy(id: "heir", title: "Heir to the Strategist",
               detail: "Recruit Jiang Wei.", symbol: "scroll.fill"),
        Trophy(id: "legendary-army", title: "Legendary Army",
               detail: "Recruit 60 generals.", symbol: "star.circle.fill"),
        Trophy(id: "master-of-war", title: "Master of War",
               detail: "Reach level 30.", symbol: "chevron.up.chevron.down"),
        Trophy(id: "fortune", title: "Fortune of Kingdoms",
               detail: "Hold 50,000 gold at once.", symbol: "crown"),
        Trophy(id: "yi-ji", title: "The Yi Ji Mix-up",
               detail: "Zhang Lu joins after Liu Bei is mistaken for Yi Ji in Chapter 6.", symbol: "theatermasks.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        MesenSaves.saveFile(for: game)
    }

    func earned(from save: Data) -> Set<String> {
        let bytes = [UInt8](save)
        guard bytes.count >= Self.statusBase + 0x100 else { return [] }
        func joined(_ ids: [Int]) -> Bool {
            ids.contains { bytes[Self.statusBase + $0] & Self.joinedBit != 0 }
        }
        func number(at offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16
        }
        let recruited = (0..<0x100).filter { $0 != General.liuBei && bytes[Self.statusBase + $0] & Self.joinedBit != 0 }.count
        let experience = number(at: Self.experience)
        let level = Int(bytes[Self.level])
        let gold = number(at: Self.gold)

        var earned = Set<String>()
        if experience > 0 { earned.insert("first-victory") }
        if level >= 10 { earned.insert("seasoned") }
        if level >= 20 { earned.insert("veteran") }
        if level >= 30 { earned.insert("master-of-war") }
        if gold >= 1_000 { earned.insert("full-coffers") }
        if gold >= 10_000 { earned.insert("imperial-treasury") }
        if gold >= 50_000 { earned.insert("fortune") }
        if joined(General.zhangLu) { earned.insert("yi-ji") }
        if recruited >= 1 { earned.insert("first-recruits") }
        if recruited >= 10 { earned.insert("growing-army") }
        if recruited >= 30 { earned.insert("grand-army") }
        if recruited >= 60 { earned.insert("legendary-army") }
        if joined(General.guanYu), joined(General.zhangFei) { earned.insert("peach-garden") }
        if joined(General.zhugeLiang) { earned.insert("sleeping-dragon") }
        if joined(General.pangTong) { earned.insert("phoenix") }
        if joined(General.jiangWei) { earned.insert("heir") }
        if [General.guanYu, General.zhangFei, General.zhaoYun, General.maChao, General.huangZhong].allSatisfy(joined) {
            earned.insert("five-tigers")
        }
        return earned
    }
}
