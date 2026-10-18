"""Encoded video integrity and optional codec reference checks; no game simulation."""

from pathlib import Path
import copy
import importlib.util
import shutil
import tempfile
import unittest


MOD = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tms_decoded_assets", MOD / "tools/generate_decoded_clip.py")
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class DecodedClipAssets(unittest.TestCase):
    def read_data(self):
        return generator.parse_data((MOD / generator.DATA).read_text(encoding="utf-8"))

    def copy_assets(self, root):
        for name in (generator.SOURCE, generator.DATA):
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(MOD / name, target)

    def test_packet_metadata_and_bounded_keyframes(self):
        self.assertEqual(generator.validate_assets(), [generator.DATA])
        _, frames = self.read_data()
        self.assertEqual(len(frames), 60)
        self.assertEqual([index for index, frame in enumerate(frames) if frame["keyframe"]],
                         [0, 10, 20, 30, 40, 50])
        self.assertEqual(len({frame["rgbSha256"] for frame in frames}), 60)
        self.assertTrue(any(len(frame["hex"]) < len(frames[0]["hex"]) for frame in frames[1:10]),
                        "Delta frames must retain their actual encoded packet form")

    def test_stale_source_and_missing_assets_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix="tms_decoded_assets_") as temporary:
            root = Path(temporary)
            self.copy_assets(root)
            generator.validate_assets(root)
            source = root / generator.SOURCE
            original = source.read_bytes()
            source.write_bytes(original + b"changed")
            with self.assertRaisesRegex(ValueError, "source changed"):
                generator.validate_assets(root)
            source.write_bytes(original)
            (root / generator.DATA).unlink()
            with self.assertRaisesRegex(ValueError, "Missing or unsafe"):
                generator.validate_assets(root)

    def test_modified_packet_and_reference_hashes_are_rejected(self):
        original = (MOD / generator.DATA).read_text(encoding="utf-8")
        _, frames = self.read_data()
        packet = frames[0]["hex"]
        changed_packet = packet[:-2] + ("00" if packet[-2:] != "00" else "01")
        with self.assertRaisesRegex(ValueError, "metadata changed"):
            generator.parse_data(original.replace(packet, changed_packet, 1))
        reference = frames[0]["rgbSha256"]
        changed_reference = ("1" if reference[0] == "0" else "0") + reference[1:]
        with self.assertRaisesRegex(ValueError, "metadata changed"):
            generator.parse_data(original.replace(reference, changed_reference, 1))
        with self.assertRaisesRegex(ValueError, "metadata changed"):
            generator.parse_data(original.replace("    width = 32,", "    width = 64,"))

    def test_truncation_and_unsafe_keyframe_metadata_are_rejected(self):
        source_hash, frames = self.read_data()
        with self.assertRaisesRegex(ValueError, "60 encoded"):
            generator.parse_data(generator.render_data(source_hash, frames[:-1]))
        changed = copy.deepcopy(frames)
        changed[0]["hex"] = changed[0]["hex"][:-2]
        with self.assertRaisesRegex(ValueError, "length mismatch"):
            generator.parse_data(generator.render_data(source_hash, changed))
        changed = copy.deepcopy(frames)
        changed[10]["keyframe"] = False
        with self.assertRaisesRegex(ValueError, "keyframe interval"):
            generator.parse_data(generator.render_data(source_hash, changed))

    def test_non_data_lua_and_wrong_packet_header_are_rejected(self):
        original = (MOD / generator.DATA).read_text(encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "metadata changed"):
            generator.parse_data(original + "unexpectedFunction()\n")
        source_hash, frames = self.read_data()
        changed = copy.deepcopy(frames)
        packet = bytes.fromhex(changed[0]["hex"])
        changed[0]["hex"] = (packet[:4] + b"\x00\x80" + packet[6:]).hex()
        with self.assertRaisesRegex(ValueError, "header flags"):
            generator.parse_data(generator.render_data(source_hash, changed))

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"),
                         "Optional FFmpeg reference comparison needs development tools")
    def test_encoded_packets_and_decoded_hashes_match_ffmpeg(self):
        _, stored = self.read_data()
        reference = generator.encode_frames(shutil.which("ffmpeg"), shutil.which("ffprobe"),
                                            MOD / generator.SOURCE)
        # Matching the extracted encoded packets establishes that each saved
        # reference hash describes these bytes, not a separate raw-video source.
        self.assertEqual(stored, reference)


if __name__ == "__main__":
    unittest.main()
