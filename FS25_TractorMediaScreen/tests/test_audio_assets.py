"""Decode the actual bundled audio when optional FFmpeg tools are available.

These checks measure file contents, not audibility or audio routing in FS25.
Ordinary packaging and playback do not require FFmpeg.
"""
from array import array
from pathlib import Path
import json
import math
import shutil
import subprocess
import sys
import unittest

MOD = Path(__file__).resolve().parents[1]
FFMPEG = shutil.which("ffmpeg")
FFPROBE = shutil.which("ffprobe")


@unittest.skipUnless(FFMPEG and FFPROBE, "Optional FFmpeg/ffprobe not installed")
class BundledAudio(unittest.TestCase):
    def test_audio_duration_and_channels(self):
        for extension, codec in (("ogv", "vorbis"), ("mp4", "aac"), ("webm", "opus")):
            with self.subTest(extension=extension):
                path = MOD / "assets/media" / ("test." + extension)
                command = [FFPROBE, "-v", "error", "-select_streams", "a:0",
                           "-show_entries", "stream=codec_name,sample_rate,channels",
                           "-show_entries", "format=duration", "-of", "json", str(path)]
                data = json.loads(subprocess.run(command, check=True, capture_output=True,
                                                 text=True).stdout)
                self.assertEqual(len(data["streams"]), 1)
                stream = data["streams"][0]
                self.assertEqual(stream["codec_name"], codec)
                self.assertEqual(stream["channels"], 1)
                self.assertEqual(int(stream["sample_rate"]), 48000)
                self.assertAlmostEqual(float(data["format"]["duration"]), 6.0, delta=0.1)

    def test_decoded_audio_has_useful_level_without_clipping(self):
        for extension in ("ogv", "mp4", "webm"):
            with self.subTest(extension=extension):
                path = MOD / "assets/media" / ("test." + extension)
                command = [FFMPEG, "-hide_banner", "-loglevel", "error", "-i", str(path),
                           "-map", "0:a:0", "-vn", "-ac", "1", "-ar", "48000",
                           "-f", "f32le", "pipe:1"]
                samples = array("f", subprocess.run(command, check=True,
                                                    capture_output=True).stdout)
                if sys.byteorder != "little":
                    samples.byteswap()
                self.assertGreater(len(samples), 48000 * 5.9)
                self.assertTrue(all(math.isfinite(sample) for sample in samples))
                peak = max(abs(sample) for sample in samples)
                rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
                # The old probe peaked at 0.013 and was inaudible in the user's
                # setup. Keep the new peak near 0.2 with generous codec bounds.
                self.assertGreater(peak, 0.15)
                self.assertLess(peak, 0.30)
                self.assertGreater(rms, 0.09)
                self.assertLess(rms, 0.18)
                opening_rms = math.sqrt(sum(s * s for s in samples[48000:96000]) / 48000)
                ending = samples[-12000:]
                ending_rms = math.sqrt(sum(s * s for s in ending) / len(ending))
                self.assertLess(ending_rms, opening_rms * 0.25, "Retain the ending fade")


if __name__ == "__main__":
    unittest.main()
