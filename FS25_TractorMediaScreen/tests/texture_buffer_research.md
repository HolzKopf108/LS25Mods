# Untersuchung des Texturpuffers

Stand 10.10.2026. Diese Notizen unterscheiden einen statisch nachvollzogenen Engine-Aufruf von einem erfolgreichen Laufzeit- oder Bildtest.

## Belege

Das vom Benutzer bereitgestellte `local/log.txt` zeigt FS25 1.24.0.0 mit Mod 0.1.4.0. Die Inventur vom 06.10.2026 um 19:02:53 erfasst 2.148 Funktionen und nennt `createTextureBuffer`, `setMaterialCustomMap` und `createMaterialTextureFromFile`. Sie meldet keine Begrenzung und keine fehlenden Kontrollnamen. Objektmethoden, die erst nach dem Erzeugen eines Objekts existieren, werden damit nicht vollständig untersucht.

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

## Auswertung des nächsten Spieltests

- Bewegter Balken und korrekt angeordnete Ecken: CPU-Daten erreichen sichtbar das Kabinenmaterial. Danach Auflösung und Dauer steigern und eine tatsächliche Decoderquelle untersuchen.
- Fehlende Funktion oder fehlendes Format: Die lokale Editor-Erkenntnis lässt sich nicht unverändert auf diese Modumgebung übertragen.
- Argumentfehler: Binding-Signatur des tatsächlichen Spiels gezielt prüfen; keine weiteren Parametervarianten blind ausprobieren.
- Shaderfehler, schwarzes oder falsches Bild bei angenommenen Uploads: Shader-/Materialweg weiter prüfen. Angenommene Aufrufe sind kein Sichtnachweis.

Selbst ein erfolgreicher Test liefert keinen Decoder und keinen Zugriff auf die native OGV-Videotextur. YouTube, Twitch und synchronisierte Videoausgabe benötigen weiterhin eine Quelle laufender Pixel und einen gemeinsamen Wiedergabezeitstand. Die vorhandenen DDS-Testbilder bleiben bis zu diesem Nachweis erhalten.
