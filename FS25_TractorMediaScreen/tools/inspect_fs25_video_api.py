"""Read installed FS25 API bindings and export only media/texture signatures.

The official GIANTS IDE reads <game>/sdk/debugger/scriptBinding.xml.
Source: https://gdn.giants-software.com/vscode.php and the official
GIANTSSoftware.farmingsimulator-ide 1.1.0 package (path discovery only).
This tool never loads game code, calls engine functions or copies game assets.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
REPORT_DIRECTORY = MOD / "tests/local"
DEFAULT_REPORT = REPORT_DIRECTORY / "video_api_report.json"
GAME_BINDING_PATH = Path("sdk/debugger/scriptBinding.xml")
RELEVANT_NAME = re.compile(r"video|overlay|texture|render.?target|material.*map", re.I)


def inspect_binding(path, source_kind="explicit_binding"):
    """Return documentation, not inferred API availability or compatibility."""
    data = path.read_bytes()
    root = ET.fromstring(data)
    if root.tag != "scriptBinding":
        raise ValueError("Expected a GIANTS scriptBinding XML document")
    functions = []
    all_functions = root.findall(".//function")
    for function in all_functions:
        if not RELEVANT_NAME.search(function.get("name", "")):
            continue
        functions.append({
            "name": function.get("name", ""),
            "category": function.get("category", ""),
            "description": function.get("desc", ""),
            "inputs": [dict(param.attrib) for param in function.findall("input/param")],
            "outputs": [dict(param.attrib) for param in function.findall("output/param")],
        })
    functions.sort(key=lambda function: function["name"])
    return {
        "report_format": 1,
        "source_kind": source_kind,
        "binding_filename": path.name,
        "binding_sha256": hashlib.sha256(data).hexdigest(),
        "binding_metadata": dict(root.attrib),
        "all_function_count": len(all_functions),
        "selected_function_count": len(functions),
        "selection": RELEVANT_NAME.pattern,
        "scope": (
            "Gefilterte Dokumentation der angegebenen Installation. "
            "Kein Laufzeitnachweis, kein Nachweis einer Video-zu-Material-Anbindung. "
            "Die Spielversion ist durch dieses XML allein nicht bestaetigt."
        ),
        "functions": functions,
    }


def binding_from_game(game_root):
    game_root = game_root.resolve()
    path = game_root / GAME_BINDING_PATH
    if not path.is_file():
        raise FileNotFoundError(
            f"Keine FS25-API-Bindings gefunden: {path}. "
            "Den Installationsordner mit data/ angeben, nicht das Spielprofil "
            "unter Documents oder den x64-Unterordner."
        )
    # A path that unexpectedly leaves the chosen game installation is not followed.
    if not path.resolve().is_relative_to(game_root):
        raise ValueError("Der Bindingpfad verlaesst die angegebene Spielinstallation")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--game-root", type=Path, help="FS25-Installationsordner mit data/")
    source.add_argument("--bindings", type=Path, help="Einzelne scriptBinding.xml, z.B. vom GIANTS Editor")
    parser.add_argument("--output", type=Path, default=DEFAULT_REPORT,
                        help="JSON-Bericht innerhalb des mod-eigenen tests/local/-Ordners")
    args = parser.parse_args()
    try:
        if args.game_root is not None:
            binding = binding_from_game(args.game_root)
            kind = "game_sdk"
        else:
            binding = args.bindings.resolve()
            kind = "explicit_binding"
        report = inspect_binding(binding, kind)
        output = args.output.resolve()
        if output.suffix.lower() != ".json" or not output.is_relative_to(REPORT_DIRECTORY.resolve()):
            raise ValueError("Der Bericht muss eine JSON-Datei im mod-eigenen tests/local/ sein")
        if output == binding.resolve():
            raise ValueError("Die Quelldatei darf nicht ueberschrieben werden")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    except (OSError, ValueError, ET.ParseError) as error:
        parser.exit(1, f"API-Pruefung fehlgeschlagen: {error}\n")
    print(f"{report['selected_function_count']} passende Signaturen "
          f"aus {report['all_function_count']} Funktionen: {output}")
    print("Nur Dokumentation ausgewertet. Es wurden keine Spielfunktionen aufgerufen.")


if __name__ == "__main__":
    main()
