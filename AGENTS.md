# Anweisungen und Projektwissen fuer LS25Mods

Diese Datei gilt fuer das gesamte Repository und alle darin enthaltenen Mods. Vor Beginn einer Aufgabe diese Anweisungen lesen und anwenden. Vor Arbeiten an einem Mod auch dessen README, modDesc.xml und relevante Build-Scripts und Tests lesen. Neue bestaetigte Erkenntnisse hier ergaenzen; modbezogene Bedienung und Details in der jeweiligen Mod-README pflegen.

## Kommunikation und Schreibweise

- Mit dem Benutzer auf Deutsch, klar und direkt schreiben.
- Keine typografischen Gedankenstriche U+2013 oder U+2014 verwenden. Stattdessen einen normalen ASCII-Bindestrich U+002D verwenden oder den Satz ohne Strich formulieren. Das gilt fuer Chat-Antworten, Markdown, Kommentare, Beschreibungen und neu erzeugte Texte.
- Keine dekorativen Unicode-Trennlinien, Sonderzeichen-Aufzaehlungen oder auffaellige KI-Typografie hinzufuegen. Normales Markdown, normale Satzzeichen und deutsche Umlaute sind erlaubt.
- Bestehende Benutzer-Aenderungen erhalten. Vor Aenderungen den Arbeitsstand pruefen. Keine fremden Aenderungen zuruecksetzen.
- Ausdrueckliche neue Benutzeranweisungen haben Vorrang vor diesen Repo-Konventionen.

## Einheitliche Struktur pro Mod

Jeder Mod hat einen eigenen Ordner direkt im Repository, normalerweise FS25_<Name>. Seine Dateien, Tests, Werkzeuge und Build-Ergebnisse gehoeren vollstaendig in diesen Ordner:

```text
FS25_<Name>/
  dist/
    FS25_<Name>.zip
  scripts/
    <Lua-Dateien und sinnvolle Unterordner>
  tests/
    <Tests und modbezogene Testdaten>
  tools/
    build_<name>.py
    <weitere modbezogene Werkzeuge bei Bedarf>
  icon.dds
  modDesc.xml
  README.md
```

