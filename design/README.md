# App icon design sources

Editable vector sources for the ReverseIt! app icon and the exploration
concepts that led to it.

```
design/
  icon/
    AppIcon-Light.svg   Default/light icon (opaque green→teal, descending glucose curve)
    AppIcon-Glyph.svg   Black-on-white silhouette; source for the Dark & Tinted variants
    render.sh           Rasterizes the SVGs and installs the PNGs into the asset catalog
    build/              Generated PNGs (git-ignored; recreated by render.sh)
  concepts/
    concept-1-descending-curve.svg
    concept-2-reverse-loop.svg
    concept-3-pulse-arrow.svg
```

## Regenerating the icon

```bash
brew install imagemagick   # one-time; qlmanage ships with macOS
./design/icon/render.sh
```

The script produces three 1024×1024 PNGs and copies them into
`ReverseItApp/Assets.xcassets/AppIcon.appiconset/`:

| Variant | Background | Alpha | Notes                                                        |
| ------- | ---------- | ----- | ------------------------------------------------------------ |
| Light   | Opaque     | No    | App Store rejects an alpha channel on the default icon.      |
| Dark    | Transparent| Yes   | System draws its dark backdrop behind the white glyph.       |
| Tinted  | Transparent| Yes   | Grayscale (white) glyph; the system applies the user's tint. |

## Design notes

- Metaphor: a glucose curve rising to a peak (droplet marker) then trending
  down into an arrow — "bring your numbers down / reverse it".
- Palette: health green (`#3DDC84`) → teal (`#0E9F8E`).
- Dark and tinted share one silhouette (`AppIcon-Glyph.svg`) so the icon's core
  features stay consistent across appearances, per Apple's HIG.
