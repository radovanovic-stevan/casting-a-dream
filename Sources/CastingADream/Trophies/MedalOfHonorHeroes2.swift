import Foundation

/// Medal of Honor: Heroes 2 (Europe, Wii, RM2P69).
///
/// The game's own awards are the trophies. data/locks.xml on the disc defines 23 (id 1–23) with their
/// conditions; /locale/eng_us.loc has their names and descriptions. game.dol's award manager
/// (around 0x800CAF00) sets byte `0x3C4A + id` of the profile when an award is earned, and the profile is
/// saved from offset 0x84 of the save file, so the flags are at 0x3CCE + id. Each profile is a file in
/// Dolphin's data folder ("001", ...); 0x48 holds 0x80 and 0x4C the profile size 0x4AE0.
/// Checked on two US saves from GameFAQs: the award bytes are only 0 or 1, the more advanced save has a
/// superset, and the kill awards line up (100, 250 and 500 kills set in order).
struct MedalOfHonorHeroes2Trophies: TrophySet {
    let id = "medal-of-honor-heroes-2"
    let system = GameSystem.wii
    let romSHA1: Set<String> = ["8dc140d9c4fc1bebdd1cb0380abbe697fb8843dd"]

    private static let gameID = "RM2P"
    private static let awards = 0x3CCE
    private static let awardCount = 23

    /// The awards in id order (1–23), as the game names and describes them.
    private static let awardList: [(id: String, title: String, detail: String, symbol: String)] = [
        ("participant", "Participant", "Complete Campaign mode on the Green difficulty setting.", "flag.fill"),
        ("veteran", "Veteran", "Complete Campaign mode on the Veteran difficulty setting.", "flag.2.crossed.fill"),
        ("heroism", "Heroism", "Complete Campaign mode on the Hero difficulty setting.", "star.circle.fill"),
        ("marksmanship", "Marksmanship", "Complete a Mission with 75% accuracy.", "scope"),
        ("endurance", "Endurance", "Complete a Mission without being critically injured once.", "heart.fill"),
        ("green-survivor", "Green Survivor", "Complete a Mission on Green without dying once.", "shield"),
        ("veteran-survivor", "Veteran Survivor", "Complete a Mission on Veteran without dying once.", "shield.lefthalf.filled"),
        ("hero-survivor", "Hero Survivor", "Complete a Mission on Hero without dying once.", "shield.fill"),
        ("combat-basic", "Combat Basic", "Kill 100 enemy soldiers on the battlefield.", "1.circle.fill"),
        ("combat-senior", "Combat Senior", "Kill 250 enemy soldiers on the battlefield.", "2.circle.fill"),
        ("combat-master", "Combat Master", "Kill 500 enemy soldiers on the battlefield.", "3.circle.fill"),
        ("sharpshooter", "Sharpshooter", "Get 100 headshots on the battlefield.", "target"),
        ("pistol-combat", "Pistol Combat", "Kill 50 enemy soldiers with the Colt .45 or Luger pistol.", "hand.point.right.fill"),
        ("smg-combat", "SMG Combat", "Kill 250 enemy soldiers with the Thompson or MP40 sub machine guns.", "burst.fill"),
        ("lmg-combat", "LMG Combat", "Kill 150 enemy soldiers with the BAR or STG44 light machine guns.", "bolt.horizontal.fill"),
        ("rifle-combat", "Rifle Combat", "Kill 50 enemy soldiers with the M1 Garand or Karabiner 98K rifles.", "line.diagonal"),
        ("sniper-combat", "Sniper Combat", "Kill 50 enemy soldiers with the scoped Gewehr or Springfield rifle.", "binoculars.fill"),
        ("shotgun-combat", "Shotgun Combat", "Kill 50 enemy soldiers with the Shotgun.", "circle.grid.2x2.fill"),
        ("rocket-combat", "Rocket Combat", "Kill 25 enemy soldiers with the Bazooka or Panzerschreck.", "flame.fill"),
        ("grenade-combat", "Grenade Combat", "Kill 25 enemy soldiers with grenades.", "circle.circle.fill"),
        ("machine-gun-combat", "Machine Gun Combat", "Kill 50 enemy soldiers with the MG42 machine gun.", "dot.radiowaves.right"),
        ("melee-combat", "Melee Combat", "Kill 25 enemy soldiers in melee combat.", "hand.raised.fill"),
        ("weapon-expert", "Weapon Expert", "Get at least 1 kill with each weapon in the game.", "rosette"),
    ]

    let trophies = awardList.map { Trophy(id: $0.id, title: $0.title, detail: $0.detail, symbol: $0.symbol) } + [
        Trophy(id: "decorated", title: "Decorated",
               detail: "Earn 10 awards.", symbol: "medal"),
        Trophy(id: "medal-of-honor", title: "Medal of Honor",
               detail: "Earn every award.", symbol: "medal.fill",
               secret: true),
    ]

    func saveURL(for game: Game) -> URL? {
        DolphinWiiSaves.file(gameID: Self.gameID) { url in
            (try? Data(contentsOf: url)).map(Self.isProfile) ?? false
        }
    }

    func earned(from save: Data) -> Set<String> {
        guard Self.isProfile(save) else { return [] }
        let flags = (1...Self.awardCount).map { save[save.startIndex + Self.awards + $0] }
        guard flags.allSatisfy({ $0 <= 1 }) else { return [] }
        let won = zip(Self.awardList, flags).filter { $0.1 == 1 }.map(\.0.id)

        var earned = Set(won)
        if won.count >= 10 { earned.insert("decorated") }
        if won.count == Self.awardCount { earned.insert("medal-of-honor") }
        return earned
    }

    private static func isProfile(_ data: Data) -> Bool {
        data.count >= awards + awardCount + 1
            && data.bigEndianU32(at: 0x48) == 0x80 && data.bigEndianU32(at: 0x4C) == 0x4AE0
    }
}
