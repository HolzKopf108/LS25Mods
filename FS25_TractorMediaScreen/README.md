# Tractor Media Screen

Stand: 18.10.2026. Experimentelle Version **0.1.9.0** für FS25. Der Benutzer hat den Pixeltransfer mit synchronem PiP in Innen- und Außenansicht bestätigt. Neu ist ein **Videodecoder direkt im Mod**: Lua decodiert eine komprimierte Fassung des mitgelieferten Testclips und überträgt die Pixel auf die Kabinenfläche. Der native OGV-Player liefert Ton, optionales PiP und den gemeinsamen Zeitstand. Der neue Test läuft ausschließlich aus dem Mod-ZIP, zunächst mit 32 x 18 Pixeln bei 10 Bildern/s und höchstens 20 Sekunden. **Sein Spieltest steht aus. YouTube, Twitch und beliebige Videodateien werden noch nicht unterstützt.**

## Aktueller Prototyp

Paket: `dist/FS25_TractorMediaScreen.zip`. Enthalten sind die zusätzliche Shop-Konfiguration der Basisspiel-Valtra S-Serie, ein eigenes Monitormodell mit Halter, ein lokales Testbild, Linkprüfung und der mitgelieferte Testfilm für Kabine und Bild-in-Bild. Die Ausstattung kostet vorläufig 250 und verwendet die stabilen Speicherkennungen `NONE` und `MONITOR`. Bestehende Traktorkonfigurationen werden nicht ersetzt.

Das Modell hat 126 Dreiecke, eine eigene 16:9-Fläche von 256 x 144 mm und ein Gehäuse von 286 x 177 x 40 mm. [Modellvorschau](assets/monitor/preview.svg). Dies ist eine Darstellung der eigenen Geometrie, kein FS25-Bild. Der Anker wird nach vollständigem Fahrzeugladen aus dem ursprünglichen Innenkamerapunkt und dessen festem Kabinen-Elternknoten ermittelt. Der Versatz ist 42 cm rechts, 30 cm tiefer und 52 cm vor dem Fahrerblickpunkt; die Vorderseite zeigt zum Fahrer. **Diese Montageposition hat der Benutzer vorläufig akzeptiert und sie bleibt unverändert.** Federung, Nachtbild und weitere Fahrzeuge sind noch zu prüfen. Fehlt ein geeigneter fester Anker, wird das Modell mit einer Logwarnung ausgelassen.

Alle Clients sehen die gekaufte Ausstattung. Nur der jeweilige Fahrer aktiviert sein lokales Testbild und seinen Videoplayer mit dessen Tonspur. Der Benutzer hat die Tonausgabe mit 0.1.3.0 bestätigt. Das Displaymaterial wird pro Fahrzeug isoliert; fremde Traktoren bleiben schwarz. Links bleiben im Arbeitsspeicher und werden weder protokolliert noch gespeichert oder über das Netzwerk versendet. Ein Dedicated Server lädt keine Geometrie und keinen Videoplayer.

Die eigene sechssekündige Videoprobe mit Ton liegt in OGV, WebM und MP4 vor. OGV spielt laut aktuellem Spielprotokoll, MP4 scheiterte im vorherigen Lauf auf dem Test-PC beim Laden. Der automatische Test bevorzugt daher OGV; WebM und MP4 bleiben alternative HUD-Diagnosen. Bei eingeschaltetem PiP sind während des Ladens Testbild, Format und Wartezeit sichtbar. Fehlerdetails stehen in `log.txt`.

Der Prüfton war bereits enthalten, hatte aber nur etwa -38 dBFS Spitzenpegel und wurde vom Player nochmals auf 25 % abgesenkt. Seit 0.1.3.0 sind die Tonspuren um 24 dB angehoben; die OGV-Spitze liegt jetzt bei etwa -13 dBFS. Der Player verwendet den nativen Standardwert 1,0. Videobilder, Laufzeit und abschließende Tonblende sind erhalten. Globale Lautstärkeeinstellungen bleiben unangetastet. Diese Korrektur wurde inzwischen vom Benutzer im Spiel als passend bestätigt und wird beibehalten.

Für den bisherigen OGV-Referenztest enthält das ZIP weiterhin 90 DDS-Bilder des exakt gleichen OGV-Clips: gespeichert als 256 x 256 Pixel, 15 Bilder pro Sekunde, BC1 mit vollständigen Mipmaps, insgesamt rund 3,94 MB. Das vollständige Quellbild wird auf die quadratische Textur skaliert und durch die unveränderte 16:9-Monitorfläche wieder im richtigen Seitenverhältnis dargestellt. Das vermeidet die im Benutzerlog tausendfach auftretende Warnung über 256 x 144 als nicht unterstützte Texturgröße. Die Auswahl folgt `getVideoOverlayCurrentTime` in Sekunden, auch beim Zurückspringen des Clips. Es gibt keinen zweiten Decoder oder Audioplayer und keinen selbst hochgezählten, abweichenden Zeitstand. Die Bilder werden auf dem echten Displaymaterial angezeigt, sodass Perspektive und Verdeckung durch die 3D-Szene entstehen. Bild-in-Bild zeigt weiterhin den nativen 30-fps-Clip. Seine Beschriftung nennt die Kabinenausgabe jetzt ausdrücklich Einzelbildfolge.

**Diese vorbereitete Sequenz ist ausschließlich ein Test für den mitgelieferten Clip.** Sie ist keine Lösung für beliebige Dateien oder Live-Inhalte. Für WebM/MP4 oder bei fehlender Decoderzeit bleibt die Kabinensequenz aus; der HUD-Test darf weiterlaufen. Ruckler durch Texturwechsel, korrekte Ausrichtung und sichtbare Synchronität müssen im Spiel geprüft werden. Material und Textur werden pro Fahrzeug getrennt gehalten; kein Bildwechsel auf anderen Traktoren.

