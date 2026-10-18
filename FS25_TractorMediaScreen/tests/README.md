# Tractor Media Screen prüfen

## Automatisierte Prüfung

Vom Repository-Stamm:

```powershell
python -m unittest discover -s FS25_TractorMediaScreen/tests -p "test_*.py" -v
lua FS25_TractorMediaScreen/tests/tractor_media_screen_spec.lua
lua FS25_TractorMediaScreen/tests/cabin_mount_spec.lua
lua FS25_TractorMediaScreen/tests/cabin_video_spec.lua
lua FS25_TractorMediaScreen/tests/qtrle_decoder_spec.lua
lua FS25_TractorMediaScreen/tests/decoded_video_spec.lua
lua FS25_TractorMediaScreen/tests/link_dialog_spec.lua
lua FS25_TractorMediaScreen/tests/native_video_spec.lua
lua FS25_TractorMediaScreen/tests/runtime_api_report_spec.lua
lua FS25_TractorMediaScreen/tests/pixel_probe_spec.lua
lua FS25_TractorMediaScreen/tests/pixel_pip_spec.lua
lua FS25_TractorMediaScreen/tests/logging_spec.lua
```

Im Mod-Ordner funktionieren entsprechend `python -m unittest discover -s tests -p "test_*.py" -v` und `lua tests/tractor_media_screen_spec.lua` sowie die übrigen Lua-Specs.

Die Lua-Prüfungen behandeln Linkauswertung, Decoderbereitschaft, Zeitbegrenzung, Ende/Fehler/Freigabe, Shop-Kennungen, gezielte Fahrzeugauswahl, eigene Materialinstanzen, lokale Eingaben, veraltete Dialogantworten, Fahrzeugwechsel, asynchrones Löschen und Dedicated Server. Die Spielobjekte sind nachgebildet. Echte FS25-APIs wurden getrennt anhand der in der Mod-README verlinkten Primärquellen abgeglichen.

Alternative ohne eigene Lua-Installation: `python tools/check_project.py` verwendet `lupa` für Lua 5.1 und 5.4 sowie optional `lxml` zur Schemaprüfung. Es führt alle `tests/*_spec.lua` getrennt aus. Abhängigkeiten nur für Tests installieren:

```powershell
python -m pip install --target <Testverzeichnis> lupa lxml
python tools/check_project.py --python-deps <Testverzeichnis> --mod-schema <modDesc.xsd> --i3d-schema <i3d-1.6.xsd>
```

Die Platzhalter durch echte Pfade ersetzen. Die beiden XSD-Dateien aus den offiziellen, in der Mod-README verlinkten Quellen beziehen. Keine Testbibliotheken werden ins Mod-ZIP gepackt.

Stand 18.10.2026, Version 0.1.9.0: **471 Lua-Prüfungen je mit Lua 5.1 und 5.4** bestanden (143 Integration, 21 Montage, 20 Kabinenclip, 53 Dialog, 30 nativer Player, 76 QTRLE-Decoder, 29 Decodersitzung, 21 Laufzeitinventur, 37 Pixelprobe, 34 Pixel-PiP, 7 Logger). Zusätzlich **120 exakte RGB-Referenzvergleiche je Lua-Version**: alle 60 Bilder sequenziell und nach unabhängigen Neustarts an den Schlüsselbildern. **21 Python-Prüfungen** einschließlich beider Audiotests und erneuter FFmpeg-Decodierung bestanden. Manifest und beide I3D-Dateien sind gegen die offiziellen Schemas validiert. Das ZIP enthält 119 Laufzeitdateien und stimmt mit den Quellen überein.

Der neue Decoder ist mit vollständigen Bildern, Änderungen, leeren Paketen, Zeilenausschnitten, beschädigten Daten und begrenzten Längen geprüft. Die Integration prüft native Playerzeit statt Spielzeit, Schleifen und Zeitsprünge, maximal zehn Pakete je Update, einmaligen Tonplayer, manuelle PiP-Sichtbarkeit, 20-Sekunden-Grenze sowie Fehler-/Menü-/Fahrzeug-/Kartenende. Der Kabinenpfad nutzt die echten Lua-Decoderdaten, aber nachgebildete GPU-Funktionen. `check_project.py` vergleicht die RGB-Bytes des echten Lua-Decoders mit den hinterlegten FFmpeg-Referenzhashes, ohne nachgebildeten Decoder.

