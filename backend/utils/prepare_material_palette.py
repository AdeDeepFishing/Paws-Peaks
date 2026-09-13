"""Crop the generated 4x4 atlas into lightweight, tintable, repeating game textures."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[2]
PALETTE = ROOT / '3d_game/assets/materials'


def repeating(tile):
    # Blend opposing edges in a narrow band; retain the generated center detail.
    pixels = tile.load()
    width, height = tile.size
    band = 6
    for y in range(height):
        for i in range(band):
            a, b = pixels[i, y], pixels[width - 1 - i, y]
            mean = (a + b) / 2
            weight = (band - i) / band
            pixels[i, y] = round(a * (1 - weight) + mean * weight)
            pixels[width - 1 - i, y] = round(b * (1 - weight) + mean * weight)
    for x in range(width):
        for i in range(band):
            a, b = pixels[x, i], pixels[x, height - 1 - i]
            mean = (a + b) / 2
            weight = (band - i) / band
            pixels[x, i] = round(a * (1 - weight) + mean * weight)
            pixels[x, height - 1 - i] = round(b * (1 - weight) + mean * weight)
    return tile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('atlas', type=Path)
    args = parser.parse_args()
    entries = json.loads((PALETTE / 'palette.json').read_text())
    atlas = Image.open(args.atlas).convert('L')
    if atlas.size != (1024, 1024) or len(entries) != 15:
        raise ValueError('Expected a 1024-pixel atlas and 15 palette entries')
    preview = Image.new('RGB', (768, 864), '#f3eddf')
    labels = ImageDraw.Draw(preview)
    tints = ['#B88755', '#79604A', '#A2ABB3', '#BB7D68', '#A5BDA0', '#C5A2AB', '#8A6656',
             '#A1AFB9', '#91B5BE', '#707B85', '#D7C6A3', '#E8D9B7', '#B7A18B', '#8AAE97', '#D5B680']
    total = 0
    # The original atlas begins with an unused plain cell; preserve the other cell positions.
    for index, (key, tint) in enumerate(zip(entries, tints), start=1):
        x, y = (index % 4) * 256, (index // 4) * 256
        tile = ImageOps.autocontrast(atlas.crop((x + 2, y + 2, x + 254, y + 254))).resize((128, 128), Image.Resampling.LANCZOS)
        tile = repeating(tile)
        # 16 light-gray levels keep colors clean and PNGs compact.
        tile = tile.point(lambda v: round(180 + round(v * 15 / 255) * 75 / 15))
        tile.save(PALETTE / (key + '.png'), optimize=True)
        assert list(tile.crop((0, 0, 1, 128)).getdata()) == list(tile.crop((127, 0, 128, 128)).getdata())
        assert list(tile.crop((0, 0, 128, 1)).getdata()) == list(tile.crop((0, 127, 128, 128)).getdata())
        total += (PALETTE / (key + '.png')).stat().st_size
        swatch = ImageOps.colorize(tile, '#000000', tint).resize((176, 176))
        px, py = (index % 4) * 192 + 8, (index // 4) * 216 + 8
        preview.paste(swatch, (px, py))
        labels.text((px, py + 183), key, fill='#293731')
    preview_dir = ROOT / 'backend/output/material-palette'
    preview_dir.mkdir(parents=True, exist_ok=True)
    preview.save(preview_dir / 'palette.png', optimize=True)
    print(f'Prepared {len(entries)} grayscale 128x128 textures; {total} bytes total.')


if __name__ == '__main__':
    main()
