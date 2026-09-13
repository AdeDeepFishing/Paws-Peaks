"""Dependency-free clay preview of static, untextured GLB triangle meshes."""
import argparse
import json
import math
from pathlib import Path
import struct
import zlib

MAX_BYTES = 32 * 1024 * 1024
MAX_TRIANGLES = 100000
IDENTITY = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]


def multiply(a, b):
    return [sum(a[k * 4 + row] * b[col * 4 + k] for k in range(4))
            for col in range(4) for row in range(4)]


def transform(node):
    if 'matrix' in node:
        matrix = node['matrix']
        if len(matrix) != 16:
            raise ValueError('Invalid transform')
        return matrix
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    scale = node.get('scale', [1, 1, 1])
    translation = node.get('translation', [0, 0, 0])
    matrix = [1-2*(y*y+z*z), 2*(x*y+z*w), 2*(x*z-y*w), 0,
              2*(x*y-z*w), 1-2*(x*x+z*z), 2*(y*z+x*w), 0,
              2*(x*z+y*w), 2*(y*z-x*w), 1-2*(x*x+y*y), 0,
              *translation, 1]
    for col in range(3):
        for row in range(3):
            matrix[col*4+row] *= scale[col]
    return matrix


def triangles(path):
    path = Path(path)
    if not 20 <= path.stat().st_size <= MAX_BYTES:
        raise ValueError('Invalid GLB size')
    data = path.read_bytes()
    if struct.unpack_from('<III', data) != (0x46546c67, 2, len(data)):
        raise ValueError('Invalid GLB header')
    chunks = {}
    offset = 12
    while offset < len(data):
        size, kind = struct.unpack_from('<II', data, offset)
        offset += 8
        if offset + size > len(data):
            raise ValueError('Invalid GLB chunk')
        chunks[kind] = data[offset:offset+size]
        offset += size
    doc = json.loads(chunks[0x4e4f534a])
    binary = chunks[0x004e4942]
    if doc.get('skins') or doc.get('extensionsRequired'):
        raise ValueError('Unsupported GLB extensions or skinning')
    if len(doc.get('buffers', [])) != 1 or any('uri' in b for b in doc.get('buffers', []) + doc.get('images', [])):
        raise ValueError('Preview requires a self-contained GLB')

    def accessor(index, positions=False):
        acc = doc['accessors'][index]
        if 'sparse' in acc or acc.get('normalized'):
            raise ValueError('Unsupported accessor')
        kind = acc['componentType']
        if positions and (kind != 5126 or acc['type'] != 'VEC3'):
            raise ValueError('Invalid positions')
        if not positions and (kind not in (5121, 5123, 5125) or acc['type'] != 'SCALAR'):
            raise ValueError('Invalid indices')
        fmt = '<' + ('fff' if positions else {5121: 'B', 5123: 'H', 5125: 'I'}[kind])
        width = struct.calcsize(fmt)
        view = doc['bufferViews'][acc['bufferView']]
        if view.get('buffer', 0) != 0:
            raise ValueError('Invalid buffer')
        start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
        stride = view.get('byteStride', width)
        count = acc['count']
        end = start + max(0, count-1)*stride + (width if count else 0)
        if count < 0 or count > MAX_TRIANGLES*3 or stride < width or start < 0 or end > min(len(binary), view.get('byteOffset', 0)+view['byteLength']):
            raise ValueError('Invalid accessor bounds')
        return [struct.unpack_from(fmt, binary, start+i*stride) for i in range(count)]

    result = []
    visited = set()

    def visit(index, parent):
        if index in visited or len(visited) > 10000:
            raise ValueError('Invalid node hierarchy')
        visited.add(index)
        node = doc['nodes'][index]
        matrix = multiply(parent, transform(node))
        if 'mesh' in node:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                if primitive.get('mode', 4) != 4 or primitive.get('targets'):
                    raise ValueError('Preview requires static triangles')
                points = accessor(primitive['attributes']['POSITION'], True)
                points = [tuple(sum(matrix[k*4+r]*p[k] for k in range(3))+matrix[12+r]
                                for r in range(3)) for p in points]
                indices = [v[0] for v in accessor(primitive['indices'])] if 'indices' in primitive else list(range(len(points)))
                if len(indices) % 3 or len(result)+len(indices)//3 > MAX_TRIANGLES:
                    raise ValueError('Invalid triangle count')
                for i in range(0, len(indices), 3):
                    result.append(tuple(points[j] for j in indices[i:i+3]))
        for child in node.get('children', []):
            visit(child, matrix)

    for index in doc['scenes'][doc.get('scene', 0)]['nodes']:
        visit(index, IDENTITY)
    if not result or not all(math.isfinite(v) for tri in result for p in tri for v in p):
        raise ValueError('Empty or invalid geometry')
    return result


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(v):
    length = math.sqrt(dot(v, v))
    return tuple(x/max(length, 1e-12) for x in v)


