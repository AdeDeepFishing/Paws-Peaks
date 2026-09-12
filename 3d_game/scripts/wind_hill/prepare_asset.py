"""Restore the delivery's blank embedded GLB images from its original PNGs.

Run before Godot import. Geometry, materials, camera and animation stay unchanged.
"""

import argparse
import json
from pathlib import Path
import struct


def prepare(source: Path, textures: Path, output: Path) -> None:
    raw = source.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or length != len(raw):
        raise ValueError("Expected a valid glTF 2.0 binary")
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    if json_type != 0x4E4F534A:
        raise ValueError("Missing JSON chunk")
    data = json.loads(raw[20:20 + json_length])
    offset = 20 + json_length
    bin_length, bin_type = struct.unpack_from("<II", raw, offset)
    if bin_type != 0x004E4942:
        raise ValueError("Missing binary chunk")
    binary = bytearray(raw[offset + 8:offset + 8 + bin_length])
    restored = set()
    for texture in data["textures"]:
        index = texture["source"]
        if index in restored:
            continue
        name = texture["name"]
        if Path(name).name != name:
            raise ValueError("Texture names must be local basenames")
        png = (textures / (name + ".png")).read_bytes()
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("Expected a PNG texture")
        binary.extend(b"\0" * (-len(binary) % 4))
        view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(png)}
        data["images"][index] = {
            "name": name,
            "mimeType": "image/png",
            "bufferView": len(data["bufferViews"]),
        }
        data["bufferViews"].append(view)
        binary.extend(png)
        restored.add(index)
    if len(restored) != len(data["images"]):
        raise ValueError("Some embedded images have no named replacement")
    data["buffers"][0]["byteLength"] = len(binary)
    binary.extend(b"\0" * (-len(binary) % 4))
    encoded = json.dumps(data, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    result = struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(binary))
    result += struct.pack("<II", len(encoded), json_type) + encoded
    result += struct.pack("<II", len(binary), bin_type) + binary
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(result)
    print(f"Restored {len(restored)} embedded textures: {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--textures", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.source, args.textures, args.output)
