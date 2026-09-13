# Reusable material palette

The game supports independent material and color variation. Interpretation selects
one of the keys below and an opaque `#RRGGBB` color. The same neutral material can
be brown, blue, green or any other tint without generating another image.

Each runtime tile is
an opaque **128 × 128 grayscale PNG**. All 15 PNGs total **84,955 bytes (83.0 KiB)**;
Godot's generated import cache is additional. The catalog is
[`palette.json`](../../3d_game/assets/materials/palette.json).

| Key | Surface | Roughness | Metallic |
|---|---|---:|---:|
| `wood` | Wood grain | 0.8 | 0 |
| `bark` | Tree bark | 0.95 | 0 |
| `stone` | Mottled stone | 0.95 | 0 |
| `brick` | Brickwork | 0.9 | 0 |
| `fabric` | Woven cloth | 0.95 | 0 |
| `knit` | Knitted yarn | 0.95 | 0 |
| `leather` | Soft leather | 0.8 | 0 |
| `metal` | Brushed metal | 0.38 | 0.85 |
| `ceramic` | Glazed ceramic | 0.3 | 0 |
| `rubber` | Matte rubber | 0.9 | 0 |
| `paper` | Paper fibers | 0.95 | 0 |
| `bone` | Bone or ivory | 0.75 | 0 |
| `fur` | Short fur | 0.95 | 0 |
| `scales` | Overlapping scales | 0.65 | 0 |
| `food` | Bread or biscuit crumb | 0.95 | 0 |

## Runtime contract

```json
{
  "name": "Dog Bone",
  "description": "A simple dog bone shape that can be a chew toy or a treat for a dog.",
  "type": "TOY",
  "movable": true,
  "texture_key": "bone",
  "color": "#D9D1C7"
}
```

This is the item returned by the live Stage 2 interpretation check. The prompt
lists all keys and their surface descriptions. It chooses the dominant material,
chooses the closest suitable material, and selects a suitable color based on the identified
object. Backend and game reject unknown keys and invalid hex colors.

Image edit receives the same material key and hex color. Its prompt requests that
color across the whole object, subtle shading, and no contrasting part colors.
The sketch remains the authority for shape and pose. This aligns the reference
with the game's single material tint without another AI call; lighting and image
generation can still produce visible color differences.

Godot loads the selected bundled texture, multiplies it by the color, and uses
local triplanar mapping. The texture follows a movable object as it falls or turns.
One preset covers the whole object; separate handles, eyes, labels or multiple
materials are not inferred. Roughness and metallic are authored preset values,
not generated per request. The palette does not introduce extra image calls.

## Generation and preparation

One authorized OpenAI Image API call used `gpt-image-2`, medium quality, opaque
1024 × 1024 PNG output via the image-generation skill's bundled CLI. It completed
in 42.6 seconds. This is one-time asset creation, not gameplay latency.

The [exact prompt](../assets/material-palette/prompt.txt) requests a 4 × 4 grayscale
atlas with fixed cell order, flat lighting, no text/borders, subtle repeatable
patterns, and this style: **soft hand-painted storybook surfaces, gentle brush
strokes, simple readable patterns, low contrast**.

Source atlas SHA-256: `93081cc961edae8375c8ecb1144c08dae2186c9dcebb89f097375897888baba2`.

`backend/utils/prepare_material_palette.py` skips the original plain cell, crops the other 15 cells, removes two edge pixels,
resizes to 128 pixels, blends opposing edge bands, and quantizes to 16 light-gray
levels before saving optimized PNGs. This preserves tint flexibility and keeps
files small. Edge pixels match; complex patterns may still reveal repetition.
The AI-created raster source is retained at `backend/output/material-palette/source-atlas.png`.
The prepared runtime files are in `3d_game/assets/materials/`.

To rebuild, install Pillow for asset preparation only, then run:

```sh
backend/.venv/bin/python -m pip install 'Pillow>=11,<13'
backend/.venv/bin/python backend/utils/prepare_material_palette.py backend/output/material-palette/source-atlas.png
```

## Verification

The existing offline tests validate all palette keys and the six-field item schema.
The desktop game smoke loads all 15 textures, checks 128-pixel dimensions, reuses
one texture with two distinct tints, verifies different metallic properties, and
rejects invalid keys/colors. The full backend suite remains 20 tests.

Stage 2 render checks reused a previously generated model with brown wood, blue
metal and bone materials. The saved UNKNOWN flower also rendered and allowed
another sketch without distracting the dog or opening the exit. Screenshots,
source atlas and the saved live interpretation remain in ignored local
`backend/output/material-palette/`, rather than shipping as game assets.

The broader dog smoke test has reported patrol and sketch-placement failures.
The shared-color prompt passed offline routing checks; live reference-to-model
color matching has not yet been measured.
