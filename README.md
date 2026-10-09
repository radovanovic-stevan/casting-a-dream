# Casting a Dream

<img src="Resources/icon/casting-a-dream.svg" alt="Casting a Dream icon" width="128"/>

A Mac launcher for my Dreamcast and PSP games. It shows both libraries in one window and opens each game in the right emulator: [Flycast](https://github.com/flyinghead/flycast) for Dreamcast, [PPSSPP](https://github.com/hrydgard/ppsspp) for PSP.

The emulators are the regular, unmodified apps. They open as normal Mac apps with their own window, Dock icon and menus, so ⌘Q, ⌘Tab and full screen work as usual. When the emulator quits, the launcher's library comes back.

## Requirements

- macOS 14 or later, Apple Silicon
- `Flycast.app` and `PPSSPP.app` in `/Applications` (or `~/Applications`). The launcher finds them by bundle identifier (`com.flyinghead.Flycast`, `org.ppsspp.ppsspp`) and prefers the copies in an Applications folder over ones in build folders.

## Library

- Games are read from `~/Games/Dreamcast` and `~/Games/PSP`, one folder per game (loose files work too).
  - Dreamcast: `.chd`, `.gdi`, `.cue`, `.cdi`
  - PSP: `.iso`, `.cso`, `.chd`, `.pbp`
- The library rescans whenever the launcher comes to the front, and with ⌘R.
- Covers: a `cover.png`/`.jpg` (or `boxart`, `folder`) in the game's folder wins. Otherwise box art is downloaded once from [libretro-thumbnails](https://thumbnails.libretro.com) by Redump/No-Intro name and cached in `~/Library/Application Support/Casting a Dream/Covers`. Misses are retried after a week.
- Play history is kept in `~/Library/Application Support/Casting a Dream/recents.json`.
- Each game has a violet button (also in its right-click menu) that opens it in [my collection](https://collection.stevan.co.rs). The collection has no per-game pages, so the link is a search for the title plus a platform filter, e.g. `?q=Sonic%20Rivals&platforms=PSP`. The title comes from the folder name without the bracketed parts, so a folder name that differs from the collection's title won't find the game.

## Playing

- Double-click a game, press Return, or press A on a controller.
- Games open in a window. **Library → Launch Games Full Screen** switches to full screen.
- While a game runs, the launcher shows a **Playing** screen with **Show Game** and **Stop Game**. Stop Game asks the emulator to quit and forces it after 5 seconds if it hasn't.
- Quitting the launcher also quits the game it started.
- Exiting the game from the emulator's own menu quits the emulator too: Flycast does this when it's started with a game, and PPSSPP gets `--pause-menu-exit`.

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
