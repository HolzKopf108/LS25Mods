# Untersuchung des Texturpuffers

Stand 11.10.2026. Diese Notizen unterscheiden den ursprünglichen statischen Editor-Befund vom inzwischen bestätigten Kabinenbild im Spiel. Die neue PiP-Ansicht ist noch nicht visuell geprüft.

## Belege

Das ursprünglich vom Benutzer bereitgestellte Protokoll zeigte FS25 1.24.0.0 mit Mod 0.1.4.0. Die Inventur vom 06.10.2026 um 19:02:53 erfasst 2.148 Funktionen und nennt `createTextureBuffer`, `setMaterialCustomMap` und `createMaterialTextureFromFile`. Sie meldet keine Begrenzung und keine fehlenden Kontrollnamen. Objektmethoden, die erst nach dem Erzeugen eines Objekts existieren, werden damit nicht vollständig untersucht. Das aktuelle `local/log.txt` enthält den unten ausgewerteten Test mit 0.1.5.0.

Die lokal installierte Originaldatei `C:\Program Files\GIANTS Software\GIANTS_Editor_10.0.1\editor.exe` wurde ausschließlich gelesen, nicht verändert. SHA256: `97e90aff44fd47bd886e8cfa1a4cdaf3a89c210ebc2b113253fefaeb3afd569a`. Die PE-Strukturen wurden mit Python-Standardbibliothek gelesen, eng begrenzte Funktionsbereiche mit GNU objdump betrachtet. Kein Code oder Asset dieser Installation wird ins Mod-Paket übernommen.

Die folgenden virtuellen Adressen gelten nur für genau diese Binärdatei, nicht für das Spiel oder andere Editorversionen:

| Fundstelle | Beobachtung |
| --- | --- |
| `0x14060f4d0` | Binding verbindet den Namen `createTextureBuffer`, die Argumentbeschreibung bei `0x14254fbc0` und den Worker über `0x14060f4c0`. |
| `0x14254fbc0` | Drei Argumente mit Typkennungen 6, 1, 12. Die Typnamens-Tabelle vor `0x141f85520` ordnet diese String, Int und FloatArray zu. |
| `0x140347550` | Gemeinsamer Binding-Wrapper prüft Argumente und gibt die erzeugte Entity-ID als Integer zurück. |
| `0x1405af440` | Worker verwendet das zweite Argument als Format und das dritte als initiales Floatarray. Für RGBA-Float wird die Arraylänge durch vier geteilt. Eine unpassende Anzahl führt zur Größenfehlermeldung. |
| Format-Tabelle `0x141f84810` | RGBA-Float hat vier Komponenten. Die Registrierung stellt `TextureFormat.R32G32B32A32_FLOAT` bereit. Der Mod verwendet ausschließlich diesen benannten Wert. |
| Worker nach `0x1405af538` | Erstellt eine GPU-Pufferressource und eine eigene Textur-Entity mit dem Namen `ScriptTextureBuffer`. Kein Zugriff auf Video-Overlay-Bilder. |

Daraus folgt für den experimentellen Aufruf `createTextureBuffer(name, format, colors)`. Das ist ein am Editor nachvollzogener Konstruktor, kein öffentlich dokumentierter FS25-Vertrag. Insbesondere ist kein Änderungsaufruf für einen bestehenden Puffer belegt. Der Prototyp erstellt deshalb für jedes neue Raster einen neuen Puffer, bindet ihn und gibt die vorherige Entity frei.

