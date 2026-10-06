"""Check the API report's source selection and preservation of documented types."""
from pathlib import Path
import importlib.util
import tempfile
import unittest

MOD = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("tms_api_inspector", MOD / "tools/inspect_fs25_video_api.py")
inspector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inspector)


class VideoAPIInspection(unittest.TestCase):
    def test_reads_only_sdk_path_and_preserves_handle_types(self):
        with tempfile.TemporaryDirectory() as directory:
            game = Path(directory)
            binding = game / "sdk/debugger/scriptBinding.xml"
            binding.parent.mkdir(parents=True)
            # Artificial names distinguish the fixture from FS25 API evidence.
            binding.write_text('''<scriptBinding fixture="true">
                <function name="fixtureGetVideoTexture" category="Fixture" desc="Fixture only">
                    <input><param name="overlay" type="entityId" desc="Fixture"/></input>
                    <output><param name="texture" type="textureId"/></output>
                </function>
                <function name="fixtureSetMaterialMap" category="Fixture">
                    <input><param name="material" type="materialId"/></input><output/>
                </function>
                <function name="fixtureSetRenderTarget" category="Fixture"><input/><output/></function>
                <function name="fixtureCreateImageOverlay" category="Fixture"><input/><output/></function>
                <function name="fixtureAddVehicle"><input/><output/></function>
            </scriptBinding>''', encoding="utf-8")
            source = inspector.binding_from_game(game)
            self.assertEqual(source, binding)
            report = inspector.inspect_binding(source, "game_sdk")
            self.assertEqual(report["all_function_count"], 5)
            self.assertEqual(report["selected_function_count"], 4)
            functions = {item["name"]: item for item in report["functions"]}
            self.assertNotIn("fixtureAddVehicle", functions)
            video = functions["fixtureGetVideoTexture"]
            self.assertEqual(video["inputs"][0]["type"], "entityId")
            self.assertEqual(video["outputs"][0]["type"], "textureId")
            self.assertEqual(report["source_kind"], "game_sdk")
            self.assertEqual(report["binding_metadata"], {"fixture": "true"})

    def test_missing_game_sdk_does_not_fall_back_to_editor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scriptBinding.xml").write_text("<scriptBinding/>", encoding="utf-8")
            with self.assertRaises(FileNotFoundError):
                inspector.binding_from_game(root)

    def test_unknown_xml_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "modDesc.xml"
            source.write_text("<modDesc/>", encoding="utf-8")
            with self.assertRaises(ValueError):
                inspector.inspect_binding(source)


if __name__ == "__main__":
    unittest.main()
