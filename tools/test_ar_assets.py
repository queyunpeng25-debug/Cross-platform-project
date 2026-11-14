import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def test_glb_panel_geometry_and_embedded_texture():
    for target in json.loads((ROOT / 'app/assets/ar_targets.json').read_text(encoding='utf-8')):
        data = (ROOT / 'app' / target['panel']).read_bytes()
        magic, version, length = struct.unpack_from('<4sII', data)
        assert (magic, version, length) == (b'glTF', 2, len(data))
        json_length, kind = struct.unpack_from('<I4s', data, 12)
        assert kind == b'JSON'
        doc = json.loads(data[20:20+json_length])
        offset = 20+json_length
        bin_length, kind = struct.unpack_from('<I4s', data, offset)
        assert kind == b'BIN\0'
        binary = data[offset+8:]
        assert len(binary) == bin_length
        for view in doc['bufferViews']:
            assert view['byteOffset'] % 4 == 0
            assert view['byteOffset'] + view['byteLength'] <= len(binary)
        position = doc['bufferViews'][doc['accessors'][0]['bufferView']]
        vertices = struct.unpack_from('<12f', binary, position['byteOffset'])
        assert all(vertices[i] == 0 for i in [1, 4, 7, 10])  # wall plane
        assert min(vertices[::3]) == -.5 and max(vertices[::3]) == .5
        texture = doc['bufferViews'][doc['images'][0]['bufferView']]
        assert binary[texture['byteOffset']:texture['byteOffset']+8] == b'\x89PNG\r\n\x1a\n'
        assert doc['materials'][0]['emissiveTexture']['index'] == 0
        assert (ROOT / 'app' / target['image']).is_file()
