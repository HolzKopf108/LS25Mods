"""Build the FS25 zip, including a small code-drawn DDS radio icon (stdlib only)."""
from pathlib import Path
import struct
import zipfile
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]


def make_icon():
    size = 512
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            color = (17, 34 + y // 32, 42)
            # Antenna, radio housing, dial, speaker and volume bars.
            if 130 <= x <= 145 and 85 <= y <= 200:
                color = (231, 239, 222)
            if 78 <= x <= 434 and 180 <= y <= 372:
                color = (231, 239, 222)
            if 92 <= x <= 420 and 194 <= y <= 358:
                color = (27, 56, 62)
            if 114 <= x <= 396 and 215 <= y <= 249:
                color = (199, 224, 147)
            if 248 <= x <= 253 and 211 <= y <= 253:
                color = (243, 184, 57)
            if (x - 361) ** 2 + (y - 304) ** 2 <= 27 ** 2:
                color = (243, 184, 57)
            if 113 <= x <= 288 and any(abs(y - line) <= 3 for line in (276, 294, 312, 330)):
                color = (231, 239, 222)
            for i in range(6):
                if 137 + i * 42 <= x <= 163 + i * 42 and 431 - i * 7 <= y <= 449:
                    color = (243, 184, 57)
            pixels.extend((color[2], color[1], color[0], 255))
    # DDS_HEADER, uncompressed 32-bit BGRA with alpha.
    header = [124, 0x100F, size, size, size * 4, 0, 0] + [0] * 11
    header += [32, 0x41, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000]
    header += [0x1000, 0, 0, 0, 0]
    (MOD / "icon.dds").write_bytes(b"DDS " + struct.pack("<31I", *header) + pixels)


def main():
    make_icon()
    desc = ET.parse(MOD / "modDesc.xml").getroot()
    files = ["modDesc.xml", desc.findtext("iconFilename")]
    files += [e.attrib["filename"] for e in desc.findall("extraSourceFiles/sourceFile")]
    destination = MOD / "dist" / "FS25_RadioVolume.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in files:
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 3, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, (MOD / name).read_bytes())
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert "modDesc.xml" in archive.namelist()
    print(f"Built {destination} ({destination.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
