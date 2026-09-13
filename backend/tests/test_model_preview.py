import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils.render import render, triangles


class PreviewTests(unittest.TestCase):
    def model(self, folder):
        data = struct.pack('<9f3H', -1, -1, 0, 1, -1, 0, 0, 1, 0, 0, 1, 2) + b'\0\0'
        doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(data)}],
               'bufferViews': [{'buffer': 0, 'byteLength': 36}, {'buffer': 0, 'byteOffset': 36, 'byteLength': 6}],
               'accessors': [{'bufferView': 0, 'componentType': 5126, 'type': 'VEC3', 'count': 3},
                             {'bufferView': 1, 'componentType': 5123, 'type': 'SCALAR', 'count': 3}],
               'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}],
               'nodes': [{'translation': [2, 3, 4], 'children': [1]}, {'mesh': 0, 'scale': [2, 1, 1]}],
               'scenes': [{'nodes': [0]}]}
        raw = json.dumps(doc).encode()
        raw += b' ' * (-len(raw) % 4)
        blob = (struct.pack('<II', len(raw), 0x4e4f534a) + raw
                + struct.pack('<II', len(data), 0x004e4942) + data)
        path = Path(folder) / 'model.glb'
        path.write_bytes(struct.pack('<III', 0x46546c67, 2, len(blob)+12) + blob)
        return path

    def test_geometry_transform_and_real_png(self):
        with tempfile.TemporaryDirectory() as folder:
            model = self.model(folder)
            before = model.read_bytes()
            self.assertEqual(triangles(model)[0], ((0, 2, 4), (4, 2, 4), (2, 4, 4)))
            output = Path(render(model))
            self.assertEqual(output, model.resolve().with_suffix('.png'))
            png = output.read_bytes()
            self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack_from('>II', png, 16), (512, 512))
            offset = 8
            compressed = b''
            while offset < len(png):
                size, kind = struct.unpack_from('>I4s', png, offset)
                data = png[offset+8:offset+8+size]
                self.assertEqual(struct.unpack_from('>I', png, offset+8+size)[0], zlib.crc32(kind+data))
                if kind == b'IDAT':
                    compressed += data
                offset += size+12
            raw = zlib.decompress(compressed)
            self.assertEqual(len(raw), 512*(512*3+1))
            self.assertGreater(len(set(raw)), 4)
            self.assertEqual(model.read_bytes(), before)
            self.assertFalse(output.with_suffix('.png.tmp').exists())
