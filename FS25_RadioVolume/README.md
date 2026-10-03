# FS25 Radio Volume

Version **2.2.0.0** für **Landwirtschafts-Simulator 25 / Farming Simulator 25**. Ändert die Radio-Lautstärke während des Fahrens oder zu Fuß in 10%-Stufen von 0 bis 100 %. Die Umsetzung wurde anhand der FS25-Dokumentation für Spielversion 1.20.0.0 überarbeitet; `modDesc` verwendet Version 110.

| Aktion | Standardbelegung |
| --- | --- |
| Radio: leiser | Strg links + Shift links + 4 |
| Radio: lauter | Strg links + Shift links + 6 |

Ein Tastendruck ändert eine Stufe. Gedrückthalten wiederholt die Änderung nicht. Der aktuelle Prozentwert erscheint für zwei Sekunden klein **oben rechts unter dem Informationsband**, in der normalen FS25-Seitenanzeige beim „Saving“-Hinweis. Weitere Tastendrücke ersetzen den Wert und starten die Anzeigedauer neu: Es bleibt genau eine Radio-Meldung sichtbar. Andere Spielmeldungen werden nicht entfernt.

Die Radio-Aktionen erscheinen nicht im F1-Hilfemenü. Sie lassen sich weiterhin in **Einstellungen → Steuerung** neu belegen. Die vorhandenen Aktionsnamen bleiben erhalten, damit eigene Belegungen weiterverwendet werden können.

Shift + 4 und Shift + 6 sind im vorhandenen FS25-Profil bereits Debug-Fahrzeugaktionen zugeordnet. Deshalb verwenden die Standards zusätzlich Strg links.

## Installation / Update

1. Das fertige Paket aus `dist/FS25_RadioVolume.zip` verwenden. Zum Neubauen vom Repository-Stamm: `python FS25_RadioVolume/tools/build_radio_volume.py`. Im Mod-Ordner funktioniert auch `python tools/build_radio_volume.py`.
2. FS25 schließen und die bisherige `FS25_RadioVolume.zip` im verwendeten Mods-Verzeichnis durch dieses ZIP ersetzen. Einen gleichnamigen entpackten Mod-Ordner ebenfalls entfernen, damit nur eine Kopie vorhanden ist.
3. Standardverzeichnis: `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods`. Das ZIP **nicht entpacken**.
4. Den Mod beim Laden des Spielstands aktivieren. In der Mod-Liste muss **2.2.0.0** stehen.
5. Radio einschalten und im Fahrzeug die beiden Hotkeys prüfen. Bei eigenen Belegungen die Aktionen **Radio: leiser** und **Radio: lauter** verwenden.

Das Radio bleibt auf demselben Sender. Bei ausgeschaltetem Radio ändert sich dessen Lautstärkeeinstellung, ohne es einzuschalten. Gespeichert wird die normale Radio-Lautstärke im lokalen Spielprofil. Motor-, Umgebungs- und Gesamtlautstärke werden nicht geändert. In Multiplayer gilt die Lautstärke nur für den jeweiligen Spieler; auf einem Dedicated Server wird keine Audiosteuerung registriert. Lua-Scriptmods sind für PC/Mac vorgesehen.

## Änderung in 2.2.0.0

Die Hotkey-Einträge im F1-Hilfemenü sind ausgeblendet. Die zentrale Warnmeldung wurde durch die native FS25-`SideNotification` ersetzt. Ein vorhandener Radio-Eintrag wird aktualisiert, statt bei jedem Tastendruck einen weiteren Eintrag anzuhängen. Nach dem Ablauf erstellt der nächste Tastendruck wieder genau einen Eintrag. Die Lautstärkeansteuerung bleibt auf dem im Spiel bestätigten Stand von Version 2.1.0.0.

## Lautstärkeansteuerung

Die bisherige Umsetzung setzte ein verfügbares `g_settingsModel` samt Radio-Menüeintrag und dessen internem Writer voraus. Die neue Lautstärkeansteuerung benötigt dieses Menümodell nicht:

- Bei jedem Tastendruck den aktuellen Wert über `g_gameSettings:getValue("radioVolume")` lesen und die nächste 10%-Stufe zwischen 0 und 1 berechnen.
- Die echte Audiogruppe mit `AudioGroup.getAudioGroupIndexByName("RADIO")` bestimmen.
- Den Faktor über `g_soundMixer:setAudioGroupVolumeFactor(group, volume)` ändern. FS25 übernimmt die Änderung beim nächsten Mixer-Update, einschließlich seiner Lautstärke-Listener und normalen Überblendungen.
- Die neue Radio-Lautstärke über `g_gameSettings:setValue("radioVolume", volume)` übernehmen und mit `g_gameSettings:save()` speichern.

Die Eingaben gehören dem lokalen `PlayerInputComponent`. FS25 registriert dessen globale Aktionen sowohl zu Fuß als auch über `Enterable.onRegisterActionEvents` im Fahrzeug. Die Hooks werden einmal beim Laden des Scripts angehängt; FS25 verwaltet die Eingabeereignisse beim Fahrzeugwechsel und beim erneuten Belegen der Tasten.