Der eigene Linkdialog hat ein breites URL-Feld für bis zu 2048 Zeichen ohne Wortfilter. Ein in der Darstellung gekürzter langer Link wird vollständig ausgewertet. Gültige YouTube-Links werden erkannt, starten aber noch kein Onlinevideo. Twitch-Erkennung ist vorbereitet. Über **Testvideo starten** im selben Menü lässt sich die lokale Videoprobe auch ohne Link und unabhängig vom Video-Shortcut starten.

Die Dialoganbindung wurde mit den FS25-Klassen [TextInputElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=498&version=script), [Gui](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=436&version=script) und [FrameElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=433&version=script) abgeglichen. Grundlage des Montageankers ist [VehicleCamera](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=891&version=engine). Die Videoreihenfolge entspricht weiterhin dem dokumentierten `VideoElement`; zusätzliche Fehleranzeigen und Formatversuche ersetzen keinen Laufzeittest.

Das [aktuelle Testprotokoll](tests/local/log.txt) enthält Version 0.1.8.0 unter FS25 **1.24.0.0** vom 18.10.2026. Der vollständige Pixelversuch von 16:00:18.067 bis 16:00:38.061 meldet 200 Kabinenuploads. PiP zeichnet 1.109 Spielbilder mit insgesamt 638.784 Zellen, ohne übersprungene Zeichenaufrufe oder zugehörige Lua-/Shaderfehler. Der Benutzer bestätigt das sichtbare, synchrone Raster auch in der Außenansicht. Damit ist die kleine CPU-Rasterausgabe im HUD praktisch bestätigt; diese Zähler sind keine Leistungsmessung für höhere Videoauflösungen. Der schwarze Szenen-Renderausgang aus 0.1.7.0 bleibt ein historischer, umgangener Fehler.

## Installation und Bedienung des Prototyps

FS25 schließen, genau das ZIP aus `dist/` in das verwendete Mods-Verzeichnis legen, nicht entpacken und im Spielstand aktivieren. Version **0.1.9.0** in der Mod-Liste prüfen. Zunächst einen Testspielstand verwenden. Alle Teilnehmer und der Server benötigen dieselbe Mod-Version. Es wurden keine Spielprofil-Dateien verändert und kein Paket automatisch installiert.

Im Shop die Basisspiel-Valtra S-Serie und **Medienbildschirm: Mit Monitor (Prototyp)** auswählen. Auch der Umbau eines vorhandenen Fahrzeugs in der Werkstatt ist zu prüfen. Die Aktionen greifen nur im eigenen unterstützten Fahrzeug mit eingebautem Monitor. Sie bleiben im F1-Menü verborgen und sind im Steuerungsmenü änderbar.

| Standardkombination | Aktion |
| --- | --- |
| Strg links + Shift links + 7 | Medienmenü mit Linkprüfung, **Testvideo starten**, **Pixeltransfer testen (20 s)** und **Decoder im Mod testen (20 s)** öffnen. Noch keine Onlinewiedergabe. |
| Strg links + Shift links + 8 | Bild-in-Bild ein-/ausblenden. Kabinentest und Ton laufen weiter. |
| Strg links + Shift links + 9 | Film gegebenenfalls stoppen und statisches Kabinen-Testbild umschalten. |
| Strg links + Shift links + V | Testfilm starten/stoppen. OGV mit Kabinenbildern zuerst; bei Fehler WebM/MP4 nur im HUD. |

**Nach einem Update die Aktion „Medienbildschirm: Testvideo starten/stoppen“ im Steuerungsmenü einmal gezielt auf Strg links + Shift links + V setzen.** Die alte Belegung Strg + Shift + 0 kann im Profil gespeichert bleiben. Der Aktionsname `TMS25_VIDEO_TEST` bleibt stabil; der Mod überschreibt keine persönlichen Belegungen und setzt keine anderen Steuerungen zurück. Andere Mods können auch die neue Kombination verwenden. Der Menübutton funktioniert unabhängig davon. Die Speicherung von Spielerbelegungen ist in [FS25 InputBinding](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=51&class=533&version=script) dokumentiert.

Bild-in-Bild ist bei einer neuen Fahrzeugsitzung ausgeschaltet und wird ausschließlich mit Strg + Shift + 8 umgeschaltet. Der Videostart per Menü oder Strg + Shift + V verändert diese Auswahl nicht. Das Kabinenbild läuft auch bei ausgeblendetem PiP. Wurde PiP zuvor ausdrücklich eingeschaltet, bleibt es beim Neustart des Testfilms sichtbar.

Beim Aussteigen, Fahrzeugwechsel oder Öffnen eines Spielmenüs stoppt der Film. Der Kabinenmonitor erhält sein vorheriges schwarzes Bild beziehungsweise Testbild zurück. Bild-in-Bild und Kamerawechsel stoppen oder starten die Wiedergabe nicht neu. Eine Pause mit späterer Fortsetzung ist noch nicht implementiert.

Wenn die Entwicklerkonsole bereits aktiviert ist: `tmsStatus` zeigt zusätzlich Kabinenstatus, Playerzeit und Bildnummer. `cabin=frames` bedeutet, dass Materialwechsel ausgeführt werden; es ist kein Beleg für das sichtbare Ergebnis. `tmsVideo` oder `tmsVideo auto` startet die automatische Auswahl; `tmsVideo ogv`, `tmsVideo mp4` und `tmsVideo webm` testen einzelne Formate. `tmsVideo stop` beendet die Probe. `tmsMount` zeigt Position und Winkel relativ zum Kabinenanker; `tmsMount x y z rx ry rz` ändert sie in Metern und Grad für diese Fahrzeuginstanz ohne Speicherung. `tmsNodes` schreibt vorhandene Kabinen-/Innenraum-/Kameramappings nach `log.txt`.

