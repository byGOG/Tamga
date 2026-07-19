from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SIZE = 1024


def rounded_mask(box, radius):
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def build_logo():
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    box = (92, 92, 932, 932)
    mask = rounded_mask(box, 245)

    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_mask = mask.filter(ImageFilter.GaussianBlur(44))
    shadow.paste((0, 55, 125, 120), (0, 26), shadow_mask)
    canvas.alpha_composite(shadow)

    gradient = Image.new("RGBA", (SIZE, SIZE))
    pixels = gradient.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = min(1.0, max(0.0, (x + y - 130) / 1750.0))
            r = int(5 + (42 - 5) * t)
            g = int(157 + (73 - 157) * t)
            b = int(218 + (197 - 218) * t)
            pixels[x, y] = (r, g, b, 255)
    canvas.paste(gradient, (0, 0), mask)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(box, radius=245, outline=(104, 226, 255, 235), width=18)
    draw.arc((135, 128, 888, 882), 205, 310, fill=(255, 255, 255, 70), width=16)

    # Geometrik T: küçük boyutlarda da harf biçimini korur.
    draw.rounded_rectangle((270, 266, 754, 392), radius=60, fill=(255, 255, 255, 255))
    draw.rounded_rectangle((445, 340, 579, 754), radius=64, fill=(255, 255, 255, 255))
    draw.rounded_rectangle((478, 390, 546, 708), radius=32, fill=(213, 240, 255, 95))

    return canvas.resize((512, 512), Image.Resampling.LANCZOS)


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    logo = build_logo()
    logo.save(ASSETS / "tamga-logo.png", optimize=True)
    logo.save(
        ASSETS / "tamga-logo.ico",
        format="ICO",
        sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