Die Python-Prüfungen betreffen Geometrie, DDS/Mipmaps, Dateiauswahl, exakte ZIP-/Quellgleichheit, Quellvideo-/Frame-/Pakethashes, decodierte Audiopegel und API-Berichtsparser. Der Pakettest prüft die frühe Logger-Ladereihenfolge und verhindert direkte mod-eigene Logging-Aufrufe außerhalb des zentralen Loggers. Zwei Audiotests und der erneute QTRLE-Referenztest benötigen optional FFmpeg/ffprobe und werden bei fehlenden Werkzeugen übersprungen. Beim dokumentierten Lauf waren diese Werkzeuge verfügbar; nichts wurde übersprungen. Normaler Build und Spielen benötigen sie nicht. Diese Prüfungen ersetzen keinen Sicht-, Hör- oder Leistungstest von 0.1.9.0.

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

Das inzwischen ersetzte vierte Protokoll stammt vom 06.10.2026, etwa 17:57 bis 18:05 Uhr, unter FS25 1.24.0.0. Der Benutzer bestätigt den optionalen PiP-Start und den passenden Testton. Das Log zeigte `volume=1.00`, laufende OGV-Proben und vorbereitete Kabinenbilder mit 256 x 256. Es enthielt keine der vorherigen Kabinentextur-Warnungen. Die veraltete Mod-Meldung betrifft `FS25_MovePlaceables`; kein entsprechender Fehler von TractorMediaScreen.

## Auswertung der Laufzeitinventur mit 0.1.4.0

Das inzwischen ersetzte Protokoll mit Version 0.1.4.0 enthält FS25 1.24.0.0. Der Block vom 06.10.2026 um 19:02:53 Uhr meldet `tables=2 entries=4468 functions=2148 selected=138 shown=138 limited=false blockedInheritance=0 missingControlNames=0 environmentFailures=0`. `createTextureBuffer` und die Materialfunktionen sind sichtbar. Es gibt keinen erkennbaren Video-zu-Textur-Aufruf in den erfassten Namen; daraus folgt kein Unmöglichkeitsbeweis.

Die Inventur ruft keine entdeckten Funktionen auf und liefert keine Signaturen. Sie liest nur Namen aus erreichbaren Tabellen und meldet Grenzen bzw. bekannte Kontrollfunktionen, die über die Tabellen nicht erfasst wurden. Ein unvollständiger Bericht beweist keine fehlende Fähigkeit. Ebenso wäre ein passender Funktionsname allein noch kein Nachweis für Videotransfer. Dedicated Server führen diese Clientdiagnose nicht aus.

## Bestätigter Pixeltransfer mit 0.1.5.0

Das inzwischen ersetzte Protokoll mit Mod-Version 0.1.5.0 stammt vom 11.10.2026, FS25 1.24.0.0. Der Versuch von 18:47:46.254 bis 18:48:06.250 endet mit `reason=completed uploads=200`; vier kürzere Versuche enden ebenfalls. `TextureFormat.R32G32B32A32_FLOAT` wird als benannter Formatwert 27 übergeben. Das Log enthält keine Texturpuffer- oder Shaderfehler. Die Warnung über nicht binäre IndexedTriangleSets betrifft die eigene temporäre Prototypfläche, nicht den Bildtransfer.

Der Benutzer bestätigt bewegte Kabinenausgabe, korrekte Perspektive und Ende nach 20 Sekunden beziehungsweise beim Aussteigen. Der Farbtest hatte absichtlich keinen Ton. Die bisherige PiP-Ausblendung war eine Einschränkung im Modcode. Dieser Test bestätigt den laufenden Transfer von CPU-Pixeln zum 3D-Material, aber weder einen Decoder noch eine brauchbare höhere Auflösung/Bildrate.

## Transparentes PiP mit 0.1.6.0

