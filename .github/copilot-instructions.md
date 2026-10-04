# LS25Mods: gemeinsame Projektanweisungen

Vor jeder Aufgabe die vollstaendigen [Repo-Anweisungen und LS25-Erkenntnisse](../AGENTS.md) lesen und anwenden. AGENTS.md im Repository-Stamm ist die zentrale Quelle; keine abweichende zweite Wissenssammlung hier fuehren. Bei einer LS25-Mod-Aufgabe zusaetzlich die README des betroffenen Mods lesen.

Die wichtigsten Vorgaben gelten auch, wenn referenzierte Dateien noch nicht automatisch geladen wurden:

- Nur FS25-Schnittstellen verwenden und anhand echter FS25-Quellen pruefen; keine ungeprueften LS19-/LS22-Beispiele.
- Auf Deutsch schreiben. Keine typografischen Gedankenstriche U+2013 oder U+2014 verwenden. Nur normale ASCII-Bindestriche U+002D oder Formulierungen ohne Strich verwenden; keine dekorative KI-Typografie.
- Jeder Mod ist eigenstaendig: dist/, scripts/, tests/, tools/, Icondatei, modDesc.xml und README.md in seinem eigenen FS25_<Name>/-Ordner. Sinnvolle weitere Ordner und mehrere Dateien fuer groessere Mods anlegen.
- Keine modbezogenen tests/- oder tools/-Ordner im Repository-Stamm erstellen.
- Pro Mod ein Python-Build-Script in dessen tools/-Ordner pflegen. Es muss aus jedem Arbeitsverzeichnis dist/<ModOrdnername>.zip erzeugen, mit modDesc.xml unmittelbar in der ZIP-Wurzel und allen Laufzeitdateien, ohne Tests, Tools, Caches und Dokumentation.
- Benutzer-Aenderungen erhalten. Neue bestaetigte Erkenntnisse in AGENTS.md und passende Mod-Details in deren README pflegen.
- Nach Laufzeit-Aenderungen passende Pruefungen durchfuehren und das Mod-ZIP neu bauen. Nachgebildete Spielobjekte ersetzen keinen echten FS25-Spieltest. Den Pruefstatus ehrlich angeben.
