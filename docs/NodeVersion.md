# Warum HB9HJI-2 „v1.55 build 823" meldet, obwohl 1.57 installiert ist

Geprüft am 13-Aug-2026, weil die Statuskachel eine ältere Version anzeigte als erwartet.

## Der Widerspruch

| Quelle | Wert |
| :-- | :-- |
| `show/version` (was der laufende Node meldet) | `DXSpider v1.55 (build 823 git: mojo/3e9b3621[r])` |
| `/spider/perl/Version.pm` (was installiert wurde) | `$version = '1.57'`, `$build = '46'`, `$gitversion = '855513b[i]'` |
| `git -C /spider describe --long --tags` | `1.55-823-g3e9b3621` |

## Die Erklärung

Läuft DXSpider aus einem Git-Arbeitsverzeichnis, ermittelt es die Version beim Start aus
`git describe` statt aus `Version.pm`. `git describe` nennt den **jüngsten erreichbaren Tag**
plus die Anzahl Commits danach — im EA3CV-Fork ist der neueste Tag `1.55`, gefolgt von 823
Commits ohne neuen Tag. Daraus wird „Version 1.55, Build 823".

Die gemeldete Zahl heisst also **„letzter Tag + Commits danach"**, nicht „Release 1.55".
Das `[r]` am Hash steht für die Repository-Ableitung, das `[i]` in `Version.pm` für den
Stand zum Installationszeitpunkt.

Nachbarnodes wie DA0BCC-7 („1.57 build: 633") sind Installationen **ohne** Git-Repo — sie
melden `Version.pm` unverändert. Ihre Build-Nummern sind darum nicht mit 823 vergleichbar:
verschiedene Zähler, nicht verschiedene Alter.

## Stand des Node (13-Aug-2026)

- Remote: `https://github.com/EA3CV/dx-spider.git`, Branch `mojo`
- Lokaler HEAD `3e9b3621` — **identisch mit `origin/mojo`**, also aktuell
- Letzter Commit im Fork: 05.07.2026 („update Changes file w.r.t shutdown")
- `Version.pm` geschrieben am 27.07.2026 (das Update)
- `cluster.pl` läuft seit 04.08.2026 — also **nach** dem Update, mit dem aktuellen Code

## Konsequenz für die App

`NodeStatus.gitVersion` hält Branch und Commit fest; sobald der Wert gesetzt ist, zeigt die
Version-Kachel ihn als zweite Zeile und erklärt per Tooltip
(`NodeStatus.versionCaveat`), woher die Nummer stammt. Die Kachel gibt damit weiterhin
wieder, was der Node meldet — ohne den Eindruck zu erwecken, die Installation sei veraltet.

## Selbst nachprüfen

```sh
ssh spider 'cat /spider/perl/Version.pm; git -C /spider describe --long --tags; \
            git -C /spider rev-parse HEAD; git -C /spider ls-remote origin refs/heads/mojo'
```
Stimmen HEAD und `ls-remote` überein, ist der Node auf dem Stand des Forks.
