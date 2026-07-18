#!/usr/bin/env python3
"""Deterministically build the authored 32px teal wanderer player sheet for issue #133."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent
player_dir = ROOT / "player"
FRAME = 32
COLUMNS = 6
ROW_ORDER = [
    "idle_down", "idle_up", "idle_side",
    "walk_down", "walk_up", "walk_side",
    "dash_down", "dash_up", "dash_side",
    "attack_melee_down", "attack_melee_up", "attack_melee_side",
    "attack_relic_down", "attack_relic_up", "attack_relic_side",
    "hurt", "death",
]

TRANSPARENT = (0, 0, 0, 0)
# Player identity ramp + accents from docs/visual_bible.md §2.3.
DARK = (0x0E, 0x5F, 0x58, 255)
MID = (0x1F, 0xD1, 0xC2, 255)
LIGHT = (0xA8, 0xFF, 0xF2, 255)
MAGENTA = (0xF2, 0x59, 0xB8, 255)
CYAN_DEEP = (0x1F, 0xA0, 0xA8, 255)
CYAN = (0x4D, 0xE5, 0xFF, 255)
CYAN_GLOW = (0xC8, 0xF8, 0xFF, 255)
STEEL_DARK = (0x45, 0x45, 0x4F, 255)
STEEL = (0x63, 0x63, 0x6E, 255)
HILT = (0x4A, 0x36, 0x28, 255)
DEATH = (0x38, 0x38, 0x42, 255)
SHADOW = (0x10, 0x0D, 0x16, 102)

# Walk cycles: per-phase boot offsets keep both feet honest on the 16px grid.
FRONT_STRIDE = [(0, -2), (0, -1), (0, 0), (-2, 0), (-1, 0), (0, 0)]
SIDE_STRIDE = [(-2, 0, 2, -1), (-1, 0, 1, 0), (1, -1, -1, 0), (2, 0, -2, -1), (1, 0, -1, 0), (-1, -1, 1, 0)]
WALK_BOB = (0, -1, 0, 0, -1, 0)
IDLE_BOB = (0, 0, -1, 0)
DASH_VECTOR = {"down": (0, 1), "up": (0, -1), "side": (1, 0)}


def animation_spec() -> dict[str, tuple[int, bool, float]]:
    return {
        "idle_down": (4, True, 6.0), "idle_up": (4, True, 6.0), "idle_side": (4, True, 6.0),
        "walk_down": (6, True, 10.0), "walk_up": (6, True, 10.0), "walk_side": (6, True, 10.0),
        "dash_down": (4, False, 12.0), "dash_up": (4, False, 12.0), "dash_side": (4, False, 12.0),
        "attack_melee_down": (4, False, 12.0), "attack_melee_up": (4, False, 12.0),
        "attack_melee_side": (4, False, 12.0),
        "attack_relic_down": (3, False, 12.0), "attack_relic_up": (3, False, 12.0),
        "attack_relic_side": (3, False, 12.0),
        "hurt": (2, False, 12.0), "death": (6, False, 10.0),
    }


def _boots(d: ImageDraw.ImageDraw, facing: str, walk_phase: int, dark: tuple[int, int, int, int]) -> None:
    if facing == "side":
        back_dx, back_dy, front_dx, front_dy = SIDE_STRIDE[walk_phase] if walk_phase >= 0 else (0, 0, 0, 0)
        d.rectangle((12 + back_dx, 23 + back_dy, 14 + back_dx, 25 + back_dy), fill=dark)
        d.rectangle((16 + front_dx, 23 + front_dy, 18 + front_dx, 25 + front_dy), fill=dark)
        return
    left_dy, right_dy = FRONT_STRIDE[walk_phase] if walk_phase >= 0 else (0, 0)
    d.rectangle((11, 23 + left_dy, 13, 25 + left_dy), fill=dark)
    d.rectangle((18, 23 + right_dy, 20, 25 + right_dy), fill=dark)


def _cloak(
    d: ImageDraw.ImageDraw, facing: str, b: int,
    dark: tuple[int, int, int, int], mid: tuple[int, int, int, int], light: tuple[int, int, int, int],
) -> None:
    if facing == "side":
        d.polygon([(10, 12 + b), (19, 12 + b), (21, 22 + b), (9, 22 + b)], fill=dark)
        d.polygon([(11, 13 + b), (18, 13 + b), (19, 21 + b), (11, 21 + b)], fill=mid)
        d.rectangle((12, 13 + b, 17, 13 + b), fill=light)
        d.rectangle((10, 18 + b, 19, 19 + b), fill=dark)
        return
    d.polygon([(10, 12 + b), (21, 12 + b), (23, 22 + b), (8, 22 + b)], fill=dark)
    d.polygon([(11, 13 + b), (20, 13 + b), (21, 21 + b), (10, 21 + b)], fill=mid)
    d.rectangle((12, 13 + b, 19, 13 + b), fill=light)
    if facing == "up":
        # The travelling cloak covers the back; teal trim only survives at the edges.
        d.rectangle((12, 14 + b, 19, 21 + b), fill=dark)
        return
    d.rectangle((10, 18 + b, 21, 19 + b), fill=dark)
    d.rectangle((15, 18 + b, 16, 19 + b), fill=light)


def _hood(
    d: ImageDraw.ImageDraw, facing: str, b: int,
    dark: tuple[int, int, int, int], mid: tuple[int, int, int, int], light: tuple[int, int, int, int],
) -> None:
    d.ellipse((11, 4 + b, 20, 12 + b), fill=dark)
    if facing == "up":
        d.rectangle((13, 6 + b, 18, 7 + b), fill=mid)
        return
    d.rectangle((13, 5 + b, 18, 6 + b), fill=mid)
    if facing == "side":
        d.rectangle((16, 7 + b, 19, 10 + b), fill=light)
        d.rectangle((17, 8 + b, 18, 8 + b), fill=dark)
        d.rectangle((17, 5 + b, 19, 6 + b), fill=MAGENTA)
        return
    d.rectangle((13, 7 + b, 18, 10 + b), fill=light)
    d.rectangle((13, 8 + b, 14, 8 + b), fill=dark)
    d.rectangle((17, 8 + b, 18, 8 + b), fill=dark)


def _sheathed_sword(d: ImageDraw.ImageDraw, facing: str, b: int) -> None:
    if facing == "up":
        d.line((12, 13 + b, 19, 20 + b), fill=STEEL_DARK, width=2)
        d.rectangle((9, 8 + b, 10, 11 + b), fill=HILT)
        d.rectangle((8, 11 + b, 11, 12 + b), fill=STEEL)
        d.rectangle((9, 7 + b, 10, 7 + b), fill=STEEL)
        return
    if facing == "side":
        d.rectangle((8, 9 + b, 9, 11 + b), fill=HILT)
        d.rectangle((7, 11 + b, 10, 12 + b), fill=STEEL)
        return
    d.rectangle((10, 9 + b, 11, 11 + b), fill=HILT)
    d.rectangle((10, 8 + b, 11, 8 + b), fill=STEEL)


def _relic_gem(d: ImageDraw.ImageDraw, facing: str, b: int, bright: bool) -> None:
    gem = CYAN_GLOW if bright else CYAN
    if facing == "side":
        d.rectangle((17, 15 + b, 18, 16 + b), fill=gem)
        d.rectangle((17, 17 + b, 18, 17 + b), fill=CYAN_DEEP)
        return
    d.rectangle((18, 14 + b, 19, 15 + b), fill=gem)
    d.rectangle((18, 16 + b, 19, 16 + b), fill=CYAN_DEEP)


def figure(facing: str, bob: int = 0, walk_phase: int = -1, flash: bool = False, gem_bright: bool = False) -> Image.Image:
    """Draw the wanderer (no shadow) so states can offset the whole body."""
    image = Image.new("RGBA", (FRAME, FRAME), TRANSPARENT)
    d = ImageDraw.Draw(image)
    dark = MID if flash else DARK
    mid = LIGHT if flash else MID
    _boots(d, facing, walk_phase, dark)
    _sheathed_sword(d, facing, bob)
    _cloak(d, facing, bob, dark, mid, LIGHT)
    _hood(d, facing, bob, dark, mid, LIGHT)
    if facing != "up":
        _relic_gem(d, facing, bob, gem_bright)
        if facing == "down":
            d.rectangle((14, 15 + bob, 17, 16 + bob), fill=MAGENTA)
    return image


def _shadow(d: ImageDraw.ImageDraw, box: tuple[int, int, int, int] = (10, 25, 21, 28)) -> None:
    d.ellipse(box, fill=SHADOW)


def _offset(image: Image.Image, dx: int, dy: int) -> Image.Image:
    # The figure never reaches the canvas border, so a wrapping shift is a pure translation.
    return ImageChops.offset(image, dx, dy)


def _dash(canvas: Image.Image, d: ImageDraw.ImageDraw, facing: str, phase: int) -> None:
    vec = DASH_VECTOR[facing]
    lean = (2, 3, 2, 1)[phase]
    length = (10, 8, 5, 3)[phase]
    if facing == "side":
        for row, y in enumerate((14, 17, 20)):
            tail = 12 - length + row
            d.line((max(1, tail), y, 9, y), fill=LIGHT if row == 1 else MID, width=1)
    elif facing == "down":
        for column, x in enumerate((12, 15, 18)):
            head = 6 - lean
            d.line((x, max(1, head - length + column), x, head), fill=LIGHT if column == 1 else MID, width=1)
    else:
        for column, x in enumerate((12, 15, 18)):
            tail = 26 + lean
            d.line((x, tail, x, min(30, tail + length - column)), fill=LIGHT if column == 1 else MID, width=1)
    canvas.alpha_composite(_offset(figure(facing), vec[0] * lean, vec[1] * lean))


def _sword(d: ImageDraw.ImageDraw, hilt: tuple[int, int], tip: tuple[int, int]) -> None:
    d.line((hilt[0], hilt[1], tip[0], tip[1]), fill=STEEL, width=2)
    d.rectangle((tip[0], tip[1], tip[0] + 1, tip[1]), fill=LIGHT)
    d.rectangle((hilt[0] - 1, hilt[1] - 1, hilt[0] + 1, hilt[1] + 1), fill=HILT)


def _melee(canvas: Image.Image, d: ImageDraw.ImageDraw, facing: str, phase: int) -> None:
    vec = DASH_VECTOR[facing]
    lunge = (0, 1, 2, 1)[phase]
    canvas.alpha_composite(_offset(figure(facing), vec[0] * lunge, vec[1] * lunge))
    if facing == "side":
        if phase == 0:
            _sword(d, (17, 14), (11, 5))
        elif phase == 1:
            _sword(d, (18, 14), (24, 6))
        elif phase == 2:
            # Contact frame (manifest f3): blade extended with the full arc flash.
            d.arc((8, 4, 30, 28), start=-70, end=55, fill=LIGHT, width=2)
            _sword(d, (19, 15), (28, 13))
        else:
            d.arc((10, 6, 28, 26), start=15, end=55, fill=MID, width=1)
            _sword(d, (18, 17), (25, 24))
    elif facing == "down":
        if phase == 0:
            _sword(d, (20, 15), (26, 7))
        elif phase == 1:
            _sword(d, (21, 17), (29, 15))
        elif phase == 2:
            d.arc((6, 10, 26, 30), start=20, end=160, fill=LIGHT, width=2)
            _sword(d, (20, 19), (26, 27))
        else:
            d.arc((8, 12, 24, 28), start=100, end=160, fill=MID, width=1)
            _sword(d, (19, 19), (21, 27))
    else:
        if phase == 0:
            _sword(d, (11, 16), (5, 24))
        elif phase == 1:
            _sword(d, (10, 14), (3, 15))
        elif phase == 2:
            d.arc((4, 0, 28, 20), start=180, end=330, fill=LIGHT, width=2)
            _sword(d, (11, 12), (8, 3))
        else:
            d.arc((6, 2, 26, 18), start=280, end=330, fill=MID, width=1)
            _sword(d, (13, 11), (18, 4))


def _relic_cast(canvas: Image.Image, d: ImageDraw.ImageDraw, facing: str, phase: int) -> None:
    cast = {"down": (16, 24), "up": (16, 6), "side": (25, 16)}[facing]
    canvas.alpha_composite(figure(facing, gem_bright=phase < 2))
    x, y = cast
    if phase == 0:
        d.rectangle((x - 1, y - 1, x, y), fill=CYAN_DEEP)
    elif phase == 1:
        d.ellipse((x - 4, y - 4, x + 3, y + 3), outline=CYAN, width=1)
        d.rectangle((x - 1, y - 1, x, y), fill=CYAN_GLOW)
        for dx, dy in ((-6, 0), (5, 0), (0, -6), (0, 5)):
            d.rectangle((x + dx, y + dy, x + dx + 1, y + dy), fill=CYAN)
    else:
        for dx, dy in ((-4, -4), (3, -4), (-4, 3), (3, 3)):
            d.rectangle((x + dx, y + dy, x + dx, y + dy + 1), fill=CYAN_DEEP)
        d.rectangle((x - 1, y - 1, x, y), fill=CYAN)


def _death(canvas: Image.Image, d: ImageDraw.ImageDraw, phase: int) -> None:
    if phase == 0:
        _shadow(d)
        canvas.alpha_composite(figure("down", flash=True))
        return
    if phase == 1:
        _shadow(d)
        canvas.alpha_composite(_offset(figure("down"), 0, 2))
        return
    if phase == 2:
        _shadow(d)
        d.polygon([(9, 18), (22, 18), (23, 25), (8, 25)], fill=DARK)
        d.polygon([(10, 19), (21, 19), (22, 24), (9, 24)], fill=MID)
        d.ellipse((11, 10, 20, 18), fill=DARK)
        d.rectangle((13, 13, 18, 15), fill=LIGHT)
        d.rectangle((14, 14, 17, 14), fill=DARK)
        return
    _shadow(d, (6, 25, 25, 28))
    if phase == 3:
        d.polygon([(7, 20), (24, 20), (25, 25), (6, 25)], fill=DARK)
        d.rectangle((9, 21, 21, 24), fill=MID)
        d.ellipse((20, 17, 26, 23), fill=DARK)
        d.rectangle((22, 19, 23, 20), fill=LIGHT)
        d.rectangle((12, 22, 13, 23), fill=CYAN)
        return
    if phase == 4:
        d.polygon([(6, 22), (25, 22), (26, 26), (5, 26)], fill=DARK)
        d.rectangle((8, 23, 23, 25), fill=DEATH)
        d.rectangle((12, 23, 13, 24), fill=CYAN_DEEP)
        return
    # Final frame holds inside the shared death tint (visual bible §8).
    d.polygon([(6, 23), (25, 23), (26, 26), (5, 26)], fill=DEATH)
    d.rectangle((12, 24, 13, 24), fill=CYAN_DEEP)


def render(name: str, phase: int) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME, FRAME), TRANSPARENT)
    d = ImageDraw.Draw(canvas)
    state, _, facing = name.rpartition("_")
    if facing not in ("down", "up", "side"):
        state, facing = name, "down"
    if state == "death":
        _death(canvas, d, phase)
        return canvas
    _shadow(d)
    if state == "idle":
        canvas.alpha_composite(figure(facing, bob=IDLE_BOB[phase], gem_bright=phase == 2))
    elif state == "walk":
        canvas.alpha_composite(figure(facing, bob=WALK_BOB[phase], walk_phase=phase))
    elif state == "dash":
        _dash(canvas, d, facing, phase)
    elif state == "attack_melee":
        _melee(canvas, d, facing, phase)
    elif state == "attack_relic":
        _relic_cast(canvas, d, facing, phase)
    else:
        canvas.alpha_composite(_offset(figure("down", flash=phase == 0), -1 if phase == 0 else 0, 0))
    return canvas


def write_frames(specs: dict[str, tuple[int, bool, float]]) -> None:
    subresources: list[str] = []
    animations: list[str] = []
    for row, name in enumerate(ROW_ORDER):
        count, loop, speed = specs[name]
        frames: list[str] = []
        for column in range(count):
            identifier = f"AtlasTexture_{name}_{column}"
            subresources.append(
                f'[sub_resource type="AtlasTexture" id="{identifier}"]\n'
                'atlas = ExtResource("1_sheet")\n'
                f"region = Rect2({column * FRAME}, {row * FRAME}, {FRAME}, {FRAME})\n"
            )
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % identifier)
        animations.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (", ".join(frames), "true" if loop else "false", name, speed)
        )
    (player_dir / "player_frames.tres").write_text(
        f'[gd_resource type="SpriteFrames" load_steps={len(subresources) + 2} format=3]\n\n'
        '[ext_resource type="Texture2D" path="res://assets/sprites/player/player.png" id="1_sheet"]\n\n'
        + "\n".join(subresources) + "\n[resource]\nanimations = [" + ", ".join(animations) + "]\n",
        encoding="utf-8",
    )


def build() -> None:
    specs = animation_spec()
    sheet = Image.new("RGBA", (COLUMNS * FRAME, len(ROW_ORDER) * FRAME), TRANSPARENT)
    for row, name in enumerate(ROW_ORDER):
        count, _, _ = specs[name]
        for column in range(count):
            sheet.alpha_composite(render(name, column), (column * FRAME, row * FRAME))
    sheet.save(player_dir / "player.png")
    write_frames(specs)


if __name__ == "__main__":
    player_dir.mkdir(parents=True, exist_ok=True)
    build()
