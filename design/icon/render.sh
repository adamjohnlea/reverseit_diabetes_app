#!/usr/bin/env bash
#
# Regenerates the AppIcon PNGs from the SVG sources and installs them into the
# asset catalog. Run from anywhere:  ./design/icon/render.sh
#
# Requires macOS `qlmanage` (built in) and ImageMagick (`brew install imagemagick`).
#
set -euo pipefail
cd "$(dirname "$0")"

OUT="build"
DEST="../../ReverseItApp/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT"

render() { # <svg> -> $OUT/<svg>.png at 1024px (qlmanage composites onto white)
  qlmanage -t -s 1024 -o "$OUT" "$1" >/dev/null 2>&1
}

# Light / default: MUST be opaque (App Store rejects an alpha channel here).
render AppIcon-Light.svg
magick "$OUT/AppIcon-Light.svg.png" \
  -background white -alpha remove -alpha off -colorspace sRGB -strip \
  "$OUT/AppIcon.png"

# Dark & Tinted: white glyph on a TRANSPARENT background so the system-provided
# backdrop shows through (dark) and the system tint applies (tinted, grayscale).
# The source is a black-glyph-on-white silhouette; negate it to white-on-black
# and copy its luminance into the alpha of a solid-white canvas — this gives
# clean, halo-free anti-aliased edges regardless of the background it lands on.
render AppIcon-Glyph.svg
# `-alpha off` first: qlmanage's PNG carries an opaque alpha channel, and a bare
# `-negate` would flip that too, zeroing the mask. We only want to invert color.
magick -size 1024x1024 xc:white \
  \( "$OUT/AppIcon-Glyph.svg.png" -alpha off -colorspace Gray -negate \) \
  -compose CopyOpacity -composite -colorspace sRGB -strip \
  "$OUT/AppIcon-Dark.png"
cp "$OUT/AppIcon-Dark.png" "$OUT/AppIcon-Tinted.png"

# Install into the asset catalog.
cp "$OUT/AppIcon.png" "$OUT/AppIcon-Dark.png" "$OUT/AppIcon-Tinted.png" "$DEST/"

echo "Installed AppIcon.png, AppIcon-Dark.png, AppIcon-Tinted.png into:"
echo "  $DEST"
