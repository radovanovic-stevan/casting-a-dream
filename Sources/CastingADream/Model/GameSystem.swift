import SwiftUI

/// A console the launcher can play, and how to hand its games to its emulator.
enum GameSystem: String, CaseIterable, Identifiable, Codable {
    case dreamcast
    case psp
    case wii
    case gamecube
    case famicom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dreamcast: "Dreamcast"
        case .psp: "PSP"
        case .wii: "Wii"
        case .gamecube: "GameCube"
        case .famicom: "Famicom"
        }
    }

    /// Games live in ~/Games/<folderName>.
    var folderName: String { displayName }

    /// Playable file types, most preferred first. When a game folder holds several, the first match wins
    /// (e.g. a folder with both a .gdi and a .cue lists the game once).
    var extensions: [String] {
        switch self {
        case .dreamcast: ["chd", "gdi", "cue", "cdi"]
        case .psp: ["iso", "cso", "chd", "pbp"]
        case .wii: ["rvz", "wbfs", "iso", "wia", "gcz", "ciso"]
        case .gamecube: ["rvz", "iso", "gcm", "gcz", "ciso", "wia"]
        case .famicom: ["nes", "fds", "unf", "unif"]
        }
    }

    /// System folder name on thumbnails.libretro.com.
    var thumbnailSystem: String {
        switch self {
        case .dreamcast: "Sega - Dreamcast"
        case .psp: "Sony - PlayStation Portable"
        case .wii: "Nintendo - Wii"
        case .gamecube: "Nintendo - GameCube"
        case .famicom: "Nintendo - Nintendo Entertainment System"
        }
    }

    /// The emulator app that plays this system, found by bundle identifier wherever it's installed.
    var emulatorName: String {
        switch self {
        case .dreamcast: "Flycast"
        case .psp: "PPSSPP"
        case .wii, .gamecube: "Dolphin"
        case .famicom: "Mesen"
        }
    }

    var emulatorBundleID: String {
        switch self {
        case .dreamcast: "com.flyinghead.Flycast"
        case .psp: "org.ppsspp.ppsspp"
        case .wii, .gamecube: "org.dolphin-emu.dolphin"
        case .famicom: "ca.mesen"
        }
    }

    var accent: Color {
        switch self {
        case .dreamcast: Theme.cyan
        case .psp: Theme.magenta
        case .wii: Theme.ice
        case .gamecube: Theme.violet
        case .famicom: Theme.coral
        }
    }

    /// Every emulator but Mesen quits by itself when the player stops the game, which clears the
    /// launcher's "Playing" screen:
    /// - Flycast quits on "Exit" whenever it was started with a game path.
    /// - PPSSPP needs --pause-menu-exit to turn "Exit to menu" into "Exit".
    /// - Dolphin's batch mode (-b) shows only the game window and quits when emulation stops.
    ///   Its "Do you want to stop?" prompt and first-run usage statistics question would block
    ///   quitting (and Stop Game), so both are switched off. ConfirmStop applies to this launch only;
    ///   Dolphin saves PermissionAsked, so it won't ask again. Reporting stays at its default, off.
    /// - Mesen has no such mode: closing the game leaves Mesen open, so the player quits it (or uses Stop Game).
    func launchArguments(for game: URL, fullScreen: Bool) -> [String] {
        switch self {
        case .dreamcast:
            // Transient config value, not written to emu.cfg.
            ["-config", "window:fullscreen=\(fullScreen ? "yes" : "no")", game.path]
        case .psp:
            ["--pause-menu-exit", fullScreen ? "--fullscreen" : "--windowed", game.path]
        case .wii, .gamecube:
            ["-b",
             "-C", "Dolphin.Display.Fullscreen=\(fullScreen ? "True" : "False")",
             "-C", "Dolphin.Interface.ConfirmStop=False",
             "-C", "Dolphin.Analytics.PermissionAsked=True",
             "-e", game.path]
        case .famicom:
            (fullScreen ? ["--fullscreen"] : []) + [game.path]
        }
    }
}
