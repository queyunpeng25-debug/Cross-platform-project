"""Match registered artworks, not human identities. No face recognition."""
import json
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent


def resize(image):
    scale = min(1, 1400 / max(image.shape[:2]))
    return cv2.resize(image, None, fx=scale, fy=scale) if scale < 1 else image


class Recognizer:
    def __init__(self, manifest=ROOT / 'references.json'):
        self.orb = cv2.ORB_create(nfeatures=3500)
        self.matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
        self.references = []
        for entry in json.loads(Path(manifest).read_text(encoding='utf-8')):
            path = Path(manifest).parent / entry['image']
            image = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_GRAYSCALE)
            if image is None:
                raise ValueError(f'Cannot read reference: {path}')
            image = resize(image)
            keypoints, descriptors = self.orb.detectAndCompute(image, None)
            if descriptors is None or len(keypoints) < 30:
                raise ValueError(f'Not enough texture in {path}')
            self.references.append((entry['id'], image.shape, keypoints, descriptors))

    def recognize(self, image):
        image = resize(image)
        points, descriptors = self.orb.detectAndCompute(image, None)
        if descriptors is None or len(points) < 2:
            return {'matched': False, 'reason': 'Not enough image detail'}
        candidates = []
        for identifier, shape, ref_points, ref_descriptors in self.references:
            pairs = self.matcher.knnMatch(ref_descriptors, descriptors, k=2)
            good = [p[0] for p in pairs if len(p) == 2 and p[0].distance < 0.72 * p[1].distance]
            # Prevent many reference points from voting for one scene point.
            good = list({m.trainIdx: m for m in sorted(good, key=lambda m: -m.distance)}.values())
            if len(good) < 16:
                continue
            source = np.float32([ref_points[m.queryIdx].pt for m in good])
            target = np.float32([points[m.trainIdx].pt for m in good])
            matrix, mask = cv2.findHomography(source, target, cv2.RANSAC, 4.0)
            if matrix is None or mask is None:
                continue
            inliers = int(mask.sum())
            ratio = inliers / len(good)
            h, w = shape
            coverage = cv2.contourArea(cv2.convexHull(source[mask.ravel().astype(bool)])) / (w * h)
            corners = np.float32([[0, 0], [w, 0], [w, h], [0, h]]).reshape(-1, 1, 2)
            quad = cv2.perspectiveTransform(corners, matrix)
            area = abs(cv2.contourArea(quad)) / (image.shape[0] * image.shape[1])
            if (inliers >= 14 and ratio >= 0.45 and coverage >= 0.08
                    and np.isfinite(quad).all() and cv2.isContourConvex(quad)
                    and 0.025 <= area <= 1.5):
                candidates.append({'matched': True, 'id': identifier, 'inliers': inliers,
                                   'inlierRatio': round(ratio, 3)})
        candidates.sort(key=lambda item: item['inliers'], reverse=True)
        if not candidates:
            return {'matched': False, 'reason': 'No registered portrait matched'}
        if len(candidates) > 1 and candidates[0]['inliers'] < candidates[1]['inliers'] * 1.25:
            return {'matched': False, 'reason': 'Ambiguous: photograph one portrait at a time'}
        return candidates[0]