Die [Testanleitung](tests/README.md) trennt automatische Prüfungen und ausstehende Spieltests. Für 0.1.9.0 bestanden **471 Lua-Prüfungen sowie 120 exakte RGB-Referenzvergleiche je unter Lua 5.1 und 5.4**, **21 Python-Prüfungen** einschließlich Audio und erneuter FFmpeg-Decodierung sowie die Validierung von Manifest und beiden I3D-Dateien gegen die offiziellen Schemas. Das ZIP enthält 119 Laufzeitdateien und stimmt mit den Quellen überein. Native Engine-Funktionen sind nachgebildet; Darstellung, Ton-Synchronität und Leistungsbedarf des neuen Decodertests müssen im Spiel geprüft werden.

## Jetzt testen: Videodecoder im Mod

1. Das ZIP mit Version **0.1.9.0** installieren und frisch in die Valtra mit Monitor einsteigen. Debug ist bereits eingeschaltet. Es ist nur das Mod-ZIP nötig, kein zusätzliches Programm und kein Berichtsscript.
2. **Strg + Shift + 7** drücken und **Decoder im Mod testen (20 s)** wählen. Dieser neue Button startet den Lua-Decoder. Strg + Shift + V startet weiterhin den bisherigen Referenztest mit DDS-Bildern.
3. In der Kabine muss der bekannte Testfilm mit Ton erscheinen. Das Bild ist absichtlich sehr grob: **32 x 18 Pixel, 10 fps**. PiP bleibt bei einer neuen Fahrzeugsitzung zunächst aus. Auf Bildausrichtung, Helligkeit und flackernde oder falsche Farben achten.
4. Mit **Strg + Shift + 8** das native PiP zuschalten. Es zeigt denselben Clip mit höherer Auflösung und 30 fps. Bewegungsphase und sechssekündige Schleifen sollen übereinstimmen; die Kabine hat weniger Zwischenbilder. Mehrfach PiP umschalten und Innen-/Außenansicht wechseln. Das darf weder die Wiedergabe neu starten noch einen zweiten Ton erzeugen.
5. Nach 20 Sekunden laufender Wiedergabe müssen Film und Ton enden. Erneut starten und aussteigen oder ein Spielmenü öffnen: Die Wiedergabe muss sofort stoppen. Danach auch den bisherigen OGV-Test und den stummen Pixeltest kurz prüfen.
6. Das vollständige neue Protokoll nach `tests/local/log.txt` kopieren und Kabinenbild, PiP, Ton, Synchronität und auffällige Ruckler beschreiben. Relevant sind `Lua decoder test requested`, `In-mod decoder begin/update/completed/failed`, `Pixel surface begin` mit `source=decoded-video` und `Video ogv: playing`. Die optionale Konsole `tmsStatus` nennt `decoded` und `decodedFrame`. Es ist kein neuer JSON-Bericht nötig.

Der neue Test enthält 60 komprimierte QuickTime-Animation-Pakete (QTRLE RGB24) aus demselben OGV-Clip. Sie stehen als Hexdaten in einer Lua-Datei, damit der Mod keinen unbelegten Binärdatei-Leseweg voraussetzt. Lua decodiert vollständige Bilder und Änderungen zum vorherigen Bild tatsächlich während der Wiedergabe. Die daraus erzeugten Farbwerte gelangen über den bestätigten Texturpuffer auf die Kabinenfläche. **Dieser Test liest keine vorbereiteten DDS-Einzelbilder.**

`getVideoOverlayCurrentTime` des einzigen nativen OGV-Players bestimmt das passende Kabinenbild. Bei Schleifen oder verspäteten Updates beginnt die Decodierung nötigenfalls am nächsten vorherigen Schlüsselbild; höchstens zehn Pakete werden je Update verarbeitet. PiP und Ton stammen direkt aus dem OGV-Player. Es gibt also zwei Bilddecoder für zwei Fassungen desselben Clips, aber nur eine Wiedergabeuhr und eine Tonquelle. Das ist noch kein Zugriff auf die native OGV-Textur und kein allgemeiner YouTube-Decoder.

Die bisherige DDS-Sequenz bleibt ausschließlich für den alten Referenztest erhalten, bis die neue Kabinenwiedergabe im Spiel bestätigt ist. Der normale Build prüft die gemeinsame Quelldatei und Paket-Hashes. Die Erzeugung der komprimierten Testdaten benötigt FFmpeg nur auf dem Entwicklungsrechner, niemals beim Spielen.

## Bestätigte Referenz: Pixeltransfer mit Bild-in-Bild

Der weiterhin verfügbare Menüpunkt **Pixeltransfer testen (20 s)** erzeugt das bekannte stumme Farbraster. Kabinenbild, synchrones PiP und Kamerawechsel wurden mit 0.1.8.0 vom Benutzer bestätigt. Dieser Weg enthält keinen Videodecoder.

Der Pixeltest erstellt 32 x 18 RGBA-Pixel bis zu zehnmal pro Sekunde, überspringt verspätete Bilder und gibt alte Puffer nach dem Materialwechsel frei. Die temporäre Kabinenfläche liegt 0,5 mm vor dem vorhandenen Display. PiP übernimmt genau die CPU-Tabelle des zuletzt erfolgreichen Kabinenuploads und deren Bildnummer. Ein einziges eigenes Bild-Overlay mit einer weißen 4 x 4 DDS wird pro Zelle eingefärbt und gezeichnet. Bei sichtbarem PiP sind das höchstens 576 Zellzeichnungen je gezeichnetem Spielbild. Die Bilddaten werden nur bei einem neuen Quellbild übernommen; beim Zeichnen entsteht keine zweite Pixelquelle oder Uhr. Diese Verwendung von Bild-Overlays und Farbmultiplikation ist in [FS25 Overlay](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=474&version=engine) dokumentiert.

