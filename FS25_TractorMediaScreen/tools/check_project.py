"""Run Lua 5.1/5.4 tests and optional official XSD validation using Lupa/lxml."""
from pathlib import Path
import argparse
import hashlib
import sys

MOD = Path(__file__).resolve().parents[1]


def verify_decoder_reference(module):
    """Compare real Lua-decoded bytes to FFmpeg reference hashes, without GPU mocks."""
    lua = module.LuaRuntime(encoding=None, unpack_returned_tuples=True)
    for filename in ("TMSQtrleDecoder.lua", "TMSDecodedClipData.lua"):
        lua.globals()[b"SCRIPT"] = (MOD / "scripts/media" / filename).as_posix().encode("utf-8")
        lua.execute(b"dofile(SCRIPT)")
    data = lua.globals()[b"TMSDecodedClipData"]
    decoder = lua.globals()[b"TMSQtrleDecoder"][b"new"](data[b"width"], data[b"height"])
    checks = 0
    # First sequential playback, then independently starting at every keyframe.
    for reset_at_keys in (False, True):
        decoder[b"reset"](decoder)
        for index in range(1, len(data[b"frames"]) + 1):
            packet = data[b"frames"][index]
            if reset_at_keys and packet[b"keyframe"]:
                decoder[b"reset"](decoder)
            rgb = decoder[b"decode"](decoder, packet[b"hex"])
            if not isinstance(rgb, bytes):
                raise ValueError(f"Lua QTRLE failed at frame {index - 1}: {rgb!r}")
            if hashlib.sha256(rgb).hexdigest().encode("ascii") != packet[b"rgbSha256"]:
                raise ValueError(f"Lua/FFmpeg decoded RGB mismatch at frame {index - 1}")
            checks += 1
    print(f"QTRLE/FFmpeg RGB reference: {checks} exact frame checks ({module.__name__})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--python-deps", type=Path, help="Directory containing optional test dependencies")
    parser.add_argument("--mod-schema", type=Path)
    parser.add_argument("--i3d-schema", type=Path)
    args = parser.parse_args()
    if args.python_deps:
        sys.path.insert(0, str(args.python_deps))
    from lupa import lua51, lua54
    for module in (lua51, lua54):
        for script in sorted((MOD / "tests").glob("*_spec.lua")):
            lua = module.LuaRuntime(unpack_returned_tuples=True)
            lua.globals().TEST_SCRIPT = script.as_posix()
            lua.execute("dofile(TEST_SCRIPT)")
        verify_decoder_reference(module)
    if args.mod_schema or args.i3d_schema:
        from lxml import etree
        documents = [(args.mod_schema, MOD / "modDesc.xml")]
        documents.extend((args.i3d_schema, path) for path in sorted((MOD / "assets").rglob("*.i3d")))
        for schema, document in documents:
            if schema:
                validator = etree.XMLSchema(etree.parse(str(schema)))
                validator.assertValid(etree.parse(str(document)))
                print(f"Official schema passed: {document.name}")


if __name__ == "__main__":
    main()
