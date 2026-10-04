"""Generate our own short audiovisual decoder probes. Requires FFmpeg at build time."""
from pathlib import Path
import argparse
import shutil
import subprocess

MOD = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    args = parser.parse_args()
    if not args.ffmpeg:
        parser.error("FFmpeg not found; pass --ffmpeg /path/to/ffmpeg")
    destination = MOD / "assets" / "media"
    destination.mkdir(parents=True, exist_ok=True)
    common = [args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
              "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30:duration=6",
              "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=6",
              "-af", "volume=0.1,afade=t=out:st=5:d=1", "-pix_fmt", "yuv420p", "-shortest",
              "-map_metadata", "-1"]
    formats = {
        "ogv": ["-c:v", "libtheora", "-q:v", "5", "-c:a", "libvorbis", "-q:a", "2"],
        "mp4": ["-c:v", "libx264", "-preset", "fast", "-crf", "28", "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart"],
        "webm": ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "38", "-c:a", "libopus", "-b:a", "48k"],
    }
    for extension, options in formats.items():
        path = destination / ("test." + extension)
        subprocess.run(common + options + [str(path)], check=True)
        print(f"Generated {path.name}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