Das inzwischen ersetzte Protokoll enthält den Lauf vom 11.10.2026 etwa 20:09 bis 20:12 Uhr, Version 0.1.6.0 unter FS25 1.24.0.0. Zwei vollständige Pixeltests melden je 200 Uploads. `Pixel PiP first render submitted` erscheint um 20:11:00.913 bei Bild 29 und um 20:11:28.768 bei Bild 0. Ein Abbruch oder Lua-/Shaderfehler ist nicht protokolliert. Der Benutzer bestätigt trotzdem nur die sichtbare Überschrift bei transparentem Bildbereich; Kabinenraster und OGV samt Ton funktionieren.

Der Abgleich mit dem offiziellen RenderElement zeigte die fehlende Zuweisung vollständiger Overlay-UVs vor dem Zeichnen. 0.1.7.0 ergänzte diese und setzte Weiß mit voller Deckkraft sowie `useAlpha=false`. Die fehlende Initialisierung war belegt; die genaue Ursache des transparenten Bildes war damit noch nicht im Spiel nachgewiesen. Neue Diagnosezeilen trennten Erzeugung, Aktualisierung und tatsächlichen Zeichenaufruf.

## Schwarzes PiP mit 0.1.7.0

Das inzwischen ersetzte `local/log.txt` enthielt Version 0.1.7.0 unter FS25 1.24.0.0 vom 12.10.2026, etwa 19:08 bis 19:11 Uhr. Beide Pixelversuche enden mit 200 Kabinenuploads. Der zweite protokolliert 200 Renderaufrufe und 1.157 Zeichenaufrufe ohne übersprungene Bilder. Die Diagnose meldet `ready=true`, dieselbe Material-ID an beiden Flächen, die erwartete Kameraposition und -rotation sowie orthografische Höhe. Passende Lua- oder Shaderfehler fehlen.

Der Benutzer sah nun ein schwarzes Rechteck statt Transparenz. Das bestätigt die sichtbare Änderung durch 0.1.7.0, aber weiterhin kein PiP-Farbbild. Die Ursache des schwarzen Renderausgangs bleibt ungeklärt. Die verborgene Szenenwurzel entspricht dem originalen FS25-RenderElement und ist kein nachgewiesener Fehler. 0.1.8.0 umgeht diesen Pfad für das kleine Pixelraster mit direkter HUD-Ausgabe der hochgeladenen CPU-Daten.

## Bestätigtes Pixel-PiP mit 0.1.8.0

Das aktuelle `local/log.txt` enthält FS25 1.24.0.0 und Mod 0.1.8.0, geladen am 18.10.2026 um 15:57:53.785. Der erste Pixeltest endet nach 141 Uploads. Der vollständige zweite Lauf von 16:00:18.067 bis 16:00:38.061 meldet 200 Uploads; PiP übernimmt ab Bild 13 insgesamt 187 Bilder und zeichnet 1.109 Spielbilder mit 638.784 Zellen, `skipped=0` und `ready=true`. Zugehörige Lua- oder Shaderfehler fehlen. Die OGV-Wiedergabe wurde ebenfalls gestartet.

Der Benutzer bestätigt ausdrücklich sichtbares, synchrones Pixel-PiP und den Wechsel in die Außenansicht. Die direkte HUD-Ausgabe des begrenzten Rasters ist damit im Spiel bestätigt. Sie verwendet dieselbe RGBA-Tabelle wie der Kabinenupload und maximal 576 Zellzeichnungen pro Spielbild. Das ist weder ein Texturpuffer-zu-HUD-Transfer noch ein Leistungsnachweis für größere Videoauflösungen. Der Pixeltest bleibt stumm und ohne Decoder.

## Nächster Spieltest mit 0.1.9.0

