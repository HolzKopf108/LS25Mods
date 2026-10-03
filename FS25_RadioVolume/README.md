# FS25 Radio Volume

Neu entwickelter Lua-Scriptmod für **Landwirtschafts-Simulator 25 / Farming Simulator 25**, ausgerichtet auf **FS25 1.20.0.0** und `modDesc`-Version **110**. Diese Versionen sind im vorhandenen FS25-Spielprotokoll bestätigt. Keine Übernahme des früheren RadioVolume-Mods.

| Aktion | Standardbelegung |
| --- | --- |
| Radio: leiser | Strg links + Shift links + 4 |
| Radio: lauter | Strg links + Shift links + 6 |

Pro Tastendruck eine Stufe: Aus (0 %), 10 %, …, 100 %. Gedrückthalten verändert die Lautstärke einmal. Eine kurze Meldung zeigt den Prozentwert. Beide Aktionen funktionieren beim Fahren und zu Fuß; bei ausgeschaltetem Radio wird nur dessen Lautstärkeeinstellung geändert. Das Radio wird dadurch nicht eingeschaltet.

Shift + 4 und Shift + 6 sind in der vorhandenen FS25-`inputBinding.xml` bereits `DEBUG_VEHICLE_4` und `DEBUG_VEHICLE_6` zugeordnet. Die gewählten Kombinationen sind in dieser Datei frei. Andere Mods oder eigene Belegungen können weitere Konflikte verursachen.

## Installation

1. Vom Repository-Stamm `python FS25_RadioVolume/tools/build_radio_volume.py` ausführen. Das fertige Paket liegt unter `FS25_RadioVolume/dist/FS25_RadioVolume.zip`. Alternativ im Mod-Ordner `python tools/build_radio_volume.py` ausführen. Der Build funktioniert unabhängig vom aktuellen Arbeitsverzeichnis.
2. Einen früheren `FS25_RadioVolume`-Ordner bzw. dessen ZIP aus dem Mods-Verzeichnis entfernen und durch dieses ZIP ersetzen. Das ZIP **nicht entpacken**; keine zweite Kopie parallel behalten.
3. ZIP nach `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods` kopieren und beim Laden des Spielstands aktivieren. Bei einem anderen eingestellten Mods-Verzeichnis dieses verwenden.
4. Unter Einstellungen → Steuerung die Aktionen **Radio: leiser** und **Radio: lauter** nach Wunsch belegen. Falls alte Belegungen übernommen wurden, dort die beiden Aktionen ausdrücklich neu zuweisen.

Die Lautstärke wird im normalen Spielprofil gespeichert und gilt nur für den jeweiligen Spieler. Der Mod verwendet weder eigene Lautstärkedateien noch Netzwerkereignisse. Ein Multiplayer-Server benötigt das Mod-Paket zur Freigabe des Mods; seine Lautstärke wird nicht verändert. Lua-Scriptmods sind für PC/Mac vorgesehen.

## Umsetzung und FS25-Quellen

Recherche vom 03.10.2026, anhand der GIANTS-FS25-Dokumentation für 1.20.0.0:

- [PlayerInputComponent](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=69&class=600&version=engine): Registrierung über `registerGlobalPlayerActionEvents`, mit dem InputComponent als Besitzer. So verwaltet FS25 die Hotkeys mit seinen normalen Eingaben, auch im Fahrzeug. Kein Hook auf die aus älteren LS-Versionen bekannte `FSBaseMission.registerActionEvents`.
- [SettingsModel](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=486&version=engine): Radio-Menüstufe über `getValue(key, true)` lesen, `setValue` und ausschließlich den registrierten Radio-Writer ausführen; anschließend `initial`/`saved` synchronisieren und die Spieleinstellungen speichern. Dadurch wird derselbe Einstellungsweg wie im Audiomenü verwendet, ohne andere vorgemerkte Menüänderungen anzuwenden. Die Dokumentation zeigt elf Audiostufen von Aus bis 100 %.
- [Offizielles FS25-Mod-Schema](https://validation.gdn.giants-software.com/xml/fs25/modDesc.xsd): Aktionen, Standardbelegungen, Lokalisierung und Lua-Einstiegspunkt in `modDesc.xml`.
- [FS25-Handbuch](https://manuals.giants-software.com/Farming_Simulator_25/Basegame/lang/en/FS25-manual_EN.pdf): Standard-Radiobedienung über 4, 5 und 6.
- [Courseplay-FS25-Quellcode](https://github.com/Courseplay/Courseplay_FS25/blob/main/Courseplay.lua): zusätzlicher Abgleich des globalen FS25-Input-Hooks anhand einer vom Entwickler gepflegten Umsetzung.

## Prüfung

Automatisierte Lua-Vertragstests: `lua FS25_RadioVolume/tests/radio_volume_spec.lua` vom Repository-Stamm oder `lua tests/radio_volume_spec.lua` vom Mod-Ordner aus. Diese prüfen Lautstärkestufen, Grenzen, Lesen nach Menüänderungen, Speicherung, unveränderte andere Menüwerte, lokale Spielereingaben, Menüschutz, Neuregistrierung und Eingabekonflikte. Der Build prüft das ZIP und legt `modDesc.xml` direkt in dessen Wurzel ab. `tests/`, `tools/`, `dist/` und die README werden nicht mit ins Mod-ZIP gepackt.

Zusätzlich wurde `modDesc.xml` gegen das offizielle FS25-XSD validiert. **Ein tatsächlicher Test im laufenden FS25 wurde noch nicht durchgeführt.** Die Lua-Tests verwenden nachgebildete Spielobjekte und ersetzen diesen Test nicht.

Zum Testen im Spiel: Radio im Fahrzeug einschalten; beide Hotkeys einzeln drücken; prüfen, dass der Sender unverändert bleibt und die Lautstärke hörbar reagiert. 0 % und 100 % erreichen. Im Audiomenü den gleichen Prozentwert prüfen, dort ändern und erneut die Hotkeys testen. Belegungen ändern, zwischen Fahrzeugen wechseln und neu laden; abschließend Spiel neu starten und den gespeicherten Wert kontrollieren. Bei Problemen `log.txt` auf `RadioVolume` und Lua-Fehler prüfen.
