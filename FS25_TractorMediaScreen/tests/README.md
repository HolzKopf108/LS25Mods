# Tractor Media Screen prüfen

## Automatisierte Prüfung

Vom Repository-Stamm:

```powershell
python -m unittest discover -s FS25_TractorMediaScreen/tests -p test_build.py -v
lua FS25_TractorMediaScreen/tests/tractor_media_screen_spec.lua
lua FS25_TractorMediaScreen/tests/cabin_mount_spec.lua
lua FS25_TractorMediaScreen/tests/link_dialog_spec.lua
lua FS25_TractorMediaScreen/tests/native_video_spec.lua
```

Im Mod-Ordner funktionieren entsprechend `python -m unittest discover -s tests -p test_build.py -v` und `lua tests/tractor_media_screen_spec.lua`.

Die Lua-Prüfungen behandeln Linkauswertung, Decoderbereitschaft, Zeitbegrenzung, Ende/Fehler/Freigabe, Shop-Kennungen, gezielte Fahrzeugauswahl, eigene Materialinstanzen, lokale Eingaben, veraltete Dialogantworten, Fahrzeugwechsel, asynchrones Löschen und Dedicated Server. Die Spielobjekte sind nachgebildet. Echte FS25-APIs wurden getrennt anhand der in der Mod-README verlinkten Primärquellen abgeglichen.

Alternative ohne eigene Lua-Installation: `python tools/check_project.py` verwendet `lupa` für Lua 5.1 und 5.4 sowie optional `lxml` zur Schemaprüfung. Es führt alle `tests/*_spec.lua` getrennt aus. Abhängigkeiten nur für Tests installieren:

```powershell
python -m pip install --target <Testverzeichnis> lupa lxml
python tools/check_project.py --python-deps <Testverzeichnis> --mod-schema <modDesc.xsd> --i3d-schema <i3d-1.6.xsd>
```

Die Platzhalter durch echte Pfade ersetzen. Die beiden XSD-Dateien aus den offiziellen, in der Mod-README verlinkten Quellen beziehen. Keine Testbibliotheken werden ins Mod-ZIP gepackt.

Stand 05.10.2026, Version 0.1.1.0: 174 Lua-Prüfungen je mit Lua 5.1 und 5.4 bestanden (82 Integration, 21 Montage, 41 Dialog, 30 Decoder). Vier Python-Prüfungen für Geometrie/Flächenorientierung, komprimierte DDS samt Mipmaps, Dateiauswahl und exakte ZIP-/Quellgleichheit bestanden. Manifest und I3D gegen die offiziellen Schemas validiert. Das ist kein Spieltest.

## Auswertung des ersten FS25-Laufs

Der Benutzer bestätigt für 0.1.0.0 Shop-Konfiguration, Testbild auf der 3D-Fläche und Bild-in-Bild. Falsch waren der Montageort links auf dem Tank, Wortfilterung von YouTube und die zu niedrige HUD-Position. Strg + Shift + 0 blieb ohne erkennbare Wirkung.

`local/log.txt` vom 05.10.2026 gehört zu FS25 1.24.0.0, ModDesc-Unterstützung 114. Es enthält die aktivierte Mod-Version 0.1.0.0, vier registrierte Aktionen, erfolgreich geladenes I3D und keine fehlenden Videofunktionen. Die Wortfilter-Meldung ist enthalten, ein Video-Zustandswechsel oder Decoderfehler dagegen nicht. Der erste Lauf belegt weder erfolgreiche Videowiedergabe noch eine bestimmte Decoderfehlerursache.

## Nächster FS25-Lauf mit 0.1.1.0

1. Testspielstand und Mod-Version 0.1.1.0 verwenden. In `log.txt` auf die Ladezeile und Lua-Fehler achten.
2. Basisspiel-Valtra im Shop mit/ohne Monitor vergleichen. Kaufen, Mieten, Werkstattumbau und bestehende Ausstattungen prüfen.
3. Monitor rechts im Innenraum prüfen. Der neue feste Anker stammt vom ursprünglichen Innenkamerapunkt. Umsehen, Kamerawechsel und Fahrbahnunebenheiten dürfen den Monitor nicht von der Kabine lösen. Feinposition mit `tmsMount` prüfen/kalibrieren und bei Bedarf `tmsNodes` protokollieren.
4. Testbild auf 3D-Fläche und im höher sitzenden HUD ansehen. Blickwinkel, Verdeckung, Innen-/Außenkamera, Tag/Nacht und Abstand zur Drehzahl-/Geschwindigkeitsanzeige prüfen. Strg + Shift + 7: vollständigen YouTube-Link einfügen, Eingabefeld verlassen, **Link prüfen** anklicken. Erwartet wird **Link erkannt**, keine veränderte Schreibweise von youtube und noch kein Onlinevideo.
5. Im selben Medienmenü **Testvideo starten** klicken. Alternativ Strg + Shift + 0. Erwartet wird sofort die HUD-Testanzeige mit Ladeformat/Wartezeit, danach ein bewegter Film mit leisem Prüfton oder eine konkrete Fehlermeldung. Automatisch werden MP4, OGV und WebM versucht, jeweils mit 15 s Lade- und maximal 5 s Startwartezeit. Währenddessen kein weiteres Menü öffnen. Der sechssekündige Film wiederholt sich bis zum Stoppen. Einzeltests sind über `tmsVideo mp4`, `tmsVideo ogv` und `tmsVideo webm` möglich. Bildschirm in der Kabine zeigt weiterhin nur schwarz oder statisches Testbild.
6. Bei Aussteigen, Fahrzeugwechsel, Menüöffnung und Mapende dürfen weder Video noch Ton weiterlaufen. Zwei Monitore auf demselben Client dürfen ihre Materialien nicht gegenseitig ändern.
7. Speichern/Laden: Einbau bleibt erhalten, kein automatischer Start persönlicher Medien. Verkauf und Löschen während einer Ladeoperation prüfen.
8. Zwei Clients und Dedicated Server: Ausstattung sichtbar, fremder Monitor schwarz, fremder Ton stumm. Fahrzeugübernahme, späterer Beitritt und zwei ausgerüstete Traktoren prüfen.

Für die nächste Auswertung das neue Spielprotokoll nach `tests/local/log.txt` kopieren und Bild/Ton oder Fehlermeldung festhalten. Tests auf einem anderen PC sind weiterhin möglich. Modellvorschau, Schema und simulierte Tests bestätigen weder neuen Montageort noch Video, Ton oder Multiplayer im laufenden FS25.
