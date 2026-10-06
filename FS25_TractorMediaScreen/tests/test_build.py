"""Asset geometry and package regression checks; no game simulation."""
from pathlib import Path
import importlib.util
import math
import struct
import unittest
import xml.etree.ElementTree as ET
import zipfile

MOD = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tms_build", MOD / "tools/build_tractor_media_screen.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class AssetsAndPackage(unittest.TestCase):
    def test_runtime_selection(self):
        files, version = builder.runtime_files()
        self.assertEqual(version, "0.1.2.0")
        self.assertIn("scripts/vehicle/TMSVehicle.lua", files)
        self.assertIn("scripts/media/TMSNativeVideo.lua", files)
        self.assertIn("scripts/media/TMSCabinVideo.lua", files)
        self.assertIn("scripts/media/TMSCabinClipData.lua", files)
        self.assertEqual(len([name for name in files if name.startswith("assets/media/cabinTest/")]), 90)
        self.assertIn("assets/gui/TMSLinkDialog.xml", files)
        self.assertFalse(any(name.startswith(("tests/", "tools/", "dist/")) for name in files))
        self.assertFalse(any(name.endswith((".svg", ".png", ".md", ".py")) for name in files))

    def test_display_geometry_and_faces(self):
        model = ET.parse(MOD / "assets/monitor/monitor.i3d").getroot()
        scene = model.find("Scene/TransformGroup")
        display = scene.find("Shape")
        self.assertEqual(display.get("name"), "display")
        shape = model.find("Shapes/IndexedTriangleSet")
        vertices = [tuple(map(float, v.get("p").split())) for v in shape.find("Vertices")]
        width = max(v[0] for v in vertices) - min(v[0] for v in vertices)
        height = max(v[1] for v in vertices) - min(v[1] for v in vertices)
        self.assertAlmostEqual(width / height, 16 / 9)
        for shape in model.findall("Shapes/IndexedTriangleSet"):
            verts = list(shape.find("Vertices"))
            for triangle in shape.find("Triangles"):
                indices = list(map(int, triangle.get("vi").split()))
                self.assertTrue(all(0 <= i < len(verts) for i in indices))
                a, b, c = [tuple(map(float, verts[i].get("p").split())) for i in indices]
                normal = tuple(map(float, verts[indices[0]].get("n").split()))
                u, v = [b[i]-a[i] for i in range(3)], [c[i]-a[i] for i in range(3)]
                cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
                self.assertGreater(sum(cross[i]*normal[i] for i in range(3)), 0, "Incorrect winding")

    def test_dds_headers_and_mips(self):
        for path in [MOD / "icon.dds", *sorted((MOD / "assets/monitor").glob("*.dds"))]:
            data = path.read_bytes()
            self.assertEqual(data[:4], b"DDS ")
            header = struct.unpack("<31I", data[4:128])
            self.assertEqual(data[84:88], b"DXT1")
            height, width, levels = header[2], header[3], header[6]
            total = 128
            for _ in range(levels):
                total += max(1, math.ceil(width/4))*max(1, math.ceil(height/4))*8
                width, height = max(1, width//2), max(1, height//2)
            self.assertEqual(len(data), total)
            self.assertEqual((width, height), (1, 1))

    def test_zip_exact_source(self):
        target = builder.build()
        files, version = builder.runtime_files()
        with zipfile.ZipFile(target) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(archive.namelist(), files)
            for name in files:
                self.assertEqual(archive.read(name), (MOD / name).read_bytes())
            self.assertEqual(ET.fromstring(archive.read("modDesc.xml")).findtext("version"), version)


if __name__ == "__main__":
    unittest.main()