- dist/, scripts/, tests/ und tools/ sind die gemeinsamen Standardordner aller Mods. modDesc.xml, README.md und eine passende Icondatei liegen im Mod-Stamm. Der Iconname muss zum iconFilename in modDesc.xml passen; icon.dds ist der Standard.
- Keine modbezogenen tests/- oder tools/-Ordner im Repository-Stamm erstellen. Auch bei zehn oder mehr Mods bleibt jeder Mod eigenstaendig.
- Bei Bedarf weitere Ordner fuer Texturen, Modelle, XML-Konfigurationen, Lokalisierung, Sounds oder andere Assets anlegen. Zusammengehoerende Bestandteile sinnvoll gliedern; groessere Mods nicht in eine einzige Lua-Datei pressen.
- Leere Standardordner neuer Mods bei Bedarf mit .gitkeep nachvollziehbar machen. dist/ enthaelt erzeugte Ergebnisse und ist ueber /*/dist/ ignoriert. Keine ZIP-Dateien oder Python-Caches ungefragt versionieren.
- Die README im Repository-Stamm bleibt eine allgemeine, visuelle Vorstellung des LS25-Mod-Repositories. Keine konkreten Mods, Installationsanleitungen einzelner Mods oder technischen Agent-Anweisungen dort einbauen. Bestehende Animationen unter .github/assets/ erhalten.

## Python-Build und ZIP

- Jeder Mod bekommt mindestens ein ausfuehrbares Python-Build-Script in seinem eigenen tools/-Ordner. Der vorhandene Radio-Mod verwendet tools/build_radio_volume.py; dieser Name muss nicht vereinheitlicht werden.
- Das Script erzeugt dist/<ModOrdnername>.zip. modDesc.xml muss unmittelbar in der ZIP-Wurzel liegen, ohne zusaetzlichen aeusseren Mod-Ordner.
- Pfade aus __file__ ableiten, nicht aus dem aktuellen Arbeitsverzeichnis. Der Aufruf muss aus dem Repository-Stamm und aus dem jeweiligen Mod-Ordner funktionieren.
- Alle benoetigten Laufzeitdateien und Assets einpacken, auch Dateien in Unterordnern und indirekt nachgeladene Scripts. Die aktuelle Radio-Build-Datei verpackt die in modDesc.xml genannten Einstiegsscripts; bei neuen Laufzeitdateien den Build entsprechend erweitern.
- tools/, tests/, dist/, README, Agent-Anweisungen, .gitkeep, Caches und fremde Mods nicht ins Mod-Paket aufnehmen. Eine klare Auswahl der Laufzeitdateien verwenden, statt blind den kompletten Mod-Ordner zu zippen.
- ZIP-Integritaet und Inhalt pruefen. Version und Script im ZIP muessen dem aktuellen Quellstand entsprechen. Das fertige ZIP nach autorisierten Laufzeit-Aenderungen neu bauen und dessen Pfad nennen.
- Python-Standardbibliothek bevorzugen. Zusaetzliche Abhaengigkeiten nur einsetzen, wenn sie fuer die Aufgabe sinnvoll sind, und deren Installation dokumentieren.
- Beispiel fuer den bestehenden Mod: python FS25_RadioVolume/tools/build_radio_volume.py. Im Mod-Ordner: python tools/build_radio_volume.py.

## FS25-Recherche und technische Grundlagen

- Ausschliesslich Landwirtschafts-Simulator 25 recherchieren. Relevante Suchnamen sind LS25, LS 25, FS25, FS 25, Farming Simulator 25 und Farming Simulator 2025.
- Beispiele und APIs aus LS19, LS22 oder anderen Versionen nicht ungeprueft uebernehmen. Seitenkopf, Spielversion und API-Signatur kontrollieren.
- Primaere Quellen bevorzugen: GIANTS Developer Network fuer FS25, offizielles FS25-XSD, offizielle Handbuecher und Entwickler-Quellcode nachweislicher FS25-Projekte. API-Aufrufe nicht aus Erinnerung erfinden.
- Vorsicht bei der allgemeinen GDN-Seite documentation_print.php: Dort waren auch alte Scriptreferenzen enthalten. Der Titel GIANTS Engine 10 allein beweist nicht, dass alle gezeigten Klassen FS25 entsprechen.
- Die bisherige Recherche nutzte die offizielle FS25-Scriptdokumentation 1.20.0.0. Das vorhandene lokale Spielprotokoll bestaetigte modDesc-Version 110. Diese Werte sind ein dokumentierter Stand, keine dauerhaft garantierten neuesten Versionen; fuer spaetere Aenderungen neu pruefen.
- modDesc.xml gegen das offizielle FS25-Schema validieren, wenn relevante Manifest-Aenderungen gemacht werden. Aktionen, Standardbelegungen, Lokalisierung, Icon und extraSourceFiles muessen zusammenpassen.
- Lua-Scriptmods fuer PC/Mac planen. Bei Multiplayer lokale Spieleraktionen und Dedicated Server beruecksichtigen. Persoenliche Audioeinstellungen nicht per Netzwerk auf andere Spieler uebertragen.
- Hooks einmal beim Laden des Scripts installieren. Nicht bei jedem loadMap erneut anhaengen. Map-Lebenszyklus, Entfernen von Eingaben und Neuregistrierung beachten.
- Fremde Mods duerfen zur API-Pruefung dienen, aber keine fremden Scripts oder Assets ungefragt ins Repository uebernehmen. Den frueheren gescheiterten Radio-Mod nicht als Vorlage wiederverwenden.

## Gesammelte Erkenntnisse: Radio, Eingaben und HUD

Diese Details sind fuer FS25_RadioVolume ermittelt worden. Nur auf andere Mods uebertragen, wenn sie dort tatsaechlich passen.

- Die Radio-Lautstaerke ist g_gameSettings:getValue("radioVolume"), ein Zahlenwert von 0 bis 1. Beim Tastendruck den Live-Wert lesen, damit Aenderungen im Audiomenue beruecksichtigt werden.
- 10%-Stufen als ganzzahlige Schritte von 0 bis 10 berechnen, dann durch 10 teilen. Grenzen klemmen; nicht wiederholt ungerundet 0.1 addieren oder subtrahieren.
- Die Radio-Gruppe mit AudioGroup.getAudioGroupIndexByName("RADIO") ermitteln. Live-Audio ueber g_soundMixer:setAudioGroupVolumeFactor(group, volume) aendern; Spieloption ueber g_gameSettings:setValue("radioVolume", volume) setzen und g_gameSettings:save() speichern.
- Der SoundMixer setzt beim Update die Engine-Lautstaerke und benachrichtigt Lautstaerke-Listener. Ein alleiniger direkter setAudioGroupVolume-Aufruf umgeht diese Mixer-Verwaltung und kann durch weitere Mixer-Updates ueberschrieben werden.
- Die erste Umsetzung hing von g_settingsModel und internen Radio-Readern/Writern des Menues ab und funktionierte beim Benutzer nicht. Diese Abhaengigkeit nicht wieder einfuehren. SettingsModel haelt temporaere Menuewerte; es ist kein notwendiger Zugang zur Live-Radio-Lautstaerke.
- Die direkte Lautstaerkeregelung von Version 2.1.0.0 wurde vom Benutzer im laufenden FS25 erfolgreich bestaetigt.
- PlayerInputComponent.registerGlobalPlayerActionEvents eignet sich fuer globale lokale Spieleraktionen. FS25 ruft diesen Weg auch aus Enterable.onRegisterActionEvents im Fahrzeug auf, mit Fahrzeug-Eingabekontext.
- Eingabeereignisse dem lokalen InputComponent zuordnen, nur fuer player.isOwner registrieren und Dedicated Server ausschliessen. FS25 verwaltet die Entfernung mit dem Eigentuemer der Eingaben. player.locked allein ist kein Ausschlussgrund: Bewegung kann beim Fahren gesperrt sein.
- Aktionen und Bindings in modDesc.xml definieren, damit die Belegung im Steuerungsmenue aenderbar bleibt. Bestehende Aktionsnamen bei Updates erhalten.
- registerActionEvent mit triggerUp=false, triggerDown=true, triggerAlways=false, startActive=true verwendet einen Schritt pro Tastendruck statt Wiederholung durch Gedrueckthalten.
- Shift + 4 und Shift + 6 waren im lokalen Profil bereits DEBUG_VEHICLE_4 und DEBUG_VEHICLE_6 zugeordnet. Der Radio-Mod verwendet deshalb Strg links + Shift links + 4 bzw. 6. Das ist kein Beweis fuer konfliktfreie Belegung in jedem fremden Profil; dort Bindings und andere Mods pruefen.
- Radio-Hotkeys sollen im F1-Hilfemenue verborgen bleiben: g_inputBinding:setActionEventTextVisibility(eventId, false). Das entfernt die Aktionen nicht aus dem Steuerungsmenue.
- Fuer den Lautstaerkewert keine zentrale showBlinkingWarning-Meldung verwenden. FS25 SideNotification bietet eine kleine Anzeige rechts unter dem oberen Informationsband und zeichnet dort auch den Saving-Hinweis.
- SideNotification:addNotification(text, color, duration) legt Eintraege in notificationQueue an. Die aktuelle Umsetzung sucht die native Anzeige im Mission-HUD und merkt sich nur ihren eigenen Radio-Eintrag.
- Bei schnellen Aenderungen denselben Radio-Eintrag aktualisieren, text ersetzen und duration/startDuration auf 2000 ms zuruecksetzen. Keine Meldung pro Zwischenstufe ansammeln und keine fremden HUD-Meldungen loeschen. Nach Ablauf darf der naechste Tastendruck genau einen neuen Radio-Eintrag erzeugen.
- Die HUD-Aenderung von 2.2.0.0 ist automatisiert geprueft, aber in dieser Unterhaltung noch nicht vom Benutzer im Spiel bestaetigt. Nicht als bereits visuell getestetes Verhalten ausgeben.

## Tests und Fehlersuche

- Tests und Hilfsmittel bleiben im jeweiligen Mod-Ordner. Bestehende relevante Tests bei Verhaltenaenderungen anpassen und gezielte Pruefungen durchfuehren. Keine Testordner oder Testabhaengigkeiten anderer Mods vermischen.
- Nachgebildete Spielobjekte allein beweisen keine gueltige FS25-API. Die erste Testversion bildete die falsche SettingsModel-Annahme nach und bestand trotzdem. Auch bei bestandenen Tests die echten FS25-Schnittstellen kontrollieren.
- Die Radio-Regressionstests wurden mit Lua 5.1 und 5.4 ausgefuehrt, zusaetzlich mit dokumentierten echten Methoden von SoundMixer und SideNotification. Eingabe, Profil, HUD und Audio-Engine bleiben dabei nachgebildet.
- Beispiel: lua FS25_RadioVolume/tests/radio_volume_spec.lua, oder lua tests/radio_volume_spec.lua im Mod-Ordner. Tests sollen ihre Scriptpfade relativ zur eigenen Testdatei aufloesen.
- Relevante Pruefpunkte: Live-Wert nach Menueaenderung, Mixer/Listener, 0-/100%-Grenzen, Speicherung, lokale Spieler, Menuesperre, Fahrzeugwechsel, Neubelegung, neuer Spielstand sowie genau eine aktualisierte HUD-Meldung.
- Automatisierte Pruefung, Manifest-/ZIP-Pruefung und echter Spieltest getrennt berichten. Ohne gestartetes FS25 keinen Hoer- oder Sichttest behaupten.
- Bei Fehlern zuerst aktuelles log.txt, dessen Datum, geladene Mod-Version, Aktivierung, Lua-Fehler, Hotkey-Registrierung und ausgefuehrte Lautstaerkeschritte pruefen. Das bisher vorhandene lokale Protokoll vom Juli 2026 enthielt Version 1.0.0.7 und belegt keine Fehler der neuen Versionen.
- Standardprofil: %USERPROFILE%/Documents/My Games/FarmingSimulator2025/. Dort liegen u.a. log.txt, gameSettings.xml und inputBinding.xml. Ein abweichendes Mods-Verzeichnis beachten.
- Zur Installation FS25 schliessen, altes ZIP oder gleichnamigen entpackten Mod-Ordner durch genau ein neues ZIP ersetzen und beim Laden aktivieren. ZIP nicht entpacken. Version in der Mod-Liste pruefen.
- Ein DDS-Icon in unkomprimiertem Rohformat kann eine Performance-Warnung erzeugen. Diese Warnung allein erklaert keinen Lua- oder Hotkey-Fehler.

## Quellen und Pflege

Erkenntnisstand: 04.10.2026. FS25-API-Recherche und Implementierungsabgleich erfolgten am 03.10.2026. Bei neuen Erkenntnissen Quelle, betroffene Spielversion und Pruefstatus mitpflegen. Keine Vermutung als bestaetigte Erkenntnis speichern.

- [FS25 SoundMixer](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=76&class=612&version=script)
- [FS25 SideNotification](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=1&class=110&version=script)
- [FS25 Enterable](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=661&version=script)
- [FS25 PlayerInputComponent](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=69&class=600&version=engine)
- [FS25 SettingsModel](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=486&version=engine)
- [Offizielles FS25-Mod-Schema](https://validation.gdn.giants-software.com/xml/fs25/modDesc.xsd)
- [FS25-Handbuch](https://manuals.giants-software.com/Farming_Simulator_25/Basegame/lang/en/FS25-manual_EN.pdf)
- [Courseplay fuer FS25](https://github.com/Courseplay/Courseplay_FS25/blob/main/Courseplay.lua)
- [Offizieller ModHub: Radio Volume Hotkeys fuer FS25](https://www.farming-simulator.com/mod.php?country=cl&lang=en&mod_id=362183)

## Automatisches Einlesen

AGENTS.md im Repository-Stamm ist der gemeinsame Einstiegspunkt fuer Codex und kompatible VS-Code-Agenten. .github/copilot-instructions.md verweist fuer Copilot auf diese Datei. Die Workspace-Einstellungen aktivieren AGENTS.md, Copilot-Anweisungen und referenzierte Anweisungen im lokalen VS-Code-Chat.

Diese Vorgaben gelten in diesem Repository, nicht automatisch in jedem anderen LS25-Projekt. Nicht jede fremde KI-Erweiterung unterstuetzt diese Formate. Automatische Bereitstellung ist keine Garantie, dass ein Modell jede Regel befolgt. In einem neuen Chat die geladenen Anweisungen bei Bedarf ueber die References oder Chat-Customizations pruefen. Hierfuer kein nur bei Bedarf geladenes Skill als einzigen Einstiegspunkt verwenden.

- [OpenAI: AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [VS Code: Custom Instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
