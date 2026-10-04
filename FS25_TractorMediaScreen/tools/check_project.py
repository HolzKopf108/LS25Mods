"""Run Lua 5.1/5.4 tests and optional official XSD validation using Lupa/lxml."""
from pathlib import Path
import argparse
import sys

MOD = Path(__file__).resolve().parents[1]


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
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.globals().TEST_SCRIPT = (MOD / "tests/tractor_media_screen_spec.lua").as_posix()
        lua.execute("dofile(TEST_SCRIPT)")
    if args.mod_schema or args.i3d_schema:
        from lxml import etree
        for schema, document in ((args.mod_schema, MOD / "modDesc.xml"),
                                 (args.i3d_schema, MOD / "assets/monitor/monitor.i3d")):
            if schema:
                validator = etree.XMLSchema(etree.parse(str(schema)))
                validator.assertValid(etree.parse(str(document)))
                print(f"Official schema passed: {document.name}")


if __name__ == "__main__":
    main()