Der HUD-Weg ist eine begrenzte Diagnosehilfe für das 32x18-Raster. Er umgeht den ungeklärten schwarzen Renderausgang und beweist keinen Transfer vom GPU-Texturpuffer ins HUD. Er erzeugt keine zusätzliche 3D-Szene, Kamera oder `RenderOverlay`. Eine größere Videoauflösung benötigt einen anderen HUD-Weg; die Zellzeichnungen werden dafür nicht einfach vervielfacht. Kabine und HUD erhalten dieselben Farbwerte, können durch ihre unterschiedlichen Renderpfade aber in Helligkeit und Farbwiedergabe abweichen.

Der Teststart erhält die manuelle PiP-Auswahl; er schaltet sie nicht selbst ein. Ein PiP-Fehler wird einmal protokolliert und im HUD benannt, während der Kabinentest weiterlaufen darf. Beim Beenden werden das eigene PiP-Overlay, die CPU-Daten und die Kabinenressourcen freigegeben. Es wird keine Bildbibliothek gespeichert. Der bisherige Film wird vor dem Test gestoppt. `tmsPixels` und `tmsPixels stop` bleiben optionale Konsolenbefehle; der Test ist im Menü erreichbar.

Der Weg von laufenden CPU-Farbwerten zum 3D-Material und zum kleinen HUD-Raster ist durch die Benutzertests praktisch belegt. 0.1.9.0 setzt davor erstmals einen eigenen, begrenzten Videodecoder. Höhere Auflösungen, Dauerlast und die Anbindung beliebiger Onlinequellen bleiben offen. Die Benutzerfestlegung gilt auch für Tests: ausschließlich das Mod-ZIP, kein separat zu startender Decoder oder Browserprozess.

## Debug-Meldungen ein- und ausschalten

Die einzige Einstellung steht in [scripts/TMSLog.lua](scripts/TMSLog.lua):

```lua
TMSLog = {DEBUG = true}
```

Für die Fehlersuche `true` verwenden. Für eine spätere Version ohne mod-eigene Logmeldungen auf `false` setzen und mit `python tools/build_tractor_media_screen.py` neu bauen. Das schaltet alle bisherigen und neuen Info-/Warn-/Fehlermeldungen des Mods ab. HUD-Fehleranzeigen, Fehlerbehandlung und Ressourcenfreigabe bleiben aktiv. Engine-Meldungen und Meldungen anderer Mods werden nicht verändert; ausdrücklich aufgerufene Konsolenbefehle behalten ihre Antwort.

Die automatische API-Inventur und optionalen PiP-Diagnoseabfragen laufen nur bei eingeschaltetem Debug. Das neue Pixel-PiP protokolliert `mode=cpu-raster source=cabin-upload`, Bildnummer, Rastergröße, Anzahl übernommener Bilder (`prepared`), gezeichneter Spielbilder (`draws`), einzelner Zellen (`cells`) und übersprungener Zeichenaufrufe (`skipped`) sowie die Overlay-Bereitschaft (`ready`). Fortschrittsmeldungen erfolgen höchstens alle fünf Sekunden der Pixelquelle, zusätzlich zum ersten Zeichenaufruf und zum Ende. Abfragefehler stoppen die Bildausgabe nicht. Ein `ready=true` oder steigende Zähler beweisen weiterhin keine sichtbaren Pixel.

## Grundlage des Experiments

Der ausgewertete SDK-Bericht enthält 819 dokumentierte Funktionen, davon 35 zu Video, Overlays, Texturen und Materialien. Er lässt bereits funktionierende Videoaufrufe aus und ist somit unvollständig. **`tests/local/video_api_report.json` kann gelöscht werden**; weder Build noch Mod noch dieser Test benötigen die Datei. Die relevanten Befunde sind dokumentiert, die Datei wurde hier nicht automatisch gelöscht.

Ein Teil des benötigten Weges ist inzwischen anhand einer offiziellen FS25-Quelle belegt: [MotionPathEffectManager](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=57&class=545) verwendet `createMaterialTextureFromFile` und `setMaterialCustomMap(material, name, textureEntityId, false)`, gefolgt von `setMaterial`. Eine passende Textur kann also einem Material zugewiesen werden. Auch diese Funktionen fehlen im SDK-Bericht. **Offen ist der Zugriff auf die laufenden Videobilder als solche Textur.** Eine Overlay-ID darf nicht ungeprüft als Textur-ID eingesetzt werden.

Der ebenfalls geprüfte [RenderElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=43&class=480) erzeugt eine HUD-Ansicht einer 3D-Szene. Er belegt keinen umgekehrten Videotransfer auf die Kabinenfläche. Ein verzerrtes HUD-Rechteck würde die geforderte perspektivische Darstellung mit echter Verdeckung nicht ersetzen.

Die Inventur von 0.1.4.0 lieferte mit `createTextureBuffer` die entscheidende Spur. Die lokale Binäranalyse des GIANTS Editors 10.0.1 ergab die Argumentfolge String, Integer, FloatArray und die Erstellung einer Textur-Entity aus Farbwerten. Das Experiment verwendet entsprechend `createTextureBuffer(name, TextureFormat.R32G32B32A32_FLOAT, colors)`. **Der Benutzertest mit 0.1.5.0 bestätigt diesen Aufruf inzwischen im FS25-1.24-Prozess für das 32x18-Raster.** Es gibt keine Umdeutung einer Video-Overlay-ID. Die [technischen Untersuchungsnotizen](tests/texture_buffer_research.md) halten Herkunft und Grenzen fest.

