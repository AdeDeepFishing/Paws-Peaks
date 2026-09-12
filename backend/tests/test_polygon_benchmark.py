import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark_meshy_polygons import triangle_count, benchmark_payload


class PolygonCountTests(unittest.TestCase):
    def test_texture_prompt_enables_texture_with_t2(self):
        payload = benchmark_payload("test-image", "meshy-t2", "hand-drawing style")
        self.assertTrue(payload["should_texture"])
        self.assertEqual(payload["texture_prompt"], "hand-drawing style")
        self.assertEqual(payload["texture_resolution"], "2k")
        self.assertEqual(payload["model_type"], "smart-topology")

    def test_invalid_texture_prompt_rejected(self):
        for prompt in (" ", "a" * 801):
            with self.assertRaises(ValueError):
                benchmark_payload("test-image", "meshy-t2", prompt)

    def test_t2_uses_smart_topology_without_remesh(self):
        payload = benchmark_payload("test-image", "meshy-t2")
        self.assertEqual(payload["model_type"], "smart-topology")
        self.assertEqual(payload["ai_model"], "meshy-t2")
        self.assertFalse(payload["should_texture"])
        self.assertNotIn("should_remesh", payload)
        self.assertNotIn("topology", payload)

    def test_standard_model_keeps_remeshing(self):
        payload = benchmark_payload("test-image", "meshy-6-lite")
        self.assertEqual(payload["model_type"], "standard")
        self.assertTrue(payload["should_remesh"])

    def count(self, primitives, accessors):
        document = {"meshes": [{"primitives": primitives}], "accessors": accessors}
        body = json.dumps(document).encode()
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "sample.glb"
            path.write_bytes(struct.pack("<4sIII4s", b"glTF", 2, 20 + len(body), len(body), b"JSON") + body)
            return triangle_count(path)

    def test_indexed_and_nonindexed_primitives(self):
        self.assertEqual(self.count([
            {"indices": 1, "attributes": {"POSITION": 0}},
            {"attributes": {"POSITION": 2}},
        ], [{"count": 4}, {"count": 6}, {"count": 9}]), 5)

    def test_nontriangle_topology_rejected(self):
        with self.assertRaises(ValueError):
            self.count([{"mode": 1, "attributes": {"POSITION": 0}}], [{"count": 6}])

    def test_incomplete_triangle_rejected(self):
        with self.assertRaises(ValueError):
            self.count([{"attributes": {"POSITION": 0}}], [{"count": 4}])
