from pathlib import Path
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from backend.main import app
from backend.recognizer import Recognizer

ROOT = Path(__file__).resolve().parent


@pytest.fixture(scope='module')
def recognizer():
    return Recognizer()


def reference():
    return cv2.imread(str(ROOT / 'references/kaisa_nyberg.jpg'), cv2.IMREAD_GRAYSCALE)


def reference_for(identifier):
    return cv2.imread(str(ROOT / f'references/{identifier}.jpg'), cv2.IMREAD_GRAYSCALE)


def test_reference_and_perspective(recognizer):
    image = reference()
    assert recognizer.recognize(image)['id'] == 'kaisa_nyberg'
    h, w = image.shape
    src = np.float32([[0, 0], [w-1, 0], [w-1, h-1], [0, h-1]])
    dst = np.float32([[130, 70], [780, 140], [840, 1080], [60, 1030]])
    transformed = cv2.warpPerspective(image, cv2.getPerspectiveTransform(src, dst), (1000, 1200))
    transformed = cv2.convertScaleAbs(transformed, alpha=0.8, beta=20)
    assert recognizer.recognize(transformed)['id'] == 'kaisa_nyberg'


def test_blank_and_unrelated(recognizer):
    assert not recognizer.recognize(np.full((800, 600), 120, np.uint8))['matched']
    rng = np.random.default_rng(42)
    assert not recognizer.recognize(rng.integers(0, 256, (800, 600), dtype=np.uint8))['matched']


def test_http_contract():
    with TestClient(app) as client:
        assert client.get('/health').json()['references'] == 4
        encoded = cv2.imencode('.jpg', reference())[1].tobytes()
        response = client.post('/recognize', files={'file': ('photo.jpg', encoded, 'image/jpeg')})
        assert response.status_code == 200
        assert response.json()['id'] == 'kaisa_nyberg'
        assert client.post('/recognize', files={'file': ('bad.jpg', b'bad')}).status_code == 400
        assert client.post('/recognize', files={'file': ('big.jpg', b'x' * (8*1024*1024+1))}).status_code == 413
        assert client.post('/recognize').status_code == 422


def test_demo_qr_payloads():
    detector = cv2.QRCodeDetector()
    for name in ['computers', 'portrait_kaisa', 'unknown']:
        image = cv2.imread(str(ROOT.parent / 'demo_qr' / f'{name}.png'))
        text, _, _ = detector.detectAndDecode(image)
        assert text == f'cs-guide://point/{name}'
