#!/bin/sh
# Builds the launcher into build/Casting a Dream.app and signs it ad hoc.
# Flycast and PPSSPP are separate apps; the launcher finds them by bundle identifier.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/Casting a Dream.app"

swift build -c release --arch arm64 --package-path "$root"
bin_dir="$(swift build -c release --arch arm64 --package-path "$root" --show-bin-path)"

rm -rf "$out"
mkdir -p "$out/Contents/MacOS" "$out/Contents/Resources"
cp "$bin_dir/CastingADream" "$out/Contents/MacOS/Casting a Dream"
cp "$root/Resources/Info.plist" "$out/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$out/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$out"
codesign --verify --strict "$out"
echo "Built $out"
