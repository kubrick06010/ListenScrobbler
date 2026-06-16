#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Resources" / "Assets.xcassets"
APPICON = ASSETS / "AppIcon.appiconset"
LISTENBRAINZ_LOGOS = (
    ROOT
    / ".references"
    / "metabrainz-design-system"
    / "brand"
    / "logos"
    / "ListenBrainz"
    / "PNG"
)
LISTENBRAINZ_MONOCHROME = (
    ROOT
    / ".references"
    / "metabrainz-design-system"
    / "brand"
    / "logos"
    / "ListenBrainz"
    / "monochrome"
)

LB_CREAM = (255, 254, 219, 255)


def require_logo(filename: str) -> Path:
    path = LISTENBRAINZ_LOGOS / filename
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {path}. Clone https://github.com/metabrainz/design-system "
            "to .references/metabrainz-design-system before regenerating icons."
        )
    return path


def require_monochrome_logo(filename: str) -> Path:
    path = LISTENBRAINZ_MONOCHROME / filename
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {path}. Clone https://github.com/metabrainz/design-system "
            "to .references/metabrainz-design-system before regenerating icons."
        )
    return path


def render_logo(
    filename: str,
    size: int,
    padding: float = 0.0,
    opaque_background: tuple[int, int, int, int] | None = None,
) -> Image.Image:
    source = Image.open(require_logo(filename)).convert("RGBA")
    canvas = Image.new("RGBA", (size, size), opaque_background or (0, 0, 0, 0))
    target = round(size * (1.0 - padding * 2.0))
    scale = min(target / source.width, target / source.height)
    resized_size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    source = source.resize(resized_size, Image.Resampling.LANCZOS)
    origin = ((size - source.width) // 2, (size - source.height) // 2)
    canvas.alpha_composite(source, origin)
    if opaque_background is not None:
        canvas.putalpha(255)
    return canvas


def render_monochrome_template(filename: str, size: int, padding: float = 0.0) -> Image.Image:
    source = Image.open(require_monochrome_logo(filename)).convert("RGBA")
    target = round(size * (1.0 - padding * 2.0))
    scale = min(target / source.width, target / source.height)
    resized_size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    source = source.resize(resized_size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = ((size - source.width) // 2, (size - source.height) // 2)
    canvas.alpha_composite(source, origin)
    return canvas


def write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def generate_app_icons() -> None:
    mac = [
        ("16x16", "1x", "icon_16x16.png", 16),
        ("16x16", "2x", "icon_16x16@2x.png", 32),
        ("32x32", "1x", "icon_32x32.png", 32),
        ("32x32", "2x", "icon_32x32@2x.png", 64),
        ("128x128", "1x", "icon_128x128.png", 128),
        ("128x128", "2x", "icon_128x128@2x.png", 256),
        ("256x256", "1x", "icon_256x256.png", 256),
        ("256x256", "2x", "icon_256x256@2x.png", 512),
        ("512x512", "1x", "icon_512x512.png", 512),
        ("512x512", "2x", "icon_512x512@2x.png", 1024),
    ]
    ios = [
        ("iphone", "20x20", "2x", "ios_20@2x.png", 40),
        ("iphone", "20x20", "3x", "ios_20@3x.png", 60),
        ("iphone", "29x29", "2x", "ios_29@2x.png", 58),
        ("iphone", "29x29", "3x", "ios_29@3x.png", 87),
        ("iphone", "40x40", "2x", "ios_40@2x.png", 80),
        ("iphone", "40x40", "3x", "ios_40@3x.png", 120),
        ("iphone", "60x60", "2x", "ios_60@2x.png", 120),
        ("iphone", "60x60", "3x", "ios_60@3x.png", 180),
        ("ipad", "20x20", "1x", "ipad_20.png", 20),
        ("ipad", "20x20", "2x", "ipad_20@2x.png", 40),
        ("ipad", "29x29", "1x", "ipad_29.png", 29),
        ("ipad", "29x29", "2x", "ipad_29@2x.png", 58),
        ("ipad", "40x40", "1x", "ipad_40.png", 40),
        ("ipad", "40x40", "2x", "ipad_40@2x.png", 80),
        ("ipad", "76x76", "2x", "ipad_76@2x.png", 152),
        ("ipad", "83.5x83.5", "2x", "ipad_83_5@2x.png", 167),
        ("ios-marketing", "1024x1024", "1x", "ios_marketing_1024.png", 1024),
    ]

    images = []
    for size_name, scale, filename, pixels in mac:
        write_png(APPICON / filename, render_logo("ListenBrainz_logo_square.png", pixels))
        images.append({"idiom": "mac", "size": size_name, "scale": scale, "filename": filename})
    for idiom, size_name, scale, filename, pixels in ios:
        write_png(
            APPICON / filename,
            render_logo("ListenBrainz_logo_square.png", pixels, opaque_background=LB_CREAM),
        )
        images.append({"idiom": idiom, "size": size_name, "scale": scale, "filename": filename})

    write_json(APPICON / "Contents.json", {"images": images, "info": {"author": "xcode", "version": 1}})


def generate_symbols() -> None:
    variants = {
        "ListenPulse": ("ListenBrainz_logo_no_text.png", 0.04),
        "OpenGraph": ("ListenBrainz_logo_square.png", 0.0),
        "LibraryScan": ("ListenBrainz_logo_no_text.png", 0.04),
        "DiscoveryRadio": ("ListenBrainz_logo_short_vertical.png", 0.04),
    }
    for kind, (logo, padding) in variants.items():
        folder = ASSETS / f"{kind}.imageset"
        images = []
        for scale, pixels in [("1x", 64), ("2x", 128), ("3x", 192)]:
            filename = f"{kind.lower()}@{scale}.png".replace("@1x", "")
            write_png(folder / filename, render_logo(logo, pixels, padding=padding))
            images.append({"idiom": "universal", "scale": scale, "filename": filename})
        write_json(folder / "Contents.json", {"images": images, "info": {"author": "xcode", "version": 1}})


def generate_macos_menu_bar_icon() -> None:
    folder = ASSETS / "MenuBarScrobbler.imageset"
    # The macOS menu bar mark is a hand-tuned 18px/36px template bitmap. The
    # upstream ListenBrainz monochrome logo rasterizes into the older filled
    # hex mark at menu-bar sizes, so preserve the checked-in tuned assets when
    # regenerating the broader icon set.
    existing = [
        folder / "menu_bar_scrobbler.png",
        folder / "menu_bar_scrobbler@2x.png",
    ]
    if all(path.exists() for path in existing):
        write_json(
            folder / "Contents.json",
            {
                "images": [
                    {"idiom": "mac", "scale": "1x", "filename": "menu_bar_scrobbler.png"},
                    {"idiom": "mac", "scale": "2x", "filename": "menu_bar_scrobbler@2x.png"},
                ],
                "info": {"author": "xcode", "version": 1},
                "properties": {"template-rendering-intent": "template"},
            },
        )
        return

    images = []
    for scale, pixels in [("1x", 18), ("2x", 36)]:
        filename = f"menu_bar_scrobbler@{scale}.png".replace("@1x", "")
        write_png(folder / filename, render_monochrome_template("ListenBrainz_logo_icon_bw.png", pixels))
        images.append({"idiom": "mac", "scale": scale, "filename": filename})
    write_json(
        folder / "Contents.json",
        {
            "images": images,
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "template"},
        },
    )


def main() -> None:
    generate_app_icons()
    generate_symbols()
    generate_macos_menu_bar_icon()


if __name__ == "__main__":
    main()
