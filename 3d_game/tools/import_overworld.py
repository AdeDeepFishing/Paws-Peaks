"""Convert the supplied three-time map into one mesh and shared palette materials.

Usage: python3 3d_game/tools/import_overworld.py /path/to/map-overworld-three-times
Only the Python standard library is required. No network or generation calls.
"""
import copy
import hashlib
import json
from pathlib import Path
import struct
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUTPUT = PROJECT / 'models' / 'overworld'
MODES = ('day', 'sunset', 'night')


def read_glb(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20 + size]), raw[28 + size:]


def floats(document, binary, accessor_index):
    accessor = document['accessors'][accessor_index]
    view = document['bufferViews'][accessor['bufferView']]
    assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC3'
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', 12)
    return [list(struct.unpack_from('<3f', binary, offset + i * stride)) for i in range(accessor['count'])]


def strip_extras(value):
    if isinstance(value, dict):
        value.pop('extras', None)
        for child in value.values():
            strip_extras(child)
    elif isinstance(value, list):
        for child in value:
            strip_extras(child)


def main(source):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / 'textures').mkdir(exist_ok=True)
    (OUTPUT / 'materials').mkdir(exist_ok=True)
    deliveries = {mode: read_glb(source / 'models' / f'overworld-{mode}.glb') for mode in MODES}
    image_paths = {}
    for mode, (document, binary) in deliveries.items():
        image_paths[mode] = []
        for image in document['images']:
            view = document['bufferViews'][image['bufferView']]
            content = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
            assert image['mimeType'] == 'image/png'
            filename = 'textures/' + hashlib.sha256(content).hexdigest()[:20] + '.png'
            (OUTPUT / filename).write_bytes(content)
            image_paths[mode].append(filename)

    document, binary = deliveries['night']
    document = copy.deepcopy(document)
    # The first 34 material slots are identical across all three exports; the
    # night export appends the moon and stars. Validate the mesh/material seam.
    for mode in MODES[:2]:
        other = deliveries[mode][0]
        for a, b in zip(other['meshes'], document['meshes']):
            assert [p['material'] for p in a['primitives']] == [p['material'] for p in b['primitives']]
        assert len(other['materials']) == 34
    for i, material in enumerate(document['materials']):
        material['name'] = f'Palette_{i:02}'
        shader_kind = {'OPAQUE': 'opaque', 'MASK': 'cutout', 'BLEND': 'blend'}[material.get('alphaMode', 'OPAQUE')]
        lines = ['[gd_resource type="ShaderMaterial" load_steps=5 format=3]', '',
                 f'[ext_resource type="Shader" path="res://shaders/overworld/palette_{shader_kind}.gdshader" id="1"]']
        parameters = []
        for j, mode in enumerate(MODES):
            palette_document = deliveries[mode][0]
            palette_mode = mode
            if i >= len(palette_document['materials']):
                palette_document = document
                palette_mode = 'night'
            entry = palette_document['materials'][i]['pbrMetallicRoughness']
            factor = entry.get('baseColorFactor', [1, 1, 1, 1])
            if 'baseColorTexture' in entry:
                texture = palette_document['textures'][entry['baseColorTexture']['index']]
                path = image_paths[palette_mode][texture['source']]
                lines.append(f'[ext_resource type="Texture2D" path="res://models/overworld/{path}" id="{j + 2}"]')
                parameters.append(f'shader_parameter/{mode}_pigment = ExtResource("{j + 2}")')
            parameters.append(f'shader_parameter/{mode}_color = Vector4({", ".join(str(c) for c in factor)})')
        lines += ['', '[resource]', 'shader = ExtResource("1")']
        lines += parameters
        lines += [f'shader_parameter/cutoff = {material.get("alphaCutoff", 0.018 if shader_kind == "blend" else 0.0)}',
                  f'shader_parameter/nocturnal = {str(i >= 34).lower()}']
        (OUTPUT / 'materials' / f'palette_{i:02}.tres').write_text('\n'.join(lines) + '\n')

    # Export exactly the authored ribbon center line, including the safe height
    # over water, rather than approximating the path with a straight-line walk.
    route_node = next(node for node in document['nodes'] if node.get('name') == 'Ochre_Brush_Route')
    primitive = document['meshes'][route_node['mesh']]['primitives'][0]
    route = floats(document, binary, primitive['attributes']['POSITION'])[1::3]
    metadata = json.loads((source / 'scene-metadata.json').read_text())
    data = ['extends RefCounted', '', '## Authored map coordinates, extracted by tools/import_overworld.py.',
            'const STAGES := [']
    for stage in metadata['stages']:
        data.append('\tVector3(%s),' % ', '.join(str(n) for n in stage['position']))
    data += [']', 'const ROUTE := [']
    data += ['\tVector3(%s),' % ', '.join(str(n) for n in point) for point in route]
    data += [']']
    (PROJECT / 'scripts/overworld/route_data.gd').write_text('\n'.join(data) + '\n')

    # Externalize and deduplicate pigments; retain a single copy of the geometry
    # and animations. Repack views so embedded PNG bytes are not shipped twice.
    image_views = {image['bufferView'] for image in document['images']}
    remap, views, packed = {}, [], bytearray()
    for index, view in enumerate(document['bufferViews']):
        if index in image_views:
            continue
        remap[index] = len(views)
        new_view = dict(view, byteOffset=len(packed))
        start = view.get('byteOffset', 0)
        packed.extend(binary[start:start + view['byteLength']])
        packed.extend(b'\0' * (-len(packed) % 4))
        views.append(new_view)
    for accessor in document['accessors']:
        if 'bufferView' in accessor:
            accessor['bufferView'] = remap[accessor['bufferView']]
        for part in accessor.get('sparse', {}).values():
            if isinstance(part, dict) and 'bufferView' in part:
                part['bufferView'] = remap[part['bufferView']]
    document['bufferViews'] = views
    document['buffers'] = [{'byteLength': len(packed)}]
    document['images'] = [{'uri': path} for path in image_paths['night']]
    strip_extras(document)
    encoded = json.dumps(document, ensure_ascii=True, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 28 + len(encoded) + len(packed))
    out += struct.pack('<II', len(encoded), 0x4E4F534A) + encoded
    out += struct.pack('<II', len(packed), 0x004E4942) + packed
    (OUTPUT / 'overworld.glb').write_bytes(out)
    provenance = PROJECT.parent / 'docs/3d_game/assets/overworld'
    (provenance / 'scene-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (provenance / 'THREE-LICENSE.txt').write_bytes((source / 'vendor/THREE-LICENSE.txt').read_bytes())
    print(f'Converted {len(document["meshes"])} meshes, {len(document["materials"])} palette materials, {len(route)} route samples.')
    print(f'Unique pigments: {len(list((OUTPUT / "textures").glob("*.png")))}; geometry: {len(out) / 1048576:.1f} MiB.')


if __name__ == '__main__':
    main(Path(sys.argv[1]).expanduser())
