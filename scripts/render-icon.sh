#!/bin/sh
# Renders Resources/icon/casting-a-dream.svg into Resources/AppIcon.icns.
# Requires rsvg-convert (brew install librsvg) and iconutil (Xcode command line tools).
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
svg="$root/Resources/icon/casting-a-dream.svg"
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"

for size in 16 32 128 256 512; do
	rsvg-convert -w "$size" -h "$size" "$svg" -o "$iconset/icon_${size}x${size}.png"
	double=$((size * 2))
	rsvg-convert -w "$double" -h "$double" "$svg" -o "$iconset/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$iconset" -o "$root/Resources/AppIcon.icns"
rm -rf "$(dirname "$iconset")"
echo "Rendered $root/Resources/AppIcon.icns"
