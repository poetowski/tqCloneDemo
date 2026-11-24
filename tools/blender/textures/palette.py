"""Bakes data/palette.json into the two palette textures every model samples:

- assets/textures/palette_albedo.png: sRGB colour per swatch cell.
- assets/textures/palette_params.png: R roughness, G metallic, B emission (0..1).

Unused cells are magenta in the albedo, so a face with a wrong UV shows at once.
Runs first in `npm run models` (the folder order in tools/dev.mjs).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402


def main():
    palette = kit.Palette()
    grid, cell = palette.grid, palette.cell_px
    size = grid * cell
    by_index = {entry["index"]: entry for entry in palette.entries.values()}
    albedo_rows, params_rows = [], []
    for y in range(size):
        row_a, row_p = bytearray(), bytearray()
        cell_row = y // cell
        for x in range(size):
            entry = by_index.get(cell_row * grid + x // cell)
            if entry is None:
                row_a += bytes((255, 0, 255))
                row_p += bytes((255, 0, 0))
                continue
            row_a += bytes(round(c * 255) for c in entry["srgb"])
            row_p += bytes((round(entry["roughness"] * 255), round(entry["metallic"] * 255), round(entry["emission"] * 255)))
        albedo_rows.append(row_a)
        params_rows.append(row_p)
    kit.write_png(kit.PALETTE_ALBEDO, size, size, albedo_rows)
    kit.write_png(kit.PALETTE_PARAMS, size, size, params_rows)
    kit.log("palette", f"{len(palette.entries)} swatches -> assets/textures/palette_albedo.png, palette_params.png ({size}x{size})")


kit.run(main)
