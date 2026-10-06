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
lua FS25_TractorMediaScreen/tests/runtime_api_report_spec.lua
```

Im Mod-Ordner funktionieren entsprechend `python -m unittest discover -s tests -p "test_*.py" -v` und `lua tests/tractor_media_screen_spec.lua` sowie die übrigen Lua-Specs.

Die Lua-Prüfungen behandeln Linkauswertung, Decoderbereitschaft, Zeitbegrenzung, Ende/Fehler/Freigabe, Shop-Kennungen, gezielte Fahrzeugauswahl, eigene Materialinstanzen, lokale Eingaben, veraltete Dialogantworten, Fahrzeugwechsel, asynchrones Löschen und Dedicated Server. Die Spielobjekte sind nachgebildet. Echte FS25-APIs wurden getrennt anhand der in der Mod-README verlinkten Primärquellen abgeglichen.

Alternative ohne eigene Lua-Installation: `python tools/check_project.py` verwendet `lupa` für Lua 5.1 und 5.4 sowie optional `lxml` zur Schemaprüfung. Es führt alle `tests/*_spec.lua` getrennt aus. Abhängigkeiten nur für Tests installieren:

```powershell
python -m pip install --target <Testverzeichnis> lupa lxml
python tools/check_project.py --python-deps <Testverzeichnis> --mod-schema <modDesc.xsd> --i3d-schema <i3d-1.6.xsd>
```

Die Platzhalter durch echte Pfade ersetzen. Die beiden XSD-Dateien aus den offiziellen, in der Mod-README verlinkten Quellen beziehen. Keine Testbibliotheken werden ins Mod-ZIP gepackt.

Stand 06.10.2026, Version 0.1.4.0: 231 Lua-Prüfungen je mit Lua 5.1 und 5.4 bestanden (98 Integration, 21 Montage, 20 Kabinenclip, 41 Dialog, 30 Decoder, 21 Laufzeitinventur). 14 Python-Prüfungen für Geometrie, DDS/Mipmaps, Dateiauswahl, exakte ZIP-/Quellgleichheit, Quellvideo-/Framehashes, decodierte Audiopegel und API-Berichtsparser bestanden. Die beiden Audiotests benötigen optional FFmpeg/ffprobe und werden bei fehlenden Werkzeugen übersprungen. Normaler Build und Spielen benötigen diese Werkzeuge nicht. Manifest und I3D gegen die offiziellen Schemas validiert. Das ist kein Spieltest der Diagnoseversion.

## Auswertung des ersten FS25-Laufs

Der Benutzer bestätigt für 0.1.0.0 Shop-Konfiguration, Testbild auf der 3D-Fläche und Bild-in-Bild. Falsch waren der Montageort links auf dem Tank, Wortfilterung von YouTube und die zu niedrige HUD-Position. Strg + Shift + 0 blieb ohne erkennbare Wirkung.

Der damals bereitgestellte erste Lauf mit FS25 1.24.0.0 und ModDesc-Unterstützung 114 bestätigte die Wortfilter-Meldung. Dieses Protokoll wurde vom Benutzer inzwischen durch den nächsten Lauf ersetzt.

## Zweiter Benutzertest mit 0.1.1.0

Das inzwischen ersetzte zweite Protokoll beginnt am 05.10.2026 um 23:51 Uhr und endet am 06.10.2026, weiterhin FS25 1.24.0.0. `VideoOverlay, failed to load ...test.mp4` mit anschließendem `startTimeout` belegt den MP4-Fehler auf diesem PC. Danach folgt mehrfach `Video ogv: playing`. Der Benutzer bestätigt das bewegte HUD-Bild, die Monitorposition, den Linkdialog und die höhere PiP-Position. Hörbarer Prüfton wurde nicht gesondert bestätigt.

Vier Eingabeaktionen sind registriert, aber kein Video-Hotkey-Callback wurde protokolliert. Video startet ausschließlich über das Menü. Der konkrete Konflikt von Strg + Shift + 0 bleibt unbekannt; das ist kein Decoderfehler.

## Dritter Benutzertest mit 0.1.2.0

Das inzwischen ersetzte dritte Protokoll stammt vom 06.10.2026 mit FS25 1.24.0.0, ModDesc-Unterstützung 114 und Mod-Version 0.1.2.0. Es enthält OGV-Wiedergabe, die Kabinenframes und erfolgreiche Video-Hotkey-Callbacks. Der Benutzer bestätigt Kabinenbild, PiP-Umschaltung und Strg + Shift + V. Beanstandet sind das automatische PiP beim Videostart und fehlender Ton.

5.755 Warnungen betreffen `non-power-of-two dimensions` der Kabinenframes mit 256 x 144 Pixeln. Diese Dateien wurden auf 256 x 256 mit vollständigen Mipmaps umgestellt; die Monitorgeometrie bleibt 16:9. Die vorhandene OGV-Tonspur lag vor der Korrektur bei etwa -41,6 dBFS Mittelwert und -37,7 dBFS Spitze, zusätzlich zum Playerfaktor 0,25. Nach der Anhebung um 24 dB liegen die gemessenen Werte bei etwa -17,6/-13,1 dBFS. Die Videostreams wurden unverändert kopiert und mit identischen decodierten Videohashes überprüft. Der Playerfaktor ist jetzt 1,0. Das Log zeigt außerdem eine Hauptlautstärke von 10 %; der Mod ändert diese nicht. Noch ist nicht bewiesen, ob allein der Pegel die fehlende Tonausgabe erklärt.

## Vierter Benutzertest mit 0.1.3.0

Das aktuelle `local/log.txt` stammt vom 06.10.2026, etwa 17:57 bis 18:05 Uhr, unter FS25 1.24.0.0. Der Benutzer bestätigt den optionalen PiP-Start und den passenden Testton. Das Log zeigt `volume=1.00`, laufende OGV-Proben und vorbereitete Kabinenbilder mit 256 x 256. Es enthält keine der vorherigen Kabinentextur-Warnungen. Die veraltete Mod-Meldung betrifft `FS25_MovePlaceables`; kein entsprechender Fehler von TractorMediaScreen.

## Nächster Diagnoseversuch mit 0.1.4.0

1. Das neue ZIP installieren und einen Spielstand mit aktiviertem Mod laden. Es genügt, bis zum spielbaren Zustand zu warten; kein Fahrzeugkauf und kein Videostart nötig.
2. In `log.txt` die Ladeversion 0.1.4.0 und die Zeilen `[TractorMediaScreen] API inventory begin`, `names`, `controls` und `end` prüfen. Automatisch darf genau ein zusammengehöriger Block pro Kartenladung erscheinen. Bei einem Fehler steht dort stattdessen `API inventory failed`.
3. Das neue Log nach `tests/local/log.txt` kopieren. Der bereits vorhandene SDK-Bericht muss nicht erneut erzeugt werden. Optional wiederholt `tmsApi` die Diagnose in einer bereits eingeschalteten Konsole.

Die Inventur ruft keine entdeckten Funktionen auf und liefert keine Signaturen. Sie liest nur Namen aus erreichbaren Tabellen und meldet Grenzen bzw. bekannte Kontrollfunktionen, die über die Tabellen nicht erfasst wurden. Ein unvollständiger Bericht beweist keine fehlende Fähigkeit. Ebenso wäre ein passender Funktionsname allein noch kein Nachweis für Videotransfer. Dedicated Server führen diese Clientdiagnose nicht aus.

## Wiedergabe bei späteren Änderungen erneut prüfen

1. ZIP ersetzen und die zu prüfende Version in der Mod-Liste kontrollieren. In `log.txt` auf die Ladezeile und Lua-Fehler achten. Die funktionierende Belegung Strg links + Shift links + V beibehalten.
2. Frisch in den ausgerüsteten Valtra einsteigen und mit Strg + Shift + V starten. Erwartet: Kabinenclip läuft, **PiP bleibt aus**. Der 440-Hz-Prüfton sollte hörbar sein und am Ende jeder sechssekündigen Schleife kurz ausblenden. Im Log muss der Formatversuch `volume=1.00` enthalten. Falls es still bleibt, zusätzlich mit laufendem PiP vergleichen und im Spiel Vordergrund/Fokus, hörbare andere Spieltöne und verwendetes Ausgabegerät festhalten.
3. Mit Strg + Shift + 8 PiP einblenden, wieder ausblenden und beim laufenden Video die Kamera wechseln. Kabinenbild und Ton müssen weiterlaufen, ohne Neustart, Zeitsprung oder zweiten Ton. Die Beschriftung nennt die Kabinenausgabe jetzt Einzelbildfolge. Kabinenclip: 15 fps; natives HUD: 30 fps.
4. Bei ausgeblendetem PiP stoppen und per Taste erneut starten. PiP muss aus bleiben. Dasselbe über Strg + Shift + 7 und **Testvideo starten** prüfen. Wurde PiP bewusst eingeschaltet, bleibt es beim Neustart innerhalb derselben Fahrzeugsitzung sichtbar.
5. Im Log müssen `Video hotkey received`, `Video ogv: playing` und `Cabin clip active: prepared OGV frames` auftauchen. Die Kabinentexturen dürfen keine Warnungen über 256 x 144 mehr auslösen. Bei Bedarf `tmsStatus` prüfen: `cabin=frames`, Decoderzeit und Bildnummer. Ausrichtung, vollständiges Bild und Seitenverhältnis aus verschiedenen Blickwinkeln kontrollieren.
6. Aussteigen, Fahrzeugwechsel, Menüöffnung und Mapende stoppen Film und Ton. Das vorherige Schwarz-/Testbild wird wiederhergestellt; nach Aussteigen bleibt der verlassene Monitor schwarz. Strg + Shift + 9 stoppt den Film und schaltet das statische Testbild. Zwei Monitore dürfen ihre Materialien nicht gegenseitig ändern.
7. Mehrere Minuten laufen lassen, Ruckler beim ersten Durchlauf und späteren Schleifen sowie Speicherbedarf beobachten. Die vorbereiteten 90 DDS-Dateien sind ein begrenzter Test und kein Streamingdecoder. `tmsVideo webm` und `tmsVideo mp4` bleiben reine HUD-Codecproben, ohne Kabinenframes. Für diese Diagnosen PiP bei Bedarf selbst einschalten.
8. Bestehende Shop-/Savegame-Funktionen und anschließend Multiplayer mit zwei Clients/Dedicated Server prüfen: fremder Monitor schwarz, fremder Ton stumm, kein automatischer Start beim Laden oder Fahrzeugübernehmen.

Für die nächste Auswertung das neue Spielprotokoll nach `tests/local/log.txt` kopieren und Kabinenbild, Ton, Synchronität sowie Shortcut-Ergebnis festhalten. Tests auf einem anderen PC sind weiterhin möglich. Ein erfolgreicher Test mit vorbereiteten Frames bestätigt noch keinen Weg für beliebige Videos oder YouTube.

## Installierte Video-/Material-Schnittstellen prüfen

Der Bericht `local/video_api_report.json` wurde bereits bereitgestellt. Er enthält 819 SDK-Funktionen und 35 passende Signaturen, aber nicht einmal die nachweislich funktionierenden `createVideoOverlay`-Aufrufe. Der Filter schließt Videofunktionen ein; erneuter Export derselben SDK-Datei bringt daher keine zusätzliche Abdeckung. Die neue Laufzeitinventur ergänzt diese unvollständige Dokumentation.

Für spätere Vergleiche nach einer Spielaktualisierung bleibt der ursprüngliche Befehl verfügbar:

```powershell
python FS25_TractorMediaScreen/tools/inspect_fs25_video_api.py --game-root "E:\SteamLibrary\steamapps\common\Farming Simulator 25"
```

Das liest die von der offiziellen GIANTS-IDE verwendete Datei `sdk/debugger/scriptBinding.xml` und schreibt ausgewählte Signaturen nach `tests/local/video_api_report.json`. Es werden keine Spielfunktionen ausgeführt oder Spieldateien verändert. Der Parser ist mit künstlichen Testdaten und dem tatsächlichen lokalen Editor-XML geprüft; Editor 10.0.1 belegt jedoch nicht den API-Stand des FS25-1.24-Clients. Falls die SDK-Datei fehlt, die Meldung festhalten. Das Werkzeug rät dann keine Ersatzsignaturen.
