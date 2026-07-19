#!/usr/bin/env python3
"""Build the deterministic stylized-HD steel weapon sprite for issue #168.

Layout of assets/sprites/player/hd/player_weapon.png (256x128, straight alpha):
  a single authored steel arming sword, laid horizontally with the point toward
  +x and the grip toward -x. The hand/pivot sits at GRIP_PIVOT so the runtime
  `PlayerWeaponPresentation` can anchor the sword at the wanderer's hand and
  rotate it around that point to face and sweep truthfully for all four
  directions. Nothing here is animation: the held pose and the melee swing are
  procedural rotations of this one authored silhouette.

Every pixel is computed from closed-form geometry (no randomness, no external
source imagery), so reruns are byte-identical and the output is CC0-safe
hand-authored art. The palette is neutral forged steel with a warm brass guard
and a restrained cyan energy line along the edge, matching the visual-bible
relic-tech language without reading as threat-side magenta corruption.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent / "player" / "hd"

CELL = (256, 128)
SUPERSAMPLE = 3

# Authored geometry, in cell pixels. Mirrored by PlayerWeaponPresentation.
CENTER_Y = 64.0
GRIP_PIVOT = (40.0, 64.0)
POMMEL_X = 12.0
GRIP_START_X = 18.0
GUARD_X = 48.0
GUARD_HALF_HEIGHT = 19.0
BLADE_START_X = 52.0
BLADE_TIP_X = 250.0
BLADE_HALF_AT_GUARD = 13.0

# Palette (straight-alpha RGB in 0..1).
STEEL_SPINE = (0.90, 0.93, 0.98)
STEEL_MID = (0.58, 0.63, 0.71)
STEEL_EDGE = (0.24, 0.28, 0.37)
FULLER_DARK = (0.16, 0.19, 0.27)
BRASS_LIGHT = (0.86, 0.68, 0.34)
BRASS_DARK = (0.44, 0.32, 0.13)
LEATHER = (0.28, 0.20, 0.16)
LEATHER_BIND = (0.47, 0.36, 0.28)
EDGE_ENERGY = (0.35, 0.92, 1.0)


def _lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = min(1.0, max(0.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def _blade_half_height(x: float) -> float:
    """Half thickness of the blade at abscissa x (0 outside the blade span)."""
    if x < BLADE_START_X or x > BLADE_TIP_X:
        return 0.0
    span = BLADE_TIP_X - BLADE_START_X
    # Convex taper: full near the guard, drawing smoothly to a point at the tip.
    reach = (x - BLADE_START_X) / span
    return BLADE_HALF_AT_GUARD * math.sqrt(max(0.0, 1.0 - reach * reach))


def _sample(x: float, y: float) -> tuple:
    """Return straight-alpha RGBA (0..1) for one supersample point."""
    dy = y - CENTER_Y

    # Pommel: a small brass disc that balances the grip.
    pommel = math.hypot(x - POMMEL_X, dy)
    if pommel <= 6.0:
        shade = _lerp(BRASS_LIGHT, BRASS_DARK, min(1.0, pommel / 6.0))
        return (*shade, 1.0)

    # Grip: wrapped leather handle with periodic binding highlights.
    if GRIP_START_X <= x <= GUARD_X and abs(dy) <= 5.5:
        bind = 0.5 + 0.5 * math.sin((x - GRIP_START_X) * 1.7)
        shade = _lerp(LEATHER, LEATHER_BIND, bind * (1.0 - abs(dy) / 5.5))
        return (*shade, 1.0)

    # Crossguard: warm brass bar with a beveled top-to-bottom gradient.
    if GUARD_X - 3.0 <= x <= GUARD_X + 4.0 and abs(dy) <= GUARD_HALF_HEIGHT:
        shade = _lerp(BRASS_LIGHT, BRASS_DARK, abs(dy) / GUARD_HALF_HEIGHT)
        return (*shade, 1.0)

    # Blade: beveled steel with a central fuller and a cyan cutting edge.
    half = _blade_half_height(x)
    if half > 0.0 and abs(dy) <= half:
        t = abs(dy) / half
        if t < 0.30:
            shade = _lerp(STEEL_SPINE, STEEL_MID, t / 0.30)
        else:
            shade = _lerp(STEEL_MID, STEEL_EDGE, (t - 0.30) / 0.70)
        # Fuller groove: a darker line just off the spine on both faces.
        groove = 1.0 - abs(t - 0.42) / 0.10
        if groove > 0.0:
            shade = _lerp(shade, FULLER_DARK, groove * 0.7)
        # Cyan energy honed onto the outermost cutting edge.
        if t > 0.86:
            shade = _lerp(shade, EDGE_ENERGY, (t - 0.86) / 0.14 * 0.6)
        return (*shade, 1.0)

    return (0.0, 0.0, 0.0, 0.0)


def weapon_sprite() -> Image.Image:
    image = Image.new("RGBA", CELL, (0, 0, 0, 0))
    step = 1.0 / SUPERSAMPLE
    offset = step / 2.0
    samples = SUPERSAMPLE * SUPERSAMPLE
    for py in range(CELL[1]):
        for px in range(CELL[0]):
            red = green = blue = alpha = 0.0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    r, g, b, a = _sample(
                        px + offset + sx * step, py + offset + sy * step
                    )
                    red += r * a
                    green += g * a
                    blue += b * a
                    alpha += a
            if alpha <= 0.0:
                continue
            image.putpixel(
                (px, py),
                (
                    round(min(1.0, red / alpha) * 255),
                    round(min(1.0, green / alpha) * 255),
                    round(min(1.0, blue / alpha) * 255),
                    round(alpha / samples * 255),
                ),
            )
    return image


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    weapon_sprite().save(ROOT / "player_weapon.png")
    print("wrote deterministic HD steel weapon sprite")


if __name__ == "__main__":
    main()