1. ZIP ersetzen und Version **0.1.9.0** kontrollieren. Frisch in einen ausgerüsteten Valtra einsteigen. **Strg + Shift + 7**, dann **Decoder im Mod testen (20 s)**. Nur das Mod-ZIP ist nötig. `TMSLog.DEBUG` ist bereits `true`.
2. Erwartet wird der bekannte Testfilm auf der Kabinenfläche, absichtlich grob mit **32 x 18 Pixeln und 10 fps**, jetzt durch einen echten Lua-Decoder. Der Prüfton kommt vom einzigen nativen OGV-Player. Auf Ausrichtung, Helligkeit und fehlerhafte Farben achten. PiP muss bei einer frischen Fahrzeugsitzung zunächst aus bleiben.
3. PiP mit **Strg + Shift + 8** einschalten. Es zeigt den nativen OGV-Clip mit höherer Auflösung und 30 fps. Bewegungsphase und sechssekündige Schleifen sollen zur Kabine passen. Mehrfach aus-/einblenden sowie zwischen Innen- und Außenansicht wechseln, ohne Neustart oder zweiten Ton. Ruckler und Bild-Ton-Versatz melden.
4. Nach 20 Sekunden laufender Wiedergabe müssen Kabinenfilm und Ton enden. Wiederholen und aussteigen oder ein Menü öffnen: sofortiges Ende. Andere Traktoren dürfen das Video nicht übernehmen.
5. Strg + Shift + V und der alte Menübutton **Testvideo starten** bleiben der bisherige Referenztest mit DDS-Bildern. Diesen sowie **Pixeltransfer testen (20 s)** kurz prüfen. Der neue Decodertest verwendet keine DDS-Bildfolge und kein CPU-Zell-PiP.
6. `local/log.txt` durch das neue vollständige Protokoll ersetzen und das sichtbare Ergebnis nennen. Relevant: `Lua decoder test requested`, `In-mod decoder begin/update/completed/failed`, `Pixel surface begin` mit `source=decoded-video`, `Video ogv: playing` und mögliche Shaderfehler. `tmsStatus` zeigt optional `decoded=playing` und `decodedFrame`. Bei Problemen angeben, ob nur die Kabine oder auch PiP/Ton ausfallen. Kein Python- oder JSON-Bericht nötig.

Die [Untersuchungsnotizen](texture_buffer_research.md) beschreiben den bestätigten Pixeltransport und die neue Decoderquelle getrennt. QTRLE-RGB24-Pakete werden im Mod decodiert; die native Playerzeit wählt das Zielbild. PiP und Ton bleiben beim vorhandenen OGV-Player. Es gibt zwei Bilddecoder, aber eine Wiedergabeuhr und eine Tonquelle. Höhere Auflösungen und beliebige Videoformate sind noch nicht umgesetzt. Die 90 DDS-Dateien bleiben nur für den bisherigen Referenztest erhalten, bis der neue Weg im Spiel bestätigt ist.

Für einen späteren Test ohne Diagnoseausgaben in `scripts/TMSLog.lua` `DEBUG = false` setzen und neu bauen. Der Schalter unterdrückt alle mod-eigenen Logstufen, Inventur und optionale Overlay-Abfragen; globale Engine-Logger, Wiedergabe und Fehlerfreigabe bleiben erhalten. Native Engine-Warnungen sowie Antworten ausdrücklich aufgerufener Konsolenbefehle fallen nicht unter diesen Mod-Schalter.

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

Der Bericht `local/video_api_report.json` wurde bereits ausgewertet und kann gelöscht werden. Er enthält 819 SDK-Funktionen und 35 passende Signaturen, aber nicht einmal die nachweislich funktionierenden `createVideoOverlay`-Aufrufe. Der Filter schließt Videofunktionen ein; erneuter Export derselben SDK-Datei bringt daher keine zusätzliche Abdeckung. Die Laufzeitinventur ergänzt diese unvollständige Dokumentation. Build und Mod benötigen die JSON-Datei nicht.

Für spätere Vergleiche nach einer Spielaktualisierung bleibt der ursprüngliche Befehl verfügbar:

```powershell
python FS25_TractorMediaScreen/tools/inspect_fs25_video_api.py --game-root "E:\SteamLibrary\steamapps\common\Farming Simulator 25"
```

Das liest die von der offiziellen GIANTS-IDE verwendete Datei `sdk/debugger/scriptBinding.xml` und schreibt ausgewählte Signaturen nach `tests/local/video_api_report.json`. Es werden keine Spielfunktionen ausgeführt oder Spieldateien verändert. Der Parser ist mit künstlichen Testdaten und dem tatsächlichen lokalen Editor-XML geprüft; Editor 10.0.1 belegt jedoch nicht den API-Stand des FS25-1.24-Clients. Falls die SDK-Datei fehlt, die Meldung festhalten. Das Werkzeug rät dann keine Ersatzsignaturen.
