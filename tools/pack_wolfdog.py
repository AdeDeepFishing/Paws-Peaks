"""Pack the six designer clips onto one mesh without duplicating embedded textures."""
import argparse
import copy
import json
from pathlib import Path
import struct


def read_glb(path):
    data = path.read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    return json.loads(data[20:20 + size]), data[28 + size:]


def pack(source, target):
    document, binary = read_glb(source / 'Idel.glb')
    binary = bytearray(binary)
    names = {node['name']: i for i, node in enumerate(document['nodes'])}
    for filename in ['Idel Alert.glb', 'Jump.glb', 'Walk.glb', 'Run.glb', 'RestPose.glb']:
        other, data = read_glb(source / filename)
        accessors, views = {}, {}

        def transfer(index):
            if index in accessors:
                return accessors[index]
            accessor = copy.deepcopy(other['accessors'][index])
            view_index = accessor['bufferView']
            if view_index not in views:
                view = copy.deepcopy(other['bufferViews'][view_index])
                offset = view.get('byteOffset', 0)
                binary.extend(b'\0' * (-len(binary) % 4))
                view['byteOffset'] = len(binary)
                view['buffer'] = 0
                binary.extend(data[offset:offset + view['byteLength']])
                views[view_index] = len(document['bufferViews'])
                document['bufferViews'].append(view)
            accessor['bufferView'] = views[view_index]
            accessors[index] = len(document['accessors'])
            document['accessors'].append(accessor)
            return accessors[index]

        for animation in copy.deepcopy(other['animations']):
            for sampler in animation['samplers']:
                sampler['input'] = transfer(sampler['input'])
                sampler['output'] = transfer(sampler['output'])
            for channel in animation['channels']:
                node = other['nodes'][channel['target']['node']]['name']
                channel['target']['node'] = names[node]
            document['animations'].append(animation)
    binary.extend(b'\0' * (-len(binary) % 4))
    document['buffers'][0]['byteLength'] = len(binary)
    metadata = json.dumps(document, separators=(',', ':')).encode()
    metadata += b' ' * (-len(metadata) % 4)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(struct.pack('<III', 0x46546C67, 2, 28 + len(metadata) + len(binary))
                       + struct.pack('<II', len(metadata), 0x4E4F534A) + metadata
                       + struct.pack('<II', len(binary), 0x004E4942) + binary)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    pack(args.source, args.target)
