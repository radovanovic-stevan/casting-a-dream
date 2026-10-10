# Casting a Dream

<img src="Resources/icon/casting-a-dream.svg" alt="Casting a Dream icon" width="128"/>

A Mac launcher for my Dreamcast, PSP, Wii, GameCube and Famicom games. It shows them in one library and opens each game in the right emulator: [Flycast](https://github.com/flyinghead/flycast) for Dreamcast, [PPSSPP](https://github.com/hrydgard/ppsspp) for PSP, [Dolphin](https://dolphin-emu.org) for Wii and GameCube, [Mesen](https://github.com/SourMesen/Mesen2) for Famicom.

The emulators are the regular, unmodified apps. They open as normal Mac apps with their own window, Dock icon and menus, so ⌘Q, ⌘Tab and full screen work as usual. When the emulator quits, the launcher's library comes back.

## Requirements

- macOS 14 or later, Apple Silicon
- `Flycast.app`, `PPSSPP.app`, `Dolphin.app` and `Mesen.app` in `/Applications` (or `~/Applications`). The launcher finds them by bundle identifier (`com.flyinghead.Flycast`, `org.ppsspp.ppsspp`, `org.dolphin-emu.dolphin`, `ca.mesen`) and prefers the copies in an Applications folder over ones in build folders. Dolphin installs with `brew install --cask dolphin`; Mesen comes from its [GitHub releases](https://github.com/SourMesen/Mesen2/releases) (Apple Silicon build). Mesen shows a setup wizard on its first start, which has to be finished once before games launch from here.

## Library

- Games are read from `~/Games/Dreamcast`, `~/Games/PSP`, `~/Games/Wii`, `~/Games/GameCube` and `~/Games/Famicom`, one folder per game (loose files work too). The header only shows a system once it has games.
  - Dreamcast: `.chd`, `.gdi`, `.cue`, `.cdi`
  - PSP: `.iso`, `.cso`, `.chd`, `.pbp`
  - Wii: `.rvz`, `.wbfs`, `.iso`, `.wia`, `.gcz`, `.ciso`
  - GameCube: `.rvz`, `.iso`, `.gcm`, `.gcz`, `.ciso`, `.wia`
  - Famicom: `.nes`, `.fds`, `.unf`, `.unif`
- The library rescans whenever the launcher comes to the front, and with ⌘R.
- Covers: a `cover.png`/`.jpg` (or `boxart`, `folder`) in the game's folder wins. Otherwise box art is downloaded once from [libretro-thumbnails](https://thumbnails.libretro.com) by Redump/No-Intro name and cached in `~/Library/Application Support/Casting a Dream/Covers`. Misses are retried after a week.
- Play history is kept in `~/Library/Application Support/Casting a Dream/stats.json`: when each game was last played and its total play time. A session runs from the emulator opening until it quits; time the Mac spends asleep doesn't count, and quitting the launcher mid-game still records the session. Each card shows the total; games played before tracking existed show "No time tracked yet" until their next session.
- Each game has a violet button (also in its right-click menu) that opens it in [my collection](https://collection.stevan.co.rs). The collection has no per-game pages, so the link is a search for the title plus a platform filter, e.g. `?q=Sonic%20Rivals&platforms=PSP`. The title comes from the folder name without the bracketed parts. When that differs from the collection's title (a fan translation, a different romanization), put a `collection.txt` in the game's folder with the search to use instead, e.g. `Tenchi wo Kurau II`.

## Playing

- Double-click a game, press Return, or press A on a controller.
- Games open in a window. **Library → Launch Games Full Screen** switches to full screen.
- While a game runs, the launcher shows a **Playing** screen with **Show Game** and **Stop Game**. Stop Game asks the emulator to quit and forces it after 5 seconds if it hasn't.
- Quitting the launcher also quits the game it started.
- Exiting the game from the emulator's own menu quits the emulator too: Flycast does this when it's started with a game, PPSSPP gets `--pause-menu-exit`, and Dolphin runs in batch mode (`-b`), which shows only the game window. Dolphin also gets `ConfirmStop=False` so quitting isn't held up by its "stop emulation?" prompt, and its first-run usage statistics question is skipped (reporting stays off). Mesen has no such mode: closing a game leaves Mesen open, so quit it (⌘Q) or use Stop Game to come back.

## Trophies

Secret trophies show as "Secret trophy" until earned. Games with a trophy set show a gold count on their card; clicking it (or **Trophies…** in the right-click menu) lists every trophy and when it was unlocked. Trophies are checked from the game's save file whenever its emulator closes, and when the launcher comes to the front (for games played outside it). New unlocks pop up in the top-right corner. Unlocks are stored in `~/Library/Application Support/Casting a Dream/trophies.json`.

A trophy set is matched to a game by the SHA-1 of its file, so renaming the folder doesn't lose it. Sets so far:

- **Destiny of an Emperor II** (English translation v1.12, SHA-1 `d02cc267e0b350b2dc84f087fbc04a778f976973`), 17 trophies: recruiting generals (specific ones and 10/30/60), first victory, party level 10/20/30, gold held (1,000/10,000/50,000) and one secret trophy. It reads Mesen's battery save (`~/Library/Application Support/Mesen2/Saves/<ROM name>.sav`): one status byte per general at `$6200 + id` (bit `0x40` set when he joins; the leader is left out of counts because a defeat sets his), experience at `$6028` and gold at `$602C` (3 bytes each, little endian), level at `$602B`. General ids come from the ROM's general table (pointer low bytes at ROM `$6DE00`, high bytes at `$6DF00`). The layout was worked out by playing the game headless in Mesen and comparing battery RAM before and after generals joined. See `Sources/CastingADream/Trophies/DestinyOfAnEmperorII.swift`.

To add a game, implement `TrophySet` (how to find the save, which trophies the bytes earn) and add it to `TrophySets.all`.

## Controls

| | Keyboard | Controller |
|---|---|---|
| Move | Arrow keys | D-pad / left stick |
| Play | Return or double-click | A (✕ on PlayStation) |
| Switch system | Click the pills | L1 / R1 |
| Clear search / selection | Esc | B (○) |
| Search | ⌘F | — |

## Building

```sh
scripts/package.sh                       # builds build/Casting a Dream.app
mv "build/Casting a Dream.app" /Applications/
```

To change the icon, edit `Resources/icon/casting-a-dream.svg` and run `scripts/render-icon.sh` (needs `brew install librsvg`).

### Building the emulators from source

Both build on Apple Silicon from their upstream repositories:

- **Flycast:** `brew install cmake ninja molten-vk libomp`, `xcodebuild -downloadComponent MetalToolchain`, then
  `cmake -B build -G Xcode -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_INSTALL_PREFIX=artifact -DUSE_BREAKPAD=OFF -DMOLTENVK_DYLIB=/opt/homebrew/opt/molten-vk/lib/libMoltenVK.dylib`
  and `cmake --build build --config Release --target install`. The app is `artifact/bin/Flycast.app`.
- **PPSSPP:** `brew install sdl3 sdl3_ttf`, then `./b.sh --release --arm64`. The app is `build/PPSSPPSDL.app`; copy it to `/Applications/PPSSPP.app` and re-sign it with `codesign --force --deep --sign - /Applications/PPSSPP.app`.
