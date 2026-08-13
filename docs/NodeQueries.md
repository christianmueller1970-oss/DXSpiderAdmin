# Abfrage-Katalog: was HB9HJI-2 wirklich beantwortet

Grundlage für den Bereich **Info & Diagnose** und für `NodeQuery.all`. Jeder Kandidat wurde
am **13-Aug-2026** einmal read-only über den Console-Socket gesendet und die Antwort
protokolliert; aufgenommen wurde nur, was der Node tatsächlich beantwortet hat.

> **Wichtig:** Der Node läuft **DXSpider v1.55 (build 823)**, Perl v5.36.0 — nicht v1.57, wie
> in einer früheren Fassung von `NodeProtocol.md` stand. Die Nachbarnodes melden 1.57; der
> eigene Build ist älter, und genau daran hängt, welche Befehle es gibt.

## Aufgenommen

| Gruppe | Befehl | Argument | Bemerkung |
| :-- | :-- | :-- | :-- |
| Laufzeit | `show/cluster` | – | Nodes, User, Tagesmaximum, Uptime — Basis der Status-Kacheln |
| Laufzeit | `show/version` | – | Version, Build, Perl |
| Laufzeit | `show/time` | Präfix (optional) | Lokalzeit + UTC |
| Laufzeit | `show/motd` | – | Begrüssungstext |
| Laufzeit | `show/connect` | – | alle Kanäle mit IP/Port/Richtung — **Argument wird ignoriert** |
| Laufzeit | `stat/channel` | – | ~140 Zeilen Dump des eigenen Kanals |
| Laufzeit | `show/program` | – | ~80 Zeilen Modulpfade |
| Laufzeit | `show/debug` | – | aktive Debug-Kanäle |
| Laufzeit | `stat/msg` | – | Work-/Busy-Queue, im Normalbetrieb leer |
| User/Nodes | `stat/user` | Call (Pflicht) | kompletter DXUser-Datensatz |
| User/Nodes | `show/station` | Call (Pflicht) | Kurzprofil |
| User/Nodes | `stat/route_user` | Call (Pflicht) | Parent-Node, IP, Zonen |
| User/Nodes | `stat/route_node` | Node (Pflicht) | Nachbarn, Obscount, letzter PC92C |
| User/Nodes | `show/node` | – | Nodes mit Sort und Build |
| User/Nodes | `show/isolate` | – | „0 records" im Normalfall |
| User/Nodes | `show/hops` | Node (Pflicht) | Hop-Count für Spots |
| User/Nodes | `ping` | Node (Pflicht) | **nicht** `show/ping`; sendet ein Paket zum Nachbarn |
| Konfig | `show/configuration` | – | Nodes mit User-Listen |
| Konfig | `show/configuration/nodes` | – | nur Node-Ebene |
| Konfig | `show/newconfiguration` | – | Netz-Baum, **~500 Zeilen** |
| Konfig | `show/filter` | – | eigene Spot-Filter |
| Logs | `show/log` | Anzahl (optional) | Systemlog, letzte n Zeilen |
| Logs | `show/log <call>` | Call (Pflicht) | Logzeilen zu einem Rufzeichen |
| Logs | `show/dxstats` | – | Spots pro Tag, 31 Tage |
| Logs | `show/hfstats` / `show/vhfstats` | – | Spots pro Tag und Band |
| Logs | `show/hftable` / `show/vhftable` | – | Top-Spotter im eigenen DXCC (~100 Zeilen) |
| Betrieb | `show/dx` | Anzahl (optional) | letzte Spots |
| Betrieb | `show/announce` | Anzahl (optional) | letzte Ansagen |
| Betrieb | `show/chat` | Anzahl (optional) | Chat-Verkehr |
| Betrieb | `show/wwv` / `show/wcy` | Anzahl (optional) | Propagationsdaten |
| Betrieb | `show/muf` | Präfix (Pflicht) | MUF-Vorhersage |
| Betrieb | `show/dxcc` | Präfix (Pflicht) | Spots eines Landes |
| Betrieb | `show/prefix` | Call (Pflicht) | Land, Zonen, Locator |
| Betrieb | `show/qra` | Locator (Pflicht) | Entfernung/Richtung |
| Betrieb | `show/sun` / `show/moon` | Call (Pflicht) | Auf-/Untergang, Azimut, Elevation |

`show/uptime` liefert wortgleich dieselbe Zeile wie `show/cluster` und ist deshalb **nicht**
separat im Katalog.

## Nicht aufgenommen (Antwort des Node in Klammern)

- `show/ping` (*Unknown command*) — die funktionierende Form ist `ping <node>`
- `show/configuration/users`, `show/configuration/user` (*Unknown command*)
- `show/email`, `show/dupefile`, `show/mrtg`, `show/qsl` (*Unknown command*)
- `show/files` (*show/files: not found*)
- `show/qrz` (*Sorry, Internet access is not enabled*) — braucht freigeschalteten Internetzugang
- `stat/db` (*Need a Message number*) — die Argumentform ist unklar, kein Nutzen ohne sie
- `show/startup <call>` — **leere Antwort**, weder Fehler noch Inhalt; wäre in der UI nicht von
  einem Fehler zu unterscheiden

## Methodik, zum Nachstellen

Ein Perl-Einzeiler auf dem Node verbindet sich mit `127.0.0.1:27754`, attached als
`A<CALL>|local width=80 enhanced`, sendet je Kandidat `I<CALL>|<befehl>` und sammelt die
`D`-Zeilen, bis für einige Sekunden Ruhe herrscht (`X`-Broadcasts werden verworfen).

**Stolperfalle:** Das Ruhefenster muss zur längsten Antwort passen. Im ersten Lauf lief
`show/newconfiguration` (~500 Zeilen) in die drei folgenden Befehle über und liess sie
falsch aussehen — mit 6 s Ruhefenster und einem Verwerf-Durchlauf vor jedem Befehl war das
Ergebnis sauber. Derselbe Effekt ist der Grund für den `settleDelay` im
`ConsoleSocketChannel`.