## Fehler nachvollziehen

Die neue Version protokolliert Laden, Hotkey-Registrierung und jeden ausgeführten Lautstärkeschritt in `log.txt`. Nach einem Testlauf sind beispielsweise diese Zeilen zu erwarten; der Gruppenindex kann abweichen:

```text
[FS25_RadioVolume] v2.2.0.0 loaded; RADIO audio group=...
[FS25_RadioVolume] Hotkeys registered in ...: 2/2
[FS25_RadioVolume] Radio volume: 20% -> 30% (RADIO group=...)
```

Fehlt die Ladezeile, zuerst die installierte Mod-Version und Aktivierung prüfen. Fehlt nach einem Tastendruck die Lautstärkezeile, Registrierung und Tastenbelegung prüfen. Eine nicht verfügbare Spieleinstellung oder Audiogruppe erzeugt eine Warnung statt einer Erfolgsmeldung. Falls die Lautstärke weiterhin nicht hörbar reagiert, lässt sich der ausgeführte Weg mit dem **aktuellen** Spielprotokoll prüfen.

## Prüfung

`lua FS25_RadioVolume/tests/radio_volume_spec.lua` vom Repository-Stamm oder `lua tests/radio_volume_spec.lua` vom Mod-Ordner ausführen.

Die Regressionstests laufen ohne `SettingsModel` und prüfen die Radio-Spieloption, Mixer-Faktoren, Engine-Audioaufrufe und Lautstärke-Listener, Fuß-/Fahrzeugkontexte, 0-/100%-Grenzen, Änderungen im Audiomenü, Speicherung, Menüsperre und Neuregistrierung. Zusätzlich prüfen sie ausgeblendete F1-Einträge, fünf schnelle Schritte hoch und runter, genau eine Radio-Meldung, zurückgesetzte Anzeigedauer, Ablauf und erneute Anzeige sowie den Erhalt anderer HUD-Meldungen. Ausgeführt mit Lua 5.1 und 5.4, zusätzlich mit den direkt aus der offiziellen FS25-Dokumentation geladenen Methoden `SoundMixer.setAudioGroupVolumeFactor`, `SoundMixer.update` und `SideNotification.addNotification`. Eingabe, Profil, HUD und Audio-Engine werden dabei weiterhin nachgebildet. `modDesc.xml` wurde gegen das offizielle FS25-XSD validiert.

Die Lautstärkeregelung von Version 2.1.0.0 wurde vom Anwender im laufenden FS25 erfolgreich getestet. **Die neue Anzeige von 2.2.0.0 wurde hier noch nicht im Spiel geprüft**, da die Spielinstallation in dieser Arbeitsumgebung nicht verfügbar ist. Zum Prüfen: F1 öffnen und die Radio-Einträge kontrollieren; fünfmal schnell lauter/leiser drücken und genau einen aktuellen Prozentwert oben rechts erwarten. Zwei Sekunden nach dem letzten Tastendruck soll die Meldung verschwinden. Andere Seitenmeldungen und der „Saving“-Hinweis sollen weiterhin normal angezeigt werden.

Das Build-Script erstellt nur das Mod-Paket: `modDesc.xml`, Icon und Lua-Script. Tests, Tools und README werden nicht ins ZIP aufgenommen.

## FS25-Quellen

Recherche vom 03.10.2026, ausschließlich zur FS25-Umsetzung:

- [GIANTS FS25: SoundMixer](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=76&class=612&version=script) – Faktor, Mixer-Update, Engine-Aufruf und Lautstärke-Listener.
- [GIANTS FS25: SideNotification](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=1&class=110&version=script) – kleine native Meldungen oben rechts, gemeinsame Anzeige mit „Saving“, Anzeigedauer und Meldungseinträge.
- [GIANTS FS25: Enterable](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=661&version=script) – Fahrzeugregistrierung der globalen Spieleraktionen.
- [GIANTS FS25: PlayerInputComponent](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=69&class=600&version=engine) – Spieleraktionen, Eingabekontexte und Entfernen von Eingaben.
- [GIANTS FS25: SettingsModel](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=486&version=engine) – Abgrenzung des temporären Menümodells von den Spieleinstellungen und Speicherung.
- [Offizieller ModHub: Radio Volume Hotkeys für FS25](https://www.farming-simulator.com/mod.php?country=cl&lang=en&mod_id=362183) – zusätzlicher API-Abgleich von `radioVolume` und der Radio-Audiogruppe anhand des veröffentlichten FS25-Pakets. Kein fremdes Script oder Asset ist im Paket enthalten.
- [Offizielles FS25-Mod-Schema](https://validation.gdn.giants-software.com/xml/fs25/modDesc.xsd) – Aktionen, Standardbelegungen und Script-Einstiegspunkt.
