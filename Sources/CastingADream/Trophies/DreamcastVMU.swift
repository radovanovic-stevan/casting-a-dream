import Foundation

/// Flycast keeps each game's VMU (controller A, slot 1) in its data folder as
/// <product number>_vmu_save_A1.bin when "Per Game VMU A1" is on (the default), else a shared vmu_save_A1.bin.
/// The product number comes from the disc header, with spaces and / \ : * ? | < > " turned into "_".
enum FlycastSaves {
    static func vmu(productNumber: String) -> URL? {
        let fm = FileManager.default
        let data = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Flycast/data")
        let invalid = Set(" /\\:*?|<>\"")
        let prefix = String(productNumber.map { invalid.contains($0) ? "_" : $0 })
        return [prefix + "_vmu_save_A1.bin", "vmu_save_A1.bin"]
            .map { data.appendingPathComponent($0) }
            .first { fm.fileExists(atPath: $0.path) }
    }
}

/// A 128 KB Dreamcast VMU image: 256 blocks of 512 bytes, little endian.
/// Block 255 is the root (FAT block at 0x46, directory block at 0x4A, directory length at 0x4C);
/// the directory runs downwards from there in 32-byte entries (type 0x33 data / 0xCC game,
/// first block at 0x02, 12-byte name at 0x04, length in blocks at 0x18). The FAT holds the
/// next block for each block.
enum DreamcastVMU {
    private static let blockSize = 512

    /// Contents of the named file (whole blocks), or nil if it isn't on the VMU.
    static func file(named name: String, in image: Data) -> Data? {
        let bytes = [UInt8](image)
        guard bytes.count == 256 * blockSize else { return nil }
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        let root = 255 * blockSize
        let fat = u16(root + 0x46) * blockSize
        let directory = u16(root + 0x4A)
        let directoryBlocks = u16(root + 0x4C)
        guard fat < bytes.count, directory < 256, directoryBlocks <= directory + 1 else { return nil }

        for block in stride(from: directory, to: directory - directoryBlocks, by: -1) {
            for entry in stride(from: block * blockSize, to: (block + 1) * blockSize, by: 32) {
                guard bytes[entry] == 0x33 || bytes[entry] == 0xCC else { continue }
                let fileName = String(decoding: bytes[(entry + 4)..<(entry + 16)], as: UTF8.self)
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
                guard fileName == name else { continue }
                var data = Data()
                var next = u16(entry + 2)
                for _ in 0..<u16(entry + 0x18) {
                    guard next < 256 else { return nil }
                    data.append(contentsOf: bytes[(next * blockSize)..<((next + 1) * blockSize)])
                    next = u16(fat + next * 2)
                }
                return data
            }
        }
        return nil
    }
}
