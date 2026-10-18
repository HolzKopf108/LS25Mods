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
        self.assertEqual(version, "0.1.9.0")
        self.assertIn("scripts/TMSLog.lua", files)
        desc = ET.parse(MOD / "modDesc.xml").getroot()
        self.assertEqual(desc.find("extraSourceFiles/sourceFile").get("filename"), "scripts/TMSLog.lua")
        self.assertIn("scripts/vehicle/TMSVehicle.lua", files)
        self.assertIn("scripts/media/TMSNativeVideo.lua", files)
        self.assertIn("scripts/media/TMSRuntimeApiReport.lua", files)
        self.assertIn("scripts/media/TMSPixelProbe.lua", files)
        self.assertIn("scripts/media/TMSPixelPip.lua", files)
        self.assertIn("scripts/media/TMSQtrleDecoder.lua", files)
        self.assertIn("scripts/media/TMSDecodedClipData.lua", files)
        self.assertIn("scripts/media/TMSDecodedVideo.lua", files)
        self.assertIn("assets/pixelProbe/pixelsShader.xml", files)
        self.assertIn("assets/pixelProbe/screen.i3d", files)
        self.assertIn("assets/monitor/white.dds", files)
        self.assertIn("scripts/media/TMSCabinVideo.lua", files)
        self.assertIn("scripts/media/TMSCabinClipData.lua", files)
        self.assertEqual(len([name for name in files if name.startswith("assets/media/cabinTest/")]), 90)
        self.assertIn("assets/gui/TMSLinkDialog.xml", files)
        self.assertFalse(any(name.startswith(("tests/", "tools/", "dist/")) for name in files))
        self.assertFalse(any(name.endswith((".svg", ".png", ".md", ".py")) for name in files))
        for name in files:
            if name.startswith("scripts/") and name.endswith(".lua") and name != "scripts/TMSLog.lua":
                self.assertNotRegex((MOD / name).read_text(encoding="utf-8"), r"\bLogging\.(info|warning|error)\s*\(", name)

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

    def test_pixel_pip_white_texture_is_opaque_white_at_every_mip(self):
        data = (MOD / "assets/monitor/white.dds").read_bytes()
        self.assertEqual(data[:4], b"DDS ")
        self.assertEqual(data[84:88], b"DXT1")
        header = struct.unpack("<31I", data[4:128])
        self.assertEqual((header[2], header[3], header[6]), (4, 4, 3))
        # Each 4x4, 2x2 and 1x1 level occupies one complete BC1 block.
        self.assertEqual(len(data), 128 + 3 * 8)
        for level in range(3):
            c0, c1, indices = struct.unpack_from("<HHI", data, 128 + level * 8)
            self.assertGreater(c0, c1, "BC1 must use its opaque four-color mode")
            def rgb565(color):
                return ((color >> 11) * 255 // 31,
                        ((color >> 5) & 63) * 255 // 63, (color & 31) * 255 // 31)
            a, b = rgb565(c0), rgb565(c1)
            palette = (a, b, tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                       tuple((a[i] + 2 * b[i]) // 3 for i in range(3)))
            for pixel in range(16):
                self.assertEqual(palette[(indices >> (pixel * 2)) & 3], (255, 255, 255),
                                 f"Non-white texel at mip {level}, pixel {pixel}")

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
