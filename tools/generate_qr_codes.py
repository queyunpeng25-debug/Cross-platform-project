"""Generate printable online HTTPS QR codes for CS Explorer stations.

Works both with `qrcode` (if installed) AND with a built-in zero-dependency
ISO/IEC 18004 pure-Python PNG encoder so any teammate can run:

    python tools/generate_qr_codes.py
    python tools/generate_qr_codes.py --base-url https://queyunpeng25-debug.github.io/Cross-platform-project/
"""
from __future__ import annotations

import argparse
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASE_URL = "https://queyunpeng25-debug.github.io/Cross-platform-project/"

STATIONS = [
    ("lobby", "CS Lobby — Welcome & Building Guide"),
    ("tuas_bridge", "1F Shortcut Sign -> 2F Bridge to TUAS"),
    ("greenhouse", "Learning Hub Greenhouse (1F)"),
    ("guilds", "Student Guild Rooms (1F)"),
    ("locked_corridors", "Locked Corridors, Staff & Labs (1F-2F)"),
    ("study_places", "Secret Study Places (3F)"),
    ("canteen", "Lunch Place & Subway (1F)"),
    ("computers", "Evolution of Computers (2F)"),
    ("portraits", "CS Pioneers Portraits (1F)"),
]

# Single-block EC Level L specifications: version -> (size, total_data_bytes, ec_bytes, align_centers)
_SINGLE_BLOCK_L_VERSIONS = [
    (1, 21, 19, 7, []),
    (2, 25, 34, 10, [6, 18]),
    (3, 29, 55, 15, [6, 22]),
    (4, 33, 80, 20, [6, 26]),
    (5, 37, 108, 26, [6, 30]),
]


def _gf_tables() -> tuple[list[int], list[int]]:
    exp = [0] * 512
    log = [0] * 256
    x = 1
    for i in range(255):
        exp[i] = x
        log[x] = i
        x <<= 1
        if x & 0x100:
            x ^= 0x11D
    for i in range(255, 512):
        exp[i] = exp[i - 255]
    return exp, log


_GF_EXP, _GF_LOG = _gf_tables()


def _gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return _GF_EXP[_GF_LOG[a] + _GF_LOG[b]]


def _rs_generator(degree: int) -> list[int]:
    poly = [1]
    for i in range(degree):
        nxt = [0] * (len(poly) + 1)
        root = _GF_EXP[i]
        for j, c in enumerate(poly):
            nxt[j] ^= c
            nxt[j + 1] ^= _gf_mul(c, root)
        poly = nxt
    return poly


def _rs_encode(data: list[int], ec_len: int) -> list[int]:
    gen = _rs_generator(ec_len)
    rem = [0] * ec_len
    for b in data:
        factor = b ^ rem[0]
        rem = rem[1:] + [0]
        for i in range(ec_len):
            rem[i] ^= _gf_mul(gen[i + 1], factor)
    return rem


def _format_bits_level_l(mask_id: int) -> int:
    # EC Level L = 01, mask = 3 bits
    data = (0b01 << 3) | mask_id
    rem = data << 10
    for i in range(4, -1, -1):
        if rem & (1 << (i + 10)):
            rem ^= 0b10100110111 << i
    return ((data << 10) | rem) ^ 0b101010000010010


