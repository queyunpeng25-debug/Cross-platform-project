"""Generate printable "You are here" QR stickers for the CS Explorer map.

Each sticker encodes ``<base-url>?map=<marker_id>``. Scanning it with the
map's **Locate me** button moves the "You are here" beacon to that exact spot.
(Station QR codes keep working too; see ``generate_qr_codes.py``.)

The marker ids must match the places with ``hasQrMarker: true`` in
``app/lib/features/map/cs_building_map_data.dart``. The Flutter test
``test/map_feature_test.dart`` fails if a marker has no PNG here.

    python tools/generate_map_qr_codes.py
    python tools/generate_map_qr_codes.py --base-url https://<user>.github.io/<repo>/
"""
from __future__ import annotations

import argparse
from pathlib import Path

from generate_qr_codes import DEFAULT_BASE_URL, save_qr_image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "demo_qr" / "map"

# (marker id, sticker title, where to put the sticker)
MARKERS = [
    ("accessible_entrance_1f", "1F - Accessible entrance (L)", "Inside the north side door (L), next to the door button."),
    ("lift_1f", "1F - Lift", "Next to the lift call button in the main lobby (by the dining line)."),
    ("lift_2f", "2F - Lift", "Next to the lift doors on the 2nd floor."),
    ("lift_3f", "3F - Lift", "Next to the lift doors on the 3rd floor."),
    ("stairs_2f", "2F - Main stairs", "On the wall at the top of the main stairs, 2nd floor."),
    ("stairs_3f", "3F - Main stairs", "On the wall at the top of the main stairs, 3rd floor."),
    ("call_pods_2f", "2F - Call pods", "Beside the glass call pods on the 2nd floor."),
    ("call_pods_3f", "3F - Call pods", "Beside the glass call pods on the 3rd floor."),
    ("skybridge_2f", "2F - Skybridge to TUAS", "At the CS end of the skybridge, by the 'Passage to Maarintie 8' sign."),
]


def build_marker_url(base_url: str, marker_id: str) -> str:
    return base_url.rstrip("/") + f"/?map={marker_id}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate CS Explorer map QR stickers")
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Public HTTPS URL where the Flutter Web App is hosted (GitHub Pages).",
    )
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for marker_id, title, where in MARKERS:
        url = build_marker_url(args.base_url, marker_id)
        file_name = f"map_{marker_id}.png"
        save_qr_image(url, OUT_DIR / file_name)
        rows.append((marker_id, title, where, url, file_name))
        print(f"Generated {file_name} -> {url}")

    lines = [
        "# \"You are here\" map stickers",
        "",
        "Print these and stick them at the spots below. In the app, open **Map** and",
        "tap **Locate me**, then scan a sticker: the map switches to that floor and",
        "moves the red \"You are here\" beacon to the spot. Station QR codes in",
        "`demo_qr/` also work with **Locate me**.",
        "",
        "Regenerate with `python tools/generate_map_qr_codes.py` (add `--base-url` if",
        "the web app moves).",
        "",
        "| Sticker | Where to put it | QR payload | Image |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for _marker_id, title, where, url, file_name in rows:
        lines.append(f"| **{title}** | {where} | `{url}` | ![{title}]({file_name}) |")
    (OUT_DIR / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_DIR / 'README.md'}")


if __name__ == "__main__":
    main()
