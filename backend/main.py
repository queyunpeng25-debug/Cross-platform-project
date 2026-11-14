"""Local demo service. Uploaded photographs are processed in memory, never saved."""
import os
os.environ.setdefault('OPENCV_IO_MAX_IMAGE_PIXELS', '25000000')

from contextlib import asynccontextmanager
from threading import Lock

import cv2
import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from starlette.concurrency import run_in_threadpool

from backend.recognizer import Recognizer

lock = Lock()


@asynccontextmanager
async def lifespan(app):
    app.state.recognizer = Recognizer()
    yield


app = FastAPI(title='CS Guide portrait matcher', lifespan=lifespan)


@app.get('/health')
def health():
    return {'status': 'ok', 'references': len(app.state.recognizer.references)}


def match(data):
    try:
        image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_GRAYSCALE)
    except cv2.error:
        raise HTTPException(400, 'Invalid or oversized image')
    if image is None:
        raise HTTPException(400, 'Cannot decode image; use JPEG or PNG')
    with lock:
        return app.state.recognizer.recognize(image)


@app.post('/recognize')
async def recognize(file: UploadFile = File(...)):
    try:
        data = await file.read(8 * 1024 * 1024 + 1)
        if len(data) > 8 * 1024 * 1024:
            raise HTTPException(413, 'Maximum upload size is 8 MB')
        return await run_in_threadpool(match, data)
    finally:
        await file.close()


