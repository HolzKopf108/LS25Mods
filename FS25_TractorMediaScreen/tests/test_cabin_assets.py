"""Cab test-clip integrity checks; no FFmpeg dependency and no game simulation."""

from pathlib import Path
import hashlib
import importlib.util
import shutil
import struct
import tempfile
import unittest


MOD = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tms_cabin_assets", MOD / "tools/generate_cabin_clip.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class CabinClipAssets(unittest.TestCase):
    def test_source_and_frame_metadata(self):
        names = generator.validate_assets()
        self.assertEqual(len(names), 90)
        self.assertEqual(generator.FPS * generator.DURATION, len(names))
        self.assertEqual(len({hashlib.sha256((MOD / name).read_bytes()).digest()
                              for name in names}), 90, "Test video must advance every frame")

    def test_bc1_headers_and_complete_mips(self):
        for name in generator.FRAME_NAMES:
            data = (MOD / name).read_bytes()
            generator.validate_dds(data, name)
            header = struct.unpack("<31I", data[4:128])
            self.assertEqual((header[3], header[2], header[6]), (256, 144, 9))
            self.assertEqual(data[84:88], b"DXT1")

    def test_changed_source_or_frame_rejects_stale_metadata(self):
        with tempfile.TemporaryDirectory(prefix="tms_cabin_check_") as temporary:
            root = Path(temporary)
            for name in (generator.SOURCE, generator.DATA, *generator.FRAME_NAMES):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(MOD / name, target)
            generator.validate_assets(root)
            source = root / generator.SOURCE
            original = source.read_bytes()
            source.write_bytes(original + b"changed")
            with self.assertRaisesRegex(ValueError, "metadata changed"):
                generator.validate_assets(root)
            source.write_bytes(original)
            frame = root / generator.FRAME_NAMES[0]
            content = bytearray(frame.read_bytes())
            content[-1] ^= 1
            frame.write_bytes(content)
            with self.assertRaisesRegex(ValueError, "metadata changed"):
                generator.validate_assets(root)

    def test_missing_frames_and_truncated_dds_are_rejected(self):
        data = (MOD / generator.FRAME_NAMES[0]).read_bytes()
        with self.assertRaisesRegex(ValueError, "Truncated"):
            generator.validate_dds(data[:-1], "truncated.dds")
        with tempfile.TemporaryDirectory(prefix="tms_cabin_missing_") as temporary:
            with self.assertRaisesRegex(ValueError, "incomplete"):
                generator.validate_assets(Path(temporary))


if __name__ == "__main__":
    unittest.main()
