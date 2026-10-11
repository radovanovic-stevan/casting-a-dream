import Foundation
import CommonCrypto

/// PPSSPP keeps each save in its memory stick folder as PSP/SAVEDATA/<game id><save name>/, e.g.
/// UCES012500000 for UCES01250's "0000" save, with the game's data files next to PARAM.SFO.
enum PPSSPPSaves {
    /// The most recently written copy of this file among the game's save folders.
    static func file(named name: String, gameID: String) -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let memorySticks = [
            home.appendingPathComponent(".config/ppsspp/PSP"),
            home.appendingPathComponent("Library/Application Support/PPSSPP/PSP"),
            home.appendingPathComponent("Documents/PPSSPP/PSP"),
        ]
        return memorySticks
            .map { $0.appendingPathComponent("SAVEDATA") }
            .flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
            .filter { $0.lastPathComponent.hasPrefix(gameID) }
            .map { $0.appendingPathComponent(name) }
            .filter { fm.fileExists(atPath: $0.path) }
            .max { modified($0) < modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}

/// Decrypts a PSP save file written with a game key, in encryption mode 3 (older firmware) or 5.
///
/// This is PPSSPP's sceChnnlsv cipher (Core/HLE/sceChnnlsv.cpp) reduced to what decryption needs: the file
/// starts with a 16-byte header; header ⊕ game key, ⊕ a mix key, AES-decrypted with the mode's first KIRK key,
/// ⊕ a second mix key gives a 12-byte prefix. Data block n (from 1) is then XORed with
/// AES-decrypt(the mode's second KIRK key, prefix ‖ n) and with prefix ‖ n−1 (zeros for the first block).
/// Checked byte for byte against PPSSPP's own code.
enum PSPSavedata {
    enum Mode: CaseIterable {
        case mode5, mode3

        /// KIRK key 0x12 or 0x0E for the prefix, key19DC or key19AC before it and key19CC or key199C after.
        fileprivate var prefixKey: [UInt8] { self == .mode5 ? kirkKey12 : kirkKey0E }
        fileprivate var mixIn: [UInt8] { self == .mode5 ? key19DC : key19AC }
        fileprivate var mixOut: [UInt8] { self == .mode5 ? key19CC : key199C }
        /// KIRK key 0x64 or 0x57 for the data blocks.
        fileprivate var dataKey: [UInt8] { self == .mode5 ? kirkKey64 : kirkKey57 }
    }

    private static let kirkKey12: [UInt8] = [0x5D, 0xC7, 0x11, 0x39, 0xD0, 0x19, 0x38, 0xBC,
                                             0x02, 0x7F, 0xDD, 0xDC, 0xB0, 0x83, 0x7D, 0x9D]
    private static let kirkKey64: [UInt8] = [0x03, 0xB3, 0x02, 0xE8, 0x5F, 0xF3, 0x81, 0xB1,
                                             0x3B, 0x8D, 0xAA, 0x2A, 0x90, 0xFF, 0x5E, 0x61]
    private static let kirkKey0E: [UInt8] = [0xC8, 0x71, 0xFD, 0xB3, 0xBC, 0xC5, 0xD2, 0xF2,
                                             0xE2, 0xD7, 0x72, 0x9D, 0xDF, 0x82, 0x68, 0x82]
    private static let kirkKey57: [UInt8] = [0x1C, 0x9B, 0xC4, 0x90, 0xE3, 0x06, 0x64, 0x81,
                                             0xFA, 0x59, 0xFD, 0xB6, 0x00, 0xBB, 0x28, 0x70]
    private static let key19CC: [UInt8] = [0x70, 0x44, 0xA3, 0xAE, 0xEF, 0x5D, 0xA5, 0xF2,
                                           0x85, 0x7F, 0xF2, 0xD6, 0x94, 0xF5, 0x36, 0x3B]
    private static let key19DC: [UInt8] = [0xEC, 0x6D, 0x29, 0x59, 0x26, 0x35, 0xA5, 0x7F,
                                           0x97, 0x2A, 0x0D, 0xBC, 0xA3, 0x26, 0x33, 0x00]
    private static let key199C: [UInt8] = [0x36, 0xA5, 0x3E, 0xAC, 0xC5, 0x26, 0x9E, 0xA3,
                                           0x83, 0xD9, 0xEC, 0x25, 0x6C, 0x48, 0x48, 0x72]
    private static let key19AC: [UInt8] = [0xD8, 0xC0, 0xB0, 0xF3, 0x3E, 0x6B, 0x76, 0x85,
                                           0xFD, 0xFB, 0x4D, 0x7D, 0x45, 0x1E, 0x92, 0x03]

    static func decrypt(_ file: Data, gameKey: [UInt8], mode: Mode = .mode5) -> Data? {
        let bytes = [UInt8](file)
        guard bytes.count > 16, gameKey.count == 16 else { return nil }
        let seed = xor(xor(Array(bytes[0..<16]), gameKey), mode.mixIn)
        guard let mixed = aesDecrypt(seed, key: mode.prefixKey) else { return nil }
        let prefix = Array(xor(mixed, mode.mixOut)[0..<12])

        func counterBlock(_ n: Int) -> [UInt8] {
            prefix + withUnsafeBytes(of: UInt32(n).littleEndian, Array.init)
        }
        // The counter blocks for every data block, decrypted in one call.
        let blockCount = (bytes.count - 16 + 15) / 16
        guard let keystream = aesDecrypt((1...blockCount).flatMap(counterBlock), key: mode.dataKey) else { return nil }

        var plain = [UInt8](repeating: 0, count: bytes.count - 16)
        for n in 1...blockCount {
            let previous = n == 1 ? [UInt8](repeating: 0, count: 16) : counterBlock(n - 1)
            for i in 0..<16 where (n - 1) * 16 + i < plain.count {
                let at = (n - 1) * 16 + i
                plain[at] = bytes[16 + at] ^ keystream[at] ^ previous[i]
            }
        }
        return Data(plain)
    }

    private static func xor(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
        zip(a, b).map { $0 ^ $1 }
    }

    /// AES-128 ECB decryption of whole blocks.
    private static func aesDecrypt(_ input: [UInt8], key: [UInt8]) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: input.count)
        var moved = 0
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode),
                             key, key.count, nil, input, input.count, &output, output.count, &moved)
        return status == kCCSuccess && moved == input.count ? output : nil
    }
}
