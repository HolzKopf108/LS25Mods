# Tractor Media Screen prüfen

## Automatisierte Prüfung

Vom Repository-Stamm:

```powershell
python -m unittest discover -s FS25_TractorMediaScreen/tests -p "test_*.py" -v
lua FS25_TractorMediaScreen/tests/tractor_media_screen_spec.lua
lua FS25_TractorMediaScreen/tests/cabin_mount_spec.lua
lua FS25_TractorMediaScreen/tests/cabin_video_spec.lua
lua FS25_TractorMediaScreen/tests/link_dialog_spec.lua
lua FS25_TractorMediaScreen/tests/native_video_spec.lua
```

Im Mod-Ordner funktionieren entsprechend `python -m unittest discover -s tests -p "test_*.py" -v` und `lua tests/tractor_media_screen_spec.lua` sowie die übrigen Lua-Specs.

Die Lua-Prüfungen behandeln Linkauswertung, Decoderbereitschaft, Zeitbegrenzung, Ende/Fehler/Freigabe, Shop-Kennungen, gezielte Fahrzeugauswahl, eigene Materialinstanzen, lokale Eingaben, veraltete Dialogantworten, Fahrzeugwechsel, asynchrones Löschen und Dedicated Server. Die Spielobjekte sind nachgebildet. Echte FS25-APIs wurden getrennt anhand der in der Mod-README verlinkten Primärquellen abgeglichen.

Alternative ohne eigene Lua-Installation: `python tools/check_project.py` verwendet `lupa` für Lua 5.1 und 5.4 sowie optional `lxml` zur Schemaprüfung. Es führt alle `tests/*_spec.lua` getrennt aus. Abhängigkeiten nur für Tests installieren:

```powershell
python -m pip install --target <Testverzeichnis> lupa lxml
python tools/check_project.py --python-deps <Testverzeichnis> --mod-schema <modDesc.xsd> --i3d-schema <i3d-1.6.xsd>
```

Die Platzhalter durch echte Pfade ersetzen. Die beiden XSD-Dateien aus den offiziellen, in der Mod-README verlinkten Quellen beziehen. Keine Testbibliotheken werden ins Mod-ZIP gepackt.

Stand 06.10.2026, Version 0.1.2.0: 200 Lua-Prüfungen je mit Lua 5.1 und 5.4 bestanden (88 Integration, 21 Montage, 20 Kabinenclip, 41 Dialog, 30 Decoder). Acht Python-Prüfungen für Geometrie, DDS/Mipmaps, Dateiauswahl, exakte ZIP-/Quellgleichheit sowie Quellvideo-/Framehashes bestanden. Manifest und I3D gegen die offiziellen Schemas validiert. Das ist kein Spieltest.

## Auswertung des ersten FS25-Laufs

Der Benutzer bestätigt für 0.1.0.0 Shop-Konfiguration, Testbild auf der 3D-Fläche und Bild-in-Bild. Falsch waren der Montageort links auf dem Tank, Wortfilterung von YouTube und die zu niedrige HUD-Position. Strg + Shift + 0 blieb ohne erkennbare Wirkung.

Der damals bereitgestellte erste Lauf mit FS25 1.24.0.0 und ModDesc-Unterstützung 114 bestätigte die Wortfilter-Meldung. Dieses Protokoll wurde vom Benutzer inzwischen durch den nächsten Lauf ersetzt.

## Zweiter Benutzertest mit 0.1.1.0

`local/log.txt` beginnt am 05.10.2026 um 23:51 Uhr und endet am 06.10.2026, weiterhin FS25 1.24.0.0. `VideoOverlay, failed to load ...test.mp4` mit anschließendem `startTimeout` belegt den MP4-Fehler auf diesem PC. Danach folgt mehrfach `Video ogv: playing`. Der Benutzer bestätigt das bewegte HUD-Bild, die Monitorposition, den Linkdialog und die höhere PiP-Position. Hörbarer Prüfton wurde nicht gesondert bestätigt.

Vier Eingabeaktionen sind registriert, aber kein Video-Hotkey-Callback wurde protokolliert. Video startet ausschließlich über das Menü. Der konkrete Konflikt von Strg + Shift + 0 bleibt unbekannt; das ist kein Decoderfehler.

## Nächster FS25-Lauf mit 0.1.2.0

1. ZIP ersetzen, Testspielstand und Mod-Version 0.1.2.0 verwenden. In `log.txt` auf die Ladezeile und Lua-Fehler achten.
2. Im Steuerungsmenü **Medienbildschirm: Testvideo starten/stoppen** gezielt auf **Strg links + Shift links + V** legen. Bestehende Profile können noch die alte 0-Belegung enthalten. Andere Steuerungen nicht zurücksetzen.
3. Im ausgerüsteten Valtra über Strg + Shift + 7 und **Testvideo starten** beginnen. Erwartet: OGV startet zuerst; HUD und Kabinenfläche zeigen denselben sechssekündigen Clip. Der Kabinentest hat 15 fps, das native HUD 30 fps. Bewegungsrichtung, Ausrichtung, Seitenverhältnis, Schleifen und wahrnehmbaren Zeitversatz vergleichen. Leisen Prüfton kontrollieren.
4. Beim Umsehen prüfen, dass das Bild auf der Monitorfläche liegt, perspektivisch mitdreht und von Kabinenteilen verdeckt wird. Danach PiP mit Strg + Shift + 8 ausblenden: Kabinenbild und derselbe Ton müssen weiterlaufen. Wieder einblenden und auf Zeitsprung oder doppelten Ton achten. Innen-/Außenkamera wechseln.
5. Mit Strg + Shift + V stoppen und neu starten. Im Log müssen `Video hotkey received`, `Video ogv: playing` und `Cabin clip active: prepared OGV frames` auftauchen. Ohne diese Zeilen per Menü starten und bei Bedarf `tmsStatus` prüfen: `cabin=frames`, Decoderzeit und Bildnummer. Eine Erfolgsmeldung belegt noch keine sichtbare Synchronität.
6. Aussteigen, Fahrzeugwechsel, Menüöffnung und Mapende stoppen Film und Ton. Das vorherige Schwarz-/Testbild wird wiederhergestellt; nach Aussteigen bleibt der verlassene Monitor schwarz. Strg + Shift + 9 stoppt den Film und schaltet das statische Testbild. Zwei Monitore dürfen ihre Materialien nicht gegenseitig ändern.
7. Mehrere Minuten laufen lassen, Ruckler beim ersten Durchlauf und späteren Schleifen sowie Speicherbedarf beobachten. Die vorbereiteten 90 DDS-Dateien sind ein begrenzter Test und kein Streamingdecoder. `tmsVideo webm` und `tmsVideo mp4` bleiben reine HUD-Codecproben, ohne Kabinenframes.
8. Bestehende Shop-/Savegame-Funktionen und anschließend Multiplayer mit zwei Clients/Dedicated Server prüfen: fremder Monitor schwarz, fremder Ton stumm, kein automatischer Start beim Laden oder Fahrzeugübernehmen.

Für die nächste Auswertung das neue Spielprotokoll nach `tests/local/log.txt` kopieren und Kabinenbild, Ton, Synchronität sowie Shortcut-Ergebnis festhalten. Tests auf einem anderen PC sind weiterhin möglich. Ein erfolgreicher Test mit vorbereiteten Frames bestätigt noch keinen Weg für beliebige Videos oder YouTube.
