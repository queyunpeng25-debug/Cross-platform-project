"""Prepare reference from the supplied photo and printable QR codes."""
import sys
from pathlib import Path
import cv2
import numpy as np
import qrcode

root = Path(__file__).resolve().parents[1]
if len(sys.argv) > 1:
    image = cv2.imdecode(np.fromfile(sys.argv[1], dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError('Cannot read source photograph')
    # Coordinates normalized to the supplied 1153 x 2048 image.
    # Rectify only the artwork; exclude wall, frame and nameplate.
    source = np.float32([[160/1153, 255/2048], [977/1153, 280/2048],
                        [1009/1153, 1254/2048], [168/1153, 1280/2048]])
    source *= np.float32([image.shape[1], image.shape[0]])
    target = np.float32([[0, 0], [799, 0], [799, 999], [0, 999]])
    result = cv2.warpPerspective(image, cv2.getPerspectiveTransform(source, target), (800, 1000))
    folder = root / 'backend/references'
    folder.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(folder / 'kaisa_nyberg.jpg'), result)

folder = root / 'demo_qr'
folder.mkdir(exist_ok=True)
for name in ['computers', 'portrait_kaisa', 'unknown']:
    qrcode.make(f'cs-guide://point/{name}').save(folder / f'{name}.png')
print('Prepared references / demo QR codes')
