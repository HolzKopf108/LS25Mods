"""Build only the explicit runtime assets and verify each ZIP member against source."""
from pathlib import Path
import hashlib
import zipfile
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
ALLOWED = {
    "scripts": {".lua"},
    "assets": {".i3d", ".dds", ".ogv", ".mp4", ".webm"},
}


def runtime_files(mod=MOD):
    desc = ET.parse(mod / "modDesc.xml").getroot()
    files = {"modDesc.xml", desc.findtext("iconFilename")}
    for directory, extensions in ALLOWED.items():
        for path in (mod / directory).rglob("*"):
            if path.is_file() and path.suffix.lower() in extensions:
                if path.is_symlink() or not path.resolve().is_relative_to(mod.resolve()):
                    raise ValueError(f"Runtime path escapes the mod: {path}")
                files.add(path.relative_to(mod).as_posix())
    entries = [e.attrib["filename"] for e in desc.findall("extraSourceFiles/sourceFile")]
    entries += [e.attrib["filename"] for e in desc.findall("specializations/specialization")]
    for name in entries:
        if name not in files:
            raise ValueError(f"Entrypoint is not packaged: {name}")
    for name in files:
        path = mod / name
        if not path.is_file() or not path.resolve().is_relative_to(mod.resolve()):
            raise ValueError(f"Missing or unsafe runtime file: {name}")
    required = {"assets/monitor/monitor.i3d", "assets/monitor/black.dds",
                "assets/monitor/testPattern.dds", "assets/media/test.ogv",
                "assets/media/test.mp4", "assets/media/test.webm"}
    if not required.issubset(files):
        raise ValueError(f"Run the asset generators first: missing {sorted(required-files)}")
    # The model's file references must stay inside and be included in the ZIP.
    for name in files:
        if name.endswith(".i3d"):
            for entry in ET.parse(mod / name).findall("Files/File"):
                target = (mod / name).parent / entry.attrib["filename"]
                reference = target.resolve().relative_to(mod.resolve()).as_posix()
                if reference not in files:
                    raise ValueError(f"Unpackaged I3D reference: {reference}")
    return sorted(files), desc.findtext("version")


def build(mod=MOD):
    files, version = runtime_files(mod)
    destination = mod / "dist" / (mod.name + ".zip")
    destination.parent.mkdir(exist_ok=True)
    temporary = destination.with_suffix(".zip.tmp")
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name in files:
                info = zipfile.ZipInfo(name, date_time=(2026, 10, 4, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, (mod / name).read_bytes())
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None or archive.namelist() != files:
                raise ValueError("ZIP integrity/member check failed")
            for name in files:
                if archive.read(name) != (mod / name).read_bytes():
                    raise ValueError(f"ZIP/source mismatch: {name}")
            if ET.fromstring(archive.read("modDesc.xml")).findtext("version") != version:
                raise ValueError("ZIP version mismatch")
        temporary.replace(destination)
    finally:
        if temporary.exists():
            temporary.unlink()
    print(f"Built {destination} | v{version} | {len(files)} files | {destination.stat().st_size} bytes")
    print(f"SHA256 {hashlib.sha256(destination.read_bytes()).hexdigest()}")
    return destination


if __name__ == "__main__":
    build()