def _encode_qr_matrix(payload: bytes) -> list[list[int]]:
    for _ver, size, data_cap, ec_len, align in _SINGLE_BLOCK_L_VERSIONS:
        if len(payload) + 2 <= data_cap:
            break
    else:
        raise ValueError(f"URL too long ({len(payload)} bytes) for built-in V5-L encoder; install 'qrcode'.")

    bits: list[int] = [0, 1, 0, 0]  # Byte mode (0100)
    for shift in range(7, -1, -1):
        bits.append((len(payload) >> shift) & 1)
    for byte in payload:
        for shift in range(7, -1, -1):
            bits.append((byte >> shift) & 1)
    bits.extend([0] * min(4, data_cap * 8 - len(bits)))
    while len(bits) % 8 != 0:
        bits.append(0)
    codewords = [
        sum(bits[i + k] << (7 - k) for k in range(8))
        for i in range(0, len(bits), 8)
    ]
    pads = [0xEC, 0x11]
    idx = 0
    while len(codewords) < data_cap:
        codewords.append(pads[idx % 2])
        idx += 1

    all_words = codewords + _rs_encode(codewords, ec_len)
    stream = [(w >> s) & 1 for w in all_words for s in range(7, -1, -1)]

    grid: list[list[int | None]] = [[None] * size for _ in range(size)]
    reserved = [[False] * size for _ in range(size)]

    def set_fn(r: int, c: int, val: int) -> None:
        if 0 <= r < size and 0 <= c < size:
            grid[r][c] = val
            reserved[r][c] = True

    def place_finder(top: int, left: int) -> None:
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                on_border = dr in (-1, 7) or dc in (-1, 7)
                in_outer = dr in (0, 6) or dc in (0, 6)
                in_inner = 2 <= dr <= 4 and 2 <= dc <= 4
                val = 0 if on_border else (1 if (in_outer or in_inner) else 0)
                set_fn(top + dr, left + dc, val)

    place_finder(0, 0)
    place_finder(0, size - 7)
    place_finder(size - 7, 0)

    for i in range(8, size - 8):
        if not reserved[6][i]:
            set_fn(6, i, 1 if i % 2 == 0 else 0)
        if not reserved[i][6]:
            set_fn(i, 6, 1 if i % 2 == 0 else 0)

    for ar in align:
        for ac in align:
            if reserved[ar][ac]:
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    val = 1 if (abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0)) else 0
                    set_fn(ar + dr, ac + dc, val)

    # Dark module + reserve format info locations
    set_fn(size - 8, 8, 1)
    for i in range(9):
        if i != 6:
            reserved[8][i] = True
            reserved[i][8] = True
    for i in range(8):
        reserved[8][size - 1 - i] = True
        reserved[size - 1 - i][8] = True

    # Upward/downward 2-column zigzag placement
    bit_idx = 0
    upward = True
    col = size - 1
    while col > 0:
        if col == 6:
            col -= 1
        rows = range(size - 1, -1, -1) if upward else range(size)
        for r in rows:
            for dc in (0, -1):
                c = col + dc
                if not reserved[r][c]:
                    bit = stream[bit_idx] if bit_idx < len(stream) else 0
                    bit_idx += 1
                    # Mask 0: (r + c) % 2 == 0
                    if (r + c) % 2 == 0:
                        bit ^= 1
                    grid[r][c] = bit
        upward = not upward
        col -= 2

    fmt = _format_bits_level_l(0)
    fmt_bits = [(fmt >> i) & 1 for i in range(14, -1, -1)]
    coords_a = [(8, 0), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5), (8, 7), (8, 8),
                (7, 8), (5, 8), (4, 8), (3, 8), (2, 8), (1, 8), (0, 8)]
    coords_b = [(size - 1 - i, 8) for i in range(7)] + [(8, size - 8 + i) for i in range(8)]
    for idx_b, bit in enumerate(fmt_bits):
        ra, ca = coords_a[idx_b]
        rb, cb = coords_b[idx_b]
        grid[ra][ca] = bit
        grid[rb][cb] = bit

    return [[cell or 0 for cell in row] for row in grid]


def _write_png(matrix: list[list[int]], out_path: Path, scale: int = 12, border: int = 4) -> None:
    fg = (30, 45, 39)
    bg = (250, 249, 246)
    n = len(matrix)
    dim = (n + 2 * border) * scale
    raw = bytearray()
    for y in range(dim):
        raw.append(0)  # Filter type 0 (None)
        mr = y // scale - border
        for x in range(dim):
            mc = x // scale - border
            is_dark = 0 <= mr < n and 0 <= mc < n and matrix[mr][mc] == 1
            raw.extend(fg if is_dark else bg)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", dim, dim, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    out_path.write_bytes(png)


def build_station_url(base_url: str, station_id: str) -> str:
    normalized = base_url.rstrip("/") + "/"
    return f"{normalized}?station={station_id}"


def save_qr_image(url: str, out_path: Path) -> None:
    try:
        import qrcode  # type: ignore

        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=12,
            border=4,
        )
        qr.add_data(url)
        qr.make(fit=True)
        qr.make_image(fill_color="#1E2D27", back_color="#FAF9F6").save(out_path)
    except ImportError:
        matrix = _encode_qr_matrix(url.encode("utf-8"))
        _write_png(matrix, out_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate CS Explorer QR codes")
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Public HTTPS URL where the Flutter Web App is hosted (GitHub Pages).",
    )
    args = parser.parse_args()

    out_dir = ROOT / "demo_qr"
    out_dir.mkdir(parents=True, exist_ok=True)

    for station_id, label in STATIONS:
        target_url = build_station_url(args.base_url, station_id)
        file_path = out_dir / f"online_{station_id}.png"
        save_qr_image(target_url, file_path)
        print(f"Generated {file_path.name} -> {target_url} ({label})")


if __name__ == "__main__":
    main()
