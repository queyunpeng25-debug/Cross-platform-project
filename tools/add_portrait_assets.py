from pathlib import Path
import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'app/assets/portraits'
OUT.mkdir(parents=True, exist_ok=True)

items = [
    ('erkki_oja', r'C:\Users\25733\AppData\Local\Temp\codex-clipboard-fd6906b6-a1e5-4830-9dc5-b5a5bdc7f77c.jpg',
     [[125, 218], [985, 216], [988, 1365], [126, 1368]]),
    ('hans_andersin', r'C:\Users\25733\AppData\Local\Temp\codex-clipboard-cca56c76-6f0e-4b18-b1b9-5dc3cfe5aa86.jpg',
     [[420, 500], [5250, 500], [5200, 3830], [430, 3830]]),
    ('teuvo_kohonen', r'C:\Users\25733\AppData\Local\Temp\codex-clipboard-b11bede5-f2e3-4211-b0e6-b813a9f58e4b.jpg',
     [[690, 455], [5020, 435], [5050, 3990], [680, 4000]]),
]

for name, source, corners in items:
    image = cv2.imdecode(np.fromfile(source, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise FileNotFoundError(source)
    src = np.float32(corners)
    target = np.float32([[0, 0], [799, 0], [799, 999], [0, 999]])
    result = cv2.warpPerspective(image, cv2.getPerspectiveTransform(src, target), (800, 1000))
    cv2.imwrite(str(OUT / f'{name}.jpg'), result, [cv2.IMWRITE_JPEG_QUALITY, 95])
    print(name, image.shape[:2], '->', result.shape[:2])