def rasterize(mesh, size=512):
    """Orthographic, depth-tested, double-sided clay shading on a light background."""
    points = [p for tri in mesh for p in tri]
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    span = [high[i]-low[i] for i in range(3)]
    if max(span) < 1e-9:
        raise ValueError('Degenerate model')
    # Look mostly along the thinnest dimension so flat objects remain readable.
    direction = [0.28, 0.22, 0.28]
    direction[span.index(min(span))] = 1.0
    forward = unit(direction)
    up_hint = (0, 0, -1) if abs(forward[1]) > 0.9 else (0, 1, 0)
    right = unit(cross(up_hint, forward))
    up = cross(forward, right)
    center = [(low[i]+high[i])/2 for i in range(3)]
    def project(p):
        p = [(p[i]-center[i])/max(span) for i in range(3)]
        return (dot(p, right), dot(p, up), dot(p, forward))
    projected = [[project(p) for p in tri] for tri in mesh]
    extent = max(abs(v) for tri in projected for p in tri for v in p[:2])
    scale = size*0.42/max(extent, 1e-9)
    pixels = bytearray([239, 242, 246]) * (size*size)
    depth = [-math.inf] * (size*size)
    light = unit((-0.4, 0.6, 1))
    for tri in projected:
        a, b, c = [(size/2+p[0]*scale, size/2-p[1]*scale, p[2]) for p in tri]
        area = (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
        if abs(area) < 1e-9:
            continue
        normal = unit(cross(tuple(tri[1][i]-tri[0][i] for i in range(3)),
                            tuple(tri[2][i]-tri[0][i] for i in range(3))))
        if normal[2] < 0:
            normal = tuple(-v for v in normal)
        brightness = 0.35+0.65*max(0, dot(normal, light))
        color = bytes(int(channel*brightness) for channel in (116, 155, 185))
        for y in range(max(0, math.floor(min(a[1], b[1], c[1]))), min(size, math.ceil(max(a[1], b[1], c[1])))):
            for x in range(max(0, math.floor(min(a[0], b[0], c[0]))), min(size, math.ceil(max(a[0], b[0], c[0])))):
                u = ((b[0]-x-.5)*(c[1]-y-.5)-(b[1]-y-.5)*(c[0]-x-.5))/area
                v = ((c[0]-x-.5)*(a[1]-y-.5)-(c[1]-y-.5)*(a[0]-x-.5))/area
                w = 1-u-v
                if min(u, v, w) < -1e-9:
                    continue
                z = u*a[2]+v*b[2]+w*c[2]
                index = y*size+x
                if z > depth[index]:
                    depth[index] = z
                    pixels[index*3:index*3+3] = color
    return pixels


def render(model_path):
    """Save model.png atomically beside model.glb; never invoke a provider."""
    model_path = Path(model_path).resolve()
    pixels = rasterize(triangles(model_path))
    size = 512
    raw = b''.join(b'\0'+pixels[y*size*3:(y+1)*size*3] for y in range(size))
    def chunk(kind, data):
        return struct.pack('>I', len(data))+kind+data+struct.pack('>I', zlib.crc32(kind+data))
    png = (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
           +chunk(b'IDAT', zlib.compress(raw))+chunk(b'IEND', b''))
    target = model_path.with_suffix('.png')
    temporary = target.with_suffix('.png.tmp')
    temporary.write_bytes(png)
    temporary.replace(target)
    return str(target)


def preview_result(model_path):
    """Preview errors must not discard successful paid model generation."""
    try:
        return {'preview_path': render(model_path)}
    except (OSError, ValueError, KeyError, IndexError, TypeError, struct.error, RecursionError, OverflowError):
        return {'preview_error': 'PREVIEW_RENDER_FAILED'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('model', type=Path)
    args = parser.parse_args()
    result = preview_result(args.model)
    print(json.dumps(result))
    raise SystemExit(0 if 'preview_path' in result else 1)