Der eigene Shader liest den linearen Puffer als Pixelraster. Grundstruktur und Emissions-Einschub sind an [FS25-AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive/blob/main/drawing/lineShader.xml) abgeglichen. Die sichtbare Kabinenausgabe mit diesem Shader wurde am 11.10.2026 bestätigt. Der Versuch braucht weder eine DLL noch einen separat gestarteten Prozess. Die reine Namensinventur bleibt erhalten und führt selbst weiterhin keine entdeckten Funktionen aus.

Erst ein erfolgreicher Versuch mit unmittelbar übertragenen Decoderbildern erlaubt es, die vorbereiteten DDS-Bilder zu entfernen. Die direkte Videoausgabe bleibt bis dahin offen. Das [Python-Werkzeug](tools/inspect_fs25_video_api.py) bleibt für spätere SDK-Vergleiche verfügbar.

## Gewünschtes Ergebnis

Die Valtra S-Serie erhält im Shop die zusätzliche Ausstattung "Medienbildschirm: ohne / mit". Der neue Monitor sitzt rechts im Innenraum. Über ein Menü wählt der Spieler ein YouTube-Video per Link und startet es mit Ton. Ein frei belegbarer Shortcut schaltet zusätzlich eine größere, flache Bild-in-Bild-Anzeige ein oder aus. Diese funktioniert in Innen- und Außenansicht, ohne das Video neu zu starten.

Das Kabinenbild liegt auf einer echten Fläche des 3D-Modells. Perspektive, Fahrzeugbewegung und Verdeckung durch andere Fahrzeugteile müssen korrekt bleiben. Monitor und Bild-in-Bild zeigen dieselbe Wiedergabe mit genau einer Tonquelle. Twitch soll später über einen eigenen Anbieterbaustein ergänzt werden können.

## Festgelegte Anforderungen

Die Antworten des Benutzers sind Grundlage der Umsetzung:

| Entscheidung | Festlegung |
| --- | --- |
| Erstes Fahrzeug | Valtra S-Serie aus dem Basisspiel. Weitere Traktoren später über getrennte Profile. |
| Laufzeit und Tests | Ausschließlich das Mod-ZIP, auch bei Entwicklungstests. Kein separat zu startendes Hilfsprogramm. Entwicklungswerkzeuge dürfen Paketassets erzeugen; sie werden beim Spielen nicht benötigt. Ein eingebetteter Browser oder nativer Bibliothekslader ist bisher nicht nachgewiesen. |
| Multiplayer | Von Beginn an persönliche Wiedergabe je Spieler. Andere Spieler sehen schwarz und hören keinen Medienton. Keine Synchronisation von Links oder Abspielpositionen. |

Ein Windows-Hilfsprogramm wäre normalerweise eine zusätzlich laufende EXE mit Browser/Decoder. Automatischer Start würde diesen Prozess nicht ersetzen. Lua-Dateien können Teil eines Mods sein; eine irgendwo abgelegte DLL oder JavaScript-Datei ergibt dagegen noch keine von FS25 nutzbare Erweiterung. Ein externer Prozess wird nicht stillschweigend vorausgesetzt.

Weitere Vorschläge für die erste Version: persönlicher Stereoton mit eigener Lautstärke, beim Aussteigen oder Fahrzeugwechsel pausieren, beim Kamerawechsel weiterspielen. Der Monitor bleibt bei eingeschaltetem Bild-in-Bild sichtbar. Bildschirmgröße, genauer Halter, Preis und Standardtasten werden beim Fahrzeugprototyp festgelegt. Räumlicher Ton ist eine mögliche spätere Erweiterung; die gewünschte räumliche Bilddarstellung gehört bereits zum Kernumfang.

## Was technisch belegt ist

Die folgenden FS25-Quellen tragen den Dokumentationsstand Script v1.20.0.0. Das ist ein API-Recherchebeleg und kein Test in der installierten Spielversion.

