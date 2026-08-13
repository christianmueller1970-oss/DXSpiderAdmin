# Node-Protokoll: Sysop-Console über den Console-Socket (Live-Befund §10)

Beim Live-Test gegen den echten Node (HB9HJI-2) stellte sich heraus:

> **Version:** Der Node läuft **DXSpider v1.55 (build 823)** auf Perl v5.36.0 — per
> `show/version` am 13-Aug-2026 bestätigt. Frühere Fassungen dieses Dokuments nannten
> V1.57; das sind die Nachbarnodes, nicht dieser. Welche Befehle verfügbar sind, hängt
> daran — siehe `docs/NodeQueries.md`.

## `console.pl` ist eine Curses-TUI — nicht direkt steuerbar

`/spider/perl/console.pl` benötigt zwingend ein Terminal (`use Curses; new Curses; raw()`),
nutzt Alternate-Screen + Cursor-Positionierung + Farben und **ohne PTY** bricht es ab
(„Error opening terminal"). Über ein PTY liefert es nur ANSI-/Cursor-Steuerzeichen statt
zeilenweisen Texts — für einen zeilenbasierten Kanal ungeeignet.

## Der echte, saubere Transport: der Console-Socket

`console.pl` ist nur ein TUI-Wrapper. Es verbindet sich mit dem DXSpider-Daemon über einen
**lokalen Socket** (Default `127.0.0.1:27754`, in DXVars als `$clusteraddr`/`$clusterport`).
Dieser Socket spricht ein **zeilenbasiertes Textprotokoll** und gewährt — wie console.pl —
**sofort Sysop-Rechte ohne Challenge** (genau die Prämisse aus Konzeptdokument §3).

Erreichbar gemacht wird er per SSH (z. B. lokaler Portforward `ssh -L` oder eine Bridge zum
Socket); die Auth bleibt wie gehabt System-SSH-Key.

### Wire-Format (jede Nachricht `\n`-terminiert)

**Client → Daemon:**
| Nachricht | Bedeutung |
| :-- | :-- |
| `A<CALL>\|local width=80 enhanced` | Attach/Anmeldung (einmalig nach Connect) |
| `I<CALL>\|<befehl>` | Befehlszeile senden, z. B. `I<CALL>\|show/users` |
| `C<CALL>\|<cols>` | Fensterbreite (optional) |

**Daemon → Client:** `<SORT><CALL>\|<textzeile>`
| SORT | Bedeutung | Verwendung |
| :-- | :-- | :-- |
| `D` | Anzeige-/Antwortzeile (Banner, Befehls-Output, Prompt) | **das parsen wir** |
| `X` | asynchroner Broadcast (DX-Spots, Announcements) | separater Feed, vom Befehls-Output trennen |
| `Z` | Ende/Disconnect | Verbindung schließen |

Der **Prompt** ist eine `D`-Zeile; nach Entfernen des `D<CALL>|`-Präfix lautet sie
`<CALL> de <NODE> <Datum> <Zeit>Z dxspider >` — das passt zur bestehenden
`PromptDetector`-Heuristik (` de ` + endet auf `>`).

### Beispiel `show/users` (Console-Format)
```
Callsigns connected to <NODE>
<CALL1>
<CALL2>
```
→ erste Zeile ist eine Kopfzeile (enthält den Node-Call); der `ShowUsersParser` muss diese
Kopfzeile überspringen, statt `<NODE>` als User zu werten.

## Konsequenzen für die App (offen, nächster Schritt)

1. **Neuer Transport** statt „console.pl über PTY": ein `SysopChannel`, der den Console-Socket
   spricht — SSH-Tunnel zu `127.0.0.1:27754`, Attach `A<call>|…`, Befehle `I<call>|…`,
   Empfang `<sort><call>|<zeile>`, Präfix strippen, nur `D` als Antwort werten, `X` als
   Spot-Feed routen, `Z` = Disconnect.
2. **`PromptDetector`** bleibt nutzbar (Prompt-Zeilenformat bestätigt).
3. **`ShowUsersParser`** an das echte Format anpassen (Kopfzeile überspringen); weitere
   Fixtures für `show/nodes` etc. erfassen.

> Datenschutz: Verbindungsdaten (Host/User/Port) liegen in `~/Documents/DXSpiderAdmin/settings.json`,
> nie im Repo. Live-Mitschnitte enthalten echte Rufzeichen → vor Repo-Fixtures anonymisieren.
