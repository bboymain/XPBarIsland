"""Build quarter-circle atlases with constant-width borders at every radius."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
for width in range(4):
    atlas = Image.new('RGBA', (512, 512))
    for radius in range(1, 65):
        r = radius * 4
        tile = Image.new('RGBA', (r, r))
        draw = ImageDraw.Draw(tile)
        draw.ellipse((0, -r, 2*r-1, r-1), fill='white')
        if width and radius > width:
            inset = width * 4
            draw.ellipse((inset, -r+inset, 2*r-1-inset, r-1-inset), fill=(255,255,255,0))
        elif width:
            tile = Image.new('RGBA', (r, r), 'white')
        tile = tile.resize((radius, radius), Image.Resampling.LANCZOS)
        atlas.paste(tile, (((radius-1) % 8)*64, ((radius-1)//8)*64))
    atlas.save(ROOT / 'Media' / f'PillCorner{width}.tga', compression='tga_rle')
