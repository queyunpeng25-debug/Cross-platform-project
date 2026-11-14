"""Generate actual textured 3D information panels from the shared content JSON.
The mesh lies in the image anchor's XZ plane: +X right, +Y outward, -Z up.
No image generation service or remote model downloads are used.
"""
import argparse
import io
import json
from pathlib import Path
import struct

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def make_glb(png):
    binary = bytearray()
    views = []
    def add(data, target=None):
        binary.extend(b'\0' * (-len(binary) % 4))
        view = {'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(data)}
        if target:
            view['target'] = target
        views.append(view)
        binary.extend(data)
        return len(views)-1
    pos = add(struct.pack('<12f', -.5, 0, -.375, -.5, 0, .375, .5, 0, .375, .5, 0, -.375), 34962)
    normals = add(struct.pack('<12f', *([0, 1, 0] * 4)), 34962)
    uv = add(struct.pack('<8f', 0, 0, 0, 1, 1, 1, 1, 0), 34962)
    indices = add(struct.pack('<6H', 0, 1, 2, 0, 2, 3), 34963)
    tex = add(png)
    document = {
        'asset': {'version': '2.0', 'generator': 'CS Explorer panel builder'},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0}],
        'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
        'accessors': [
            {'bufferView': pos, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-.5, 0, -.375], 'max': [.5, 0, .375]},
            {'bufferView': normals, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
            {'bufferView': uv, 'componentType': 5126, 'count': 4, 'type': 'VEC2'},
            {'bufferView': indices, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
        ],
        'materials': [{'doubleSided': True, 'pbrMetallicRoughness': {
            'baseColorFactor': [0, 0, 0, 1], 'metallicFactor': 0, 'roughnessFactor': 1},
            'emissiveFactor': [1, 1, 1], 'emissiveTexture': {'index': 0}}],
        'textures': [{'source': 0, 'sampler': 0}],
        'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}],
        'images': [{'bufferView': tex, 'mimeType': 'image/png'}],
        'bufferViews': views, 'buffers': [{'byteLength': len(binary)}],
    }
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary.extend(b'\0' * (-len(binary) % 4))
    length = 12 + 8 + len(encoded) + 8 + len(binary)
    return struct.pack('<4sII', b'glTF', 2, length) + struct.pack('<I4s', len(encoded), b'JSON') + encoded + struct.pack('<I4s', len(binary), b'BIN\0') + binary


def render(entry, font_path):
    image = Image.new('RGB', (1200, 900), '#f5f5ec')
    draw = ImageDraw.Draw(image)
    def font(size): return ImageFont.truetype(font_path, size)
    draw.rectangle((0, 0, 1200, 18), fill='#a4b58a')
    draw.text((60, 52), 'CS EXPLORER / PORTRAIT STORIES', font=font(25), fill='#57735d')
    draw.text((60, 108), entry['title'], font=font(62), fill='#173e35')
    draw.text((60, 202), entry['subtitle'], font=font(29), fill='#57735d')
    draw.line((60, 260, 1140, 260), fill='#c8d1c1', width=2)
    y = 299
    for text, size, color in [(entry['body'], 34, '#233d36'), (entry['task'], 29, '#57735d')]:
        line = ''
        for char in text:
            if draw.textlength(line + char, font=font(size)) > 1080:
                draw.text((60, y), line, font=font(size), fill=color)
                y += size + 20
                line = ''
            line += char
        if line:
            draw.text((60, y), line, font=font(size), fill=color)
            y += size + 20
        y += 28
    if y > 840:
        raise ValueError(f"Panel content too long: {entry['title']}; shorten its body/task")
    draw.text((60, 849), 'AALTO / COMPUTER SCIENCE', font=font(20), fill='#6e7d6c')
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--font', default='C:/Windows/Fonts/msyh.ttc', help='Font with Chinese glyphs')
    args = parser.parse_args()
    content = json.loads((ROOT / 'app/assets/content.json').read_text(encoding='utf-8'))
    targets = json.loads((ROOT / 'app/assets/ar_targets.json').read_text(encoding='utf-8'))
    for target in targets:
        image = render(content['portraits'][target['id']], args.font)
        output = ROOT / 'app' / target['panel']
        output.parent.mkdir(parents=True, exist_ok=True)
        data = io.BytesIO()
        image.save(data, format='PNG')
        output.write_bytes(make_glb(data.getvalue()))
        image.save(output.with_suffix('.png'))
        print(output)


if __name__ == '__main__':
    main()
