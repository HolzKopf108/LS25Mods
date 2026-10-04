# Tractor Media Screen prüfen

## Automatisierte Prüfung

Vom Repository-Stamm:

```powershell
python -m unittest discover -s FS25_TractorMediaScreen/tests -p test_build.py -v
lua FS25_TractorMediaScreen/tests/tractor_media_screen_spec.lua
```

Im Mod-Ordner funktionieren entsprechend `python -m unittest discover -s tests -p test_build.py -v` und `lua tests/tractor_media_screen_spec.lua`.

Die Lua-Prüfungen behandeln Linkauswertung, Decoderbereitschaft, Zeitbegrenzung, Ende/Fehler/Freigabe, Shop-Kennungen, gezielte Fahrzeugauswahl, eigene Materialinstanzen, lokale Eingaben, veraltete Dialogantworten, Fahrzeugwechsel, asynchrones Löschen und Dedicated Server. Die Spielobjekte sind nachgebildet. Echte FS25-APIs wurden getrennt anhand der in der Mod-README verlinkten Primärquellen abgeglichen.

Alternative ohne eigene Lua-Installation: `python tools/check_project.py` verwendet `lupa` für Lua 5.1 und 5.4 sowie optional `lxml` zur Schemaprüfung. Abhängigkeiten nur für Tests installieren:

```powershell
python -m pip install --target <Testverzeichnis> lupa lxml
python tools/check_project.py --python-deps <Testverzeichnis> --mod-schema <modDesc.xsd> --i3d-schema <i3d-1.6.xsd>
```

Die Platzhalter durch echte Pfade ersetzen. Die beiden XSD-Dateien aus den offiziellen, in der Mod-README verlinkten Quellen beziehen. Keine Testbibliotheken werden ins Mod-ZIP gepackt.

Stand 04.10.2026: 67 Lua-Prüfungen mit Lua 5.1 und 5.4 bestanden. Vier Python-Prüfungen für Geometrie/Flächenorientierung, komprimierte DDS samt Mipmaps, Dateiauswahl und exakte ZIP-/Quellgleichheit bestanden. Manifest und I3D gegen die offiziellen Schemas validiert. Das ist kein Spieltest.

## Ausstehender erster FS25-Lauf

1. Testspielstand und Mod-Version 0.1.0.0 verwenden. In `log.txt` auf die Ladezeile und Lua-Fehler achten.
2. Basisspiel-Valtra im Shop mit/ohne Monitor vergleichen. Kaufen, Mieten, Werkstattumbau und bestehende Ausstattungen prüfen.
3. Position mit `tmsMount` prüfen/kalibrieren und mit `tmsNodes` mögliche Kabinenanker protokollieren. Der vorläufige Anker ist Fahrzeugkomponente 1. Er kann für Kabinenfederung ungeeignet sein und muss danach durch einen bestätigten Kabinenknoten ersetzt werden.
4. Testbild auf 3D-Fläche und im HUD ansehen. Blickwinkel, Verdeckung, Innen-/Außenkamera, Tag/Nacht, Seitenverhältnis und Flimmern prüfen.
5. Eigenen Testfilm in OGV, MP4 und WebM versuchen. `tmsStatus` und Zustandswechsel im Log sichern. Film dauert sechs Sekunden und enthält einen leisen Prüfton. Ein Codecfehler ist kein Beweis für das Fehlen aller Videofunktionen.
6. Bei Aussteigen, Fahrzeugwechsel, Menüöffnung und Mapende dürfen weder Video noch Ton weiterlaufen. Zwei Monitore auf demselben Client dürfen ihre Materialien nicht gegenseitig ändern.
7. Speichern/Laden: Einbau bleibt erhalten, kein automatischer Start persönlicher Medien. Verkauf und Löschen während einer Ladeoperation prüfen.
8. Zwei Clients und Dedicated Server: Ausstattung sichtbar, fremder Monitor schwarz, fremder Ton stumm. Fahrzeugübernahme, späterer Beitritt und zwei ausgerüstete Traktoren prüfen.

Für die nächste Auswertung werden das aktuelle Log, Videotest-Ergebnisse und Montage-/Knotenwerte benötigt. Modellvorschau, Schema und simulierte Tests bestätigen weder den echten Import noch Bild, Ton oder Multiplayer im laufenden FS25.