Der Datei-Textur-zu-Material-Weg ist durch den offiziellen [FS25 MotionPathEffectManager](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=57&class=545) belegt. Die Grundstruktur eines FS25-CustomShaders und `EMISSIVE_FS` sind in den Entwicklerquellen von [AutoDrive für FS25](https://github.com/Stephan-S/FS25_AutoDrive/blob/main/drawing/lineShader.xml) sichtbar. Der Puffershader ist eine eigene experimentelle Implementierung; er wurde nicht als fertiges fremdes Asset übernommen.

## Ausführungsversuch und Grenzen

Ein verborgener Start des lokalen Editors mit separater temporärer Konfiguration und `-runScriptCode` erreichte das kleine Marker-Script nicht. Die beiden eigens gestarteten Prozesse wurden beendet. Es wurde kein Testmodell im Editor geöffnet und kein Pixeltransfer dort ausgeführt. Das ist weder ein positiver noch ein negativer Texturpuffer-Test. Die normale Editor-Konfiguration und das vorhandene Editor-Log behielten ihren vorherigen Stand.

0.1.5.0 liefert daher einen bewusst auswählbaren Versuch für den Spiel-PC. Er läuft höchstens 20 Sekunden, erzeugt ein Raster von 32 x 18 Pixeln bei maximal zehn Uploads pro Sekunde und lädt seinen Shader erst beim Start. Pro Raster sind das 9.216 Bytes reine Floatdaten, zusätzlich zu Lua-Tabellen, Material- und Engine-Verwaltung. Die Lua-Seite hält nach einem erfolgreichen Wechsel nur die aktuelle Textur-Entity; während des Wechsels kommen die alte und die neue zusammen vor. Das beweist noch keinen stabilen GPU-Speicherverbrauch in FS25.

Die automatisierten Tests prüfen Rasterdaten, Zeitlimit, übersprungene Bilder, Ressourcenreihenfolge, Fehlerabbruch und Client-Lebenszyklus. Sie simulieren die nativen Funktionen und können weder deren FS25-Signaturen noch Shaderkompilierung, Bildausgabe oder GPU-Leistung bestätigen. Deshalb meldet das Log nur `submitted` und fordert ausdrücklich eine Sichtprüfung an.

## Bestätigter Spieltest vom 11.10.2026

Der Benutzer bestätigt mit 0.1.5.0 unter FS25 1.24.0.0 die bewegte Ausgabe auf dem Kabinenmaterial, korrekte Perspektive beim Umschauen sowie Ende nach 20 Sekunden und beim Aussteigen. Der vollständige Lauf von 18:47:46.254 bis 18:48:06.250 meldet 200 Übertragungen ohne Texturpuffer- oder Shaderfehler. Die zuvor am Editor ermittelte Konstruktorform funktioniert damit für diesen getesteten Fall auch im Spiel. Das bestätigt noch keine beliebigen Formate oder hohe Datenraten.

Der Test enthält keine Tonquelle und keinen Videodecoder. Das bisher fehlende PiP war durch eine frühe Rückkehr in `TractorMediaScreen:draw` bedingt. Es ist kein Beleg gegen die Fähigkeit der Engine, diese Pixel auch flach auszugeben.

## PiP über dasselbe Material, Version 0.1.6.0

[FS25 RenderElement, Script 1.20.0.0](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=480&version=engine) verwendet `createRenderOverlay(scene, camera, aspectRatio, resX, resY, useAlpha, shapesMask, lightMask, renderShadows, bloomQuality, enableDof, ssaoQuality, asyncShaderCompilation, atmosphereQuality)` für eine eigene Szene. Diese hängt am Weltknoten, bleibt für die Hauptansicht unsichtbar und wird ausdrücklich mit `updateRenderOverlay` aktualisiert. `renderOverlay` zeichnet das Ergebnis im HUD. Overlay vor Szene freigeben.

Die neue Umsetzung verwendet eine zweite Fläche mit genau der privaten Material-ID des Kabinenrasters. Eine eigene orthografische Kamera blickt senkrecht auf sie. Es entstehen weder ein zweiter Texturpuffer noch eine zweite Pixelquelle. Die aktuelle Bildnummer kennzeichnet, wann das Renderziel aktualisiert werden muss. `prepare` läuft während des Updates nur bei sichtbarem PiP; `draw` zeichnet nur den dazu passenden Bildstand. Ein PiP-Fehler gibt seine Ressourcen frei und lässt den Kabinentest weiterlaufen.

Die Tests prüfen Lifecycle, Materialbesitz, Freigabereihenfolge, gemeinsame Bildstände und Fehlerbegrenzung mit nachgebildeten Engine-Funktionen. Offen bleiben die echte PiP-Ausgabe dieses Puffershaders, Ausrichtung/Zuschnitt, Helligkeit und GPU-Verbrauch. Der bisher bestätigte Kabinenpfad ist von diesen offenen Punkten getrennt.

## Danach: laufende Decoderbilder

Der nächste größere Baustein ist eine Quelle real decodierter Bilder. Der veröffentlichte [FS25 VideoElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=506&version=script) liefert weiterhin keinen belegten Zugriff auf seine Pixel. Ein Browser mit [CEF OnPaint](https://github.com/chromiumembedded/cef/blob/master/include/cef_render_handler.h) kann dagegen laufende BGRA-Pixel bereitstellen. Der Entwurf wäre: Decoder/Browser, begrenztes Paket mit dem aktuellen Bild, Einlesen durch Lua, bestätigter Texturpuffer, Kabine und PiP. Das ist noch keine implementierte oder getestete Verbindung.

Für einen ersten Transportversuch ist XML ein belegter Leseweg in FS25. Der originale Entwicklercode von [FS25 Farmhand Transport.lua](https://github.com/getflowkits/fs25-farmhand-mod/blob/main/scripts/Transport.lua) liest so Daten eines externen Prozesses. Dessen Named Pipe bedient die Gegenrichtung und belegt keinen Binärlesekanal zum Mod. Eine allgemeine Lua-Binärdatei- oder HTTP-Lese-API wird deshalb nicht vorausgesetzt.

Mit nur ein bis zwei aktuellen Paketen statt einer vorbereiteten Bildbibliothek wäre die Dateimenge begrenzbar. Beispiel: 320 x 180 RGB als Base64 sind 230.400 Bytes pro Bild beziehungsweise rund 3,46 MB/s bei 15 Bildern/s, zuzüglich XML und Verarbeitungsaufwand. Dies ist eine Überschlagsrechnung, keine Leistungsmessung. Vor YouTube wären zunächst begrenzte Paketannahme, ein echter Decoder mit niedriger Auflösung, Transportleistung und Bild-Ton-Synchronisation zu prüfen. Ein Browserprozess und dessen automatischer Start sind eine noch offene Architekturentscheidung; in 0.1.6.0 wird kein Hilfsprogramm vorausgesetzt oder gestartet.

Der bestätigte Pixeltransport liefert selbst keinen Decoder und keinen Zugriff auf die native OGV-Videotextur. YouTube, Twitch und synchronisierte Videoausgabe benötigen weiterhin eine Quelle laufender Pixel und einen gemeinsamen Wiedergabezeitstand. Die vorhandenen DDS-Testbilder bleiben bis zu diesem Nachweis erhalten.