| Bereich | Befund und Konsequenz |
| --- | --- |
| Videos in der GUI | `VideoElement:changeVideo(newVideoFilename, volume, duration)` verwendet `createVideoOverlay(videoFilename, self.isLooping, volume or self.volume)`. Zeichnen erfolgt über `renderOverlay`. Damit existiert ein dokumentierter Ansatz für einen Videotest im HUD. Unterstützte Formate, Zugriff aus einem normalen Mod und Laufzeitverhalten müssen geprüft werden. [FS25 VideoElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=506&version=script) |
| Zusätzliches 3D-Modell | `DynamicallyLoadedParts` lädt externe I3D-Teile und verbindet sie mit einem Fahrzeugknoten. Das ist ein Ansatz für einen separaten Monitor mit Halter. Der konkrete Valtra-Kabinenknoten ist noch unbekannt. [FS25 DynamicallyLoadedParts](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=659&version=script) |
| Shop-Konfiguration | `FrontloaderAttacher.initSpecialization` registriert einen Konfigurationstyp über `g_vehicleConfigurationManager:addConfigurationType`; `onLoad` liest die Fahrzeugauswahl aus `self.configurations`. Ein eigener Monitor-Konfigurationstyp ist daraus ein abzuleitender Entwurf. [FS25 FrontloaderAttacher](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=677&version=script) |
| YouTube | Die IFrame API steuert einen eingebetteten Browser-Player. Eine normale YouTube-Seitenadresse ist damit noch keine von FS25 abspielbare Videodatei. Nicht einbettbare oder entfernte Videos und blockierter automatischer Start müssen als Fehlerfälle behandelt werden. [YouTube IFrame API](https://developers.google.com/youtube/iframe_api_reference) |
| Twitch | Der Webplayer hat eine eigene Einbettung und eigene Zustände für Livestreams. Dessen Schnittstelle wird getrennt von YouTube vorgesehen. [Twitch Video & Clips](https://dev.twitch.tv/docs/embed/video-and-clips/) |

Noch nicht belegt sind ein nutzbarer eingebetteter Browser für normale FS25-Lua-Mods und ein vollständiger Weg von dessen laufendem Bild zu einem Fahrzeugmaterial. Auch ein vorhandenes Video-Overlay beweist keine solche Materialanbindung. Fehlende Dokumentation beweist umgekehrt nicht, dass eine Fähigkeit grundsätzlich unmöglich ist.

Die FS25-Engine dokumentiert `createImageOverlayWithTexture(textureId)` für die Richtung Textur zu HUD und `setMaterialDiffuseMapFromFile(...)` für Bilddateien am Material. Keine dieser Funktionen belegt die fehlende Richtung vom laufenden Videoplayer zum 3D-Material. Außerdem reagiert das normale `VideoElement` auf Tastatureingaben mit dem Beenden der Wiedergabe. Für eine Anzeige während des Fahrens muss dieser Lebenszyklus gezielt angepasst werden. [FS25 Textur-Overlay](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=17&function=381&version=engine), [FS25 Materialtextur aus Datei](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=22&function=637&version=engine), [FS25 VideoElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=506&version=script)

Die erneute Recherche am 06.10.2026 in FS25-GDN und lokalem GIANTS Editor 10.0.1 hat keinen belegten Zugriff auf die Videotextur geliefert. Eine Overlay-ID darf nicht ohne Typnachweis als Materialtextur verwendet werden. Der OGV-Kabinentest nutzt deshalb weiterhin die dokumentierte Datei-zu-Material-Funktion; der separate Pixeltest verwendet inzwischen den bestätigten Texturpuffer. `getVideoOverlayCurrentTime` wird in FS25 `VideoElement` für Minuten/Sekunden verwendet; entsprechend indexiert der OGV-Test mit `floor(seconds * fps)` und nicht mit Millisekunden. Die vorbereiteten Bilder beweisen weder einen Browserzugang noch eine dynamische Decoderanbindung.

Die lokale Steam-Konfiguration verweist auf FS25 in `D:\SteamLibrary`. Dieses Laufwerk ist nicht verfügbar. Der Benutzer testet auf einem anderen PC und stellt dessen Protokoll unter `tests/local/log.txt` bereit. Das separate lokale Profilprotokoll vom 09.07.2026 ist veraltet. Der Basisspielpfad `data/vehicles/valtra/sSeries/sSeries.xml` ist durch einen Spielstand und das neue Testprotokoll belegt. Fahrzeug-XML und Original-I3D stehen hier weiterhin nicht zur direkten Ansicht zur Verfügung.

## Machbarkeit zuerst

Es gibt drei getrennte Fragen:

1. Kann FS25 bewegte Bilder mit Ton aus einer kontrollierten Testquelle wiedergeben?
2. Kann dieselbe laufende Quelle eine echte 3D-Bildschirmfläche und eine flache HUD-Anzeige versorgen?
3. Kann ein YouTube-Player diesen Weg zuverlässig speisen und bedienbar bleiben?

Eine Lösung der ersten Frage reicht nicht für die dritte. Der Benutzer hat externe Hilfsprogramme auch für Tests ausgeschlossen. Daher erfolgt der aktuelle Decoderversuch vollständig in Lua aus dem Mod-ZIP. Ein Browserfenster über dem Spiel erfüllt die Kabinenanforderung nicht. Eine native Erweiterung der Spielgrafik wäre ein eigener, wesentlich größerer Entwicklungsweg und wird hier nicht als triviale Mod-Funktion eingeplant.

Der erste Versuch verwendet eine selbst erzeugte bewegte Testquelle mit Bildzähler und Tonsignal. Vorproduzierte Wechselbilder können Perspektive prüfen, ersetzen aber keinen Nachweis für fortlaufend übertragene Videobilder. Die konkrete Decoder-, Material- und Übertragungstechnik wird erst nach belegten FS25-Schnittstellen festgelegt.

Für YouTube müssen außerdem die dokumentierten Vorgaben zu Playeridentität, Größe, Sichtbarkeit und zugänglichen Bedienelementen berücksichtigt werden. Ein verkleinerter oder teilweise verdeckter 3D-Player ist deshalb eine eigene offene Integrationsfrage. Der vorgesehene Weg ist der offizielle Player. [YouTube Anforderungen an eingebettete Player](https://developers.google.com/youtube/terms/required-minimum-functionality)

Der Videotransfer bleibt die entscheidende offene Frage. Shop, eigene Geometrie und Diagnose werden als unabhängig prüfbare Grundlage parallel vorbereitet. Eine reine Overlay-Lösung oder lokale Videodateien ersetzen das gewünschte YouTube-Kabinenbild nicht. Wenn kein tragfähiger Weg gefunden wird, wird das Ergebnis dokumentiert; eine Änderung des Ziels entscheidet der Benutzer.

## Umsetzung in kleinen Stufen

| Stufe | Ergebnis | Prüfung vor dem nächsten Ausbau |
| --- | --- | --- |
| 0: Technischer Machbarkeitstest | FS25-Probe mit bewegtem Testbild, echter 3D-Fläche, HUD-Bild und einer Tonquelle. Separater Nachweis, wie der YouTube-Player an diesen Weg angeschlossen werden kann. | Aktuelle FS25-Version und konkrete APIs protokolliert; Bildtransfer, Perspektive, gemeinsamer Zeitstand und Ton im Spiel geprüft. Ohne Bildtransfer bleibt die Umsetzung offen. |
| 1: Valtra und Shop | Eigener Monitor samt Halter rechts in der Kabine, zunächst mit Testbild. Shop-Auswahl ohne/mit Monitor. | Vorschau, Kauf, Mieten, Werkstattumbau und Speichern/Laden funktionieren, auch mit zwei unterschiedlich ausgestatteten Fahrzeugen. Andere Valtra-Konfigurationen bleiben erhalten. Position und Sicht werden im Spiel abgenommen. |
| 2: Bildschirm und Bild-in-Bild | Die geprüfte Testquelle läuft auf dem Monitor und im zuschaltbaren HUD. Shortcuts für Medienmenü und Bild-in-Bild sind neu belegbar. | Kamerawechsel und Bild-in-Bild verändern weder Zeitposition noch Audiozahl. Schräge Blickwinkel, Verdeckung, Nacht und unterschiedliche HUD-Skalierungen funktionieren. |
| 3: YouTube | Linkeingabe, Start/Pause, Stopp, Lautstärke und verständliche Lade-/Fehleranzeige. | Mehrere einbettbare Videos laufen mit Ton. Ungültiger Link, gesperrtes Video, Netzunterbrechung und fehlende Wiedergabefähigkeiten werden sauber behandelt. |
| 4: Alltag und Stabilität | Verhalten beim Aussteigen, Fahrzeugwechsel, Verkauf, erneutem Laden und Beenden. Größe/Position des Bild-in-Bild werden einstellbar. | Keine weiterlaufende verwaiste Tonquelle, keine Eingabesperren und kein fortlaufender Speicheranstieg. Leistungsbedarf mit/ohne Wiedergabe messen. |
| 5: Multiplayer-Abnahme | Zwei Clients und Dedicated Server, persönliche Wiedergabe je Fahrer. Diese Trennung wird bereits in allen vorherigen Stufen eingehalten. | Fremde Monitore schwarz/stumm, zwei Traktoren, Fahrzeugübernahme, späterer Beitritt und Speichern/Laden prüfen. Keine Mediensynchronisation. |
| 6: Erweiterungen | Twitch-Anbieter und weitere Fahrzeugprofile. | Live-/Offline-/Wiederverbindungszustände sowie Montage und Konfiguration jedes zusätzlichen Traktors einzeln prüfen. |

Jede spielbare Stufe erhält ein neu gebautes ZIP mit klarer Version und eine kurze manuelle Testanleitung. Automatisierte Prüfungen, Paketprüfung und tatsächliche Sicht-/Hörtests werden getrennt dokumentiert. Der Abschluss einer Stufe bedeutet nicht automatisch, dass spätere Stufen bereits funktionieren.

## Technische Aufteilung

Das ist eine geplante Modulgrenze, keine Liste bereits vorhandener FS25-APIs:

- Fahrzeuganbindung: Ziel-Valtra erkennen, Shop-Auswahl integrieren, Monitor laden und Lebenszyklus verwalten.
- Wiedergabesitzung: eine aktive Quelle, Zeitposition, Start/Pause, Lautstärke und Fehlerzustand verwalten.
- Anbieter: Link prüfen und in Video-ID oder später Twitch-Kanal übersetzen. YouTube und Twitch erhalten eigene Implementierungen hinter gemeinsamen Steuerbefehlen.
- Wiedergabeanbindung: den in Stufe 0 nachgewiesenen Weg zu Browser beziehungsweise Decoder und Spielgrafik kapseln.
- Darstellung: Kabinenmaterial und HUD verwenden dieselbe Sitzung. Das HUD startet keinen zweiten Player.
- Bedienung: Linkmenü und kontextabhängige Shortcuts. Während der Texteingabe dürfen die Fahraktionen nicht versehentlich reagieren.

Der Ablauf ist: Linkeingabe, Anbietererkennung, Wiedergabesitzung, geprüfte Bildanbindung, Ausgabe auf Kabinenfläche und HUD. Der Ton gehört zur Sitzung und wird genau einmal ausgegeben. Für Livestreams melden Anbieter ihre Fähigkeiten, damit beispielsweise eine nicht unterstützte Suche nach einer Zeitposition ausgeblendet werden kann.

Die gekaufte Monitor-Ausstattung gehört zum Fahrzeug und Spielstand. Später gespeicherte Lautstärke, HUD-Position und gegebenenfalls zuletzt verwendete Links gehören zum lokalen Benutzerprofil. Bereits im ersten Multiplayer-Prototyp werden persönliche Links und Lautstärke nicht an andere Spieler übertragen. Ein Dedicated Server benötigt keinen Videoplayer.

## Integration der Valtra

Ziel ist die zusätzliche Konfiguration am gewünschten Valtra-Shopfahrzeug. Zuerst sind dessen tatsächlicher Fahrzeugtyp, bestehende Konfigurationen und Innenraumknoten zu lesen. Ein neuer Monitor wird als eigenes Asset erstellt; Dateien anderer Mods werden nicht übernommen. Bestehende Spieldateien werden nicht verändert.

Für das Display sind eine feste 16:9-Fläche, passende UV-Koordinaten und ein überprüftes Material vorgesehen. So berechnet die 3D-Darstellung die Perspektive und Verdeckung. Ein einfach über die Kabinenposition gezeichnetes 2D-Rechteck erfüllt diese Anforderungen nicht. Materialhelligkeit, Mipmaps, Flimmern und Seitenverhältnis gehören zur visuellen Prüfung.

Falls die Erweiterung des vorhandenen Shop-Eintrags nicht sauber möglich ist, kann ein eigener Valtra-Shop-Eintrag mit Referenzen auf vorhandene Spieldaten untersucht werden. Das wäre eine sichtbare Änderung des gewünschten Ablaufs und wird vor Umsetzung mit dem Benutzer geklärt.

## Geplante Projektstruktur und Prüfung

Der Mod enthält `scripts/`, `tests/`, `tools/`, `dist/`, `assets/`, `modDesc.xml` und ein eigenes BC1-DDS-Icon mit Mipmaps. Die Fahrzeuganbindung liegt unter `scripts/vehicle/`, die Medienbausteine unter `scripts/media/`. Es gibt kein Hilfsprogramm für die Laufzeit.

`python FS25_TractorMediaScreen/tools/build_tractor_media_screen.py` läuft vom Repository-Stamm; im Mod-Ordner funktioniert `python tools/build_tractor_media_screen.py`. Das Script verwendet seine eigene Position und erzeugt `dist/FS25_TractorMediaScreen.zip`. Alle Laufzeit-Skripte, die Spezialisierung und ausdrücklich erlaubte Assettypen werden verpackt. README, Vorschauen, Tests und Tools bleiben draußen. ZIP-Integrität und jeder Eintrag werden mit dem aktuellen Quellstand verglichen. Der Build benötigt nur Python-Standardbibliothek.

Die Assets sind bereits vorhanden. Zur Neuerzeugung: `python tools/generate_monitor.py` und `python tools/generate_test_video.py`. Nur die Erzeugung der Testclips benötigt FFmpeg mit Theora/Vorbis, H.264/AAC und VP9/Opus. FFmpeg wird beim Spielen nicht benötigt und nicht mitgeliefert. `python tools/render_model_preview.py` rendert die tatsächliche Geometrie nach [assets/monitor/monitor_preview.png](assets/monitor/monitor_preview.png). Die Vorschau wird nicht ins Mod-ZIP aufgenommen. `dist/` enthält ausschließlich das installierbare ZIP.

Nach einer Änderung des OGV-Clips `python tools/generate_cabin_clip.py` und `python tools/generate_decoded_clip.py` ausführen. Es extrahiert dessen Frames 0, 2, 4 bis 178 mit FFmpeg/ffprobe und schreibt DDS plus `scripts/media/TMSCabinClipData.lua`. `python tools/generate_cabin_clip.py --check` prüft vorhandene Bilder und Hashes ohne FFmpeg. Der normale ZIP-Build führt diese Prüfung ebenfalls aus und lehnt eine veraltete oder beschädigte Bildfolge ab. Die Erzeugungswerkzeuge gehören nicht ins Mod-Paket.

`generate_decoded_clip.py` erzeugt mit FFmpeg/ffprobe aus den OGV-Quellbildern 0, 3, 6 bis 177 einen temporären QTRLE-Clip und übernimmt dessen 60 komprimierte Pakete in `scripts/media/TMSDecodedClipData.lua`. Die Paketnutzdaten umfassen 65.680 Bytes; die Lua-Datei mit Hexdaten und Prüfwerten umfasst 139.148 Bytes. Der temporäre MOV-Container wird nicht mitgeliefert. `python tools/generate_decoded_clip.py --check` und der ZIP-Build prüfen die vorhandenen Daten mit Python-Standardbibliothek. Der optionale FFmpeg-Regressionstest decodiert den Clip erneut; `check_project.py` vergleicht die echten Lua-Decoderausgaben bytegenau über SHA256 mit den hinterlegten RGB-Referenzen.

Sinnvolle automatisierte Prüfungen betreffen später Linkauswertung, Zustandswechsel, den Erhalt einer einzigen Wiedergabesitzung und den Paketinhalt. Nachgebildete Objekte allein gelten nicht als Beleg für eine gültige FS25-Schnittstelle. Sichtprüfung aus verschiedenen Winkeln, Audio, Leistung und Shop-Verhalten benötigen echte Spieltests.

Für den ersten Versuch reichen dokumentierte Messwerte statt versprochener Leistungszahlen: Bildrate des Spiels ohne/mit Wiedergabe, Bildrate der Videoquelle, CPU-/GPU-Last, Speicherbedarf und wahrnehmbarer Bild-Ton-Versatz. Auflösung und Bildrate werden daraus abgeleitet.

Der nächste praktische Schritt ist der oben beschriebene Spieltest des Lua-Decoders mit 0.1.9.0. Nach bestätigtem Bild und gemeinsamer Wiedergabe folgen Auflösung, Bildrate und Dauerlast. Der Decoder unterstützt derzeit ausschließlich die mitgelieferte QTRLE-RGB24-Fassung, weder Theora/OGV noch H.264 oder Onlineanbieter. Für das eigentliche YouTube-Ziel fehlen weiterhin ein ohne Hilfsprogramm nutzbarer Quellenzugriff und passende Wiedergabe-/Decoderfähigkeiten.

Weitere Implementierungsquellen: [FS25 ConfigurationUtil](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=15&class=172&version=script), [VehicleConfigurationItem](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=15&class=176&version=script), [Vehicle](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=888&version=script), [Courseplay-FS25-Typregistrierung](https://github.com/Courseplay/Courseplay_FS25/blob/150dcd5/Courseplay.lua), [FS25-Dialogaufruf](https://github.com/Courseplay/Courseplay_FS25/blob/150dcd5/scripts/gui/pages/CpCourseManagerFrame.lua), [offizielles Mod-Schema](https://validation.gdn.giants-software.com/xml/fs25/modDesc.xsd), [offizielles I3D-Schema](https://i3d.giants.ch/schema/i3d-1.6.xsd). Keine fremden Scripts oder Assets im Paket.
