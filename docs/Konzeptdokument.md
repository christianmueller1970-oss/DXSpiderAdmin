# Konzeptdokument: DXSpiderAdmin (V4)

**Status:** Spezifikation / lebendes Dokument
**Plattform:** macOS (nativ, SwiftUI), Deployment-Ziel macOS 26+
**Zielsystem:** DXSpider Linux-Node **HB9HJI-2**
**Sprache:** Code & Bezeichner Englisch, Doku Deutsch

> Dieses Dokument ist die Weiterentwicklung des ursprünglichen Konzepts (V3, Python/Flet).
> Es wird gemeinsam mit `CHANGELOG.md` gepflegt und ist die maßgebliche Quelle für die Architektur.

---

## 1. Ziel

Eine eigenständige, native macOS-App als grafische Schaltzentrale (Control Panel) für den
DXSpider-Cluster-Node. Die App ist signiert/notarisiert und kann an andere Sysops
weitergegeben werden. Schwerpunkt: **robust, sicher, wartbar** — kein schneller Prototyp,
sondern ein dauerhaft betreibbares Werkzeug.

---

## 2. Grundsätze & harte Einschränkungen

Diese Regeln sind nicht verhandelbar und prägen jede Designentscheidung:

1. **Der DXSpider-Code wird niemals verändert.** Die App ist ein reiner Client.
2. **Die Verfügbarkeit/der Betrieb des Nodes wird niemals beeinträchtigt.**
3. **Es werden niemals Geheimnisse oder Einstellungen im Programm gespeichert.**
   Keine Zugänge, Keys, Passwörter oder Konfigurationswerte im App-Bundle.
   **Nichts davon gelangt jemals in Git.**
4. **Secrets bleiben beim Betriebssystem.** SSH-Key-Handling übernimmt ausschließlich
   das System (`/usr/bin/ssh`, `ssh-agent`, `~/.ssh`). Die App kennt keine Keys/Passwörter.
5. **Nicht-geheime Einstellungen** (Host, SSH-User, Port, console.pl-Pfad, Sysop-Call)
   liegen — falls überhaupt nötig — als lesbare Datei im **Dokumente-Ordner** des Users
   (`~/Documents/DXSpiderAdmin/settings.json`), nie im Bundle, nie im Repo.

**Daraus abgeleitete Schutzmechanismen in der App:**
- **Read-only-Default** beim Verbinden; schreibende Aktionen müssen aktiv freigeschaltet werden.
- **Bestätigungsdialog** für destruktive Befehle (`boot`, `set/priv`, `clear/spots`).
- **Rate-Limiting** beim Senden, damit keine Befehlsflut den Node belastet.
- **Command-Audit-Log** (lokal, im Dokumente-Ordner): jede gesendete Zeile wird protokolliert.
- **Dry-Run-Preview**: generierte Befehle werden angezeigt, bevor sie gesendet werden.

---

## 3. Architektur

```
┌───────────────────────────────────────────────┐
│  macOS-App (SwiftUI)                            │
│                                                 │
│   UI-Layer (Views, Sidebar, Tabs)               │
│        │                                        │
│   ViewModels (@Observable, MVVM)                │
│        │                                        │
│   DXSpiderCore  (reines Swift, testbar)         │
│     ├─ Models     (User, Node, Privilege)       │
│     ├─ Commands   (Command-Builder, sicher)     │
│     ├─ Parsing    (Textausgabe → Modelle)       │
│     └─ Connection (SysopChannel-Protokoll)      │
│        │                                        │
└────────┼────────────────────────────────────────┘
         │  Prozess-Aufruf
         ▼
   /usr/bin/ssh -tt user@host "/spider/perl/console.pl"
         │  (PTY, SSH-Key-Auth über System)
         ▼
   DXSpider-Node (HB9HJI-2)  →  Sysop-Konsole, Priv 9
```

**Begründung des Verbindungswegs (SSH + console.pl):**
- `console.pl` läuft auf dem Server als der spider-User und liefert **sofort volle
  Sysop-Rechte** — ohne Telnet, ohne sysop-Challenge-Response.
- **Nur ein Sicherheitskanal (SSH)**, Authentifizierung per Key über das System.
- Kein offener Telnet-Port nötig, keine Telnet-IAC-Aushandlung im Datenstrom.
- Telnet ist im MVP **nicht** vorgesehen (optionaler read-only-Pfad als spätere Ausbaustufe).

---

## 4. Verbindungs-Layer (Design)

Der fragile Ansatz aus V3 (`time.sleep()` + einzelnes `recv`) wird ersetzt durch:

- **Prozess-basierte Verbindung:** Die App startet `/usr/bin/ssh -tt <user>@<host>
  "<console.pl-Pfad>"` als Subprozess (`Process` + `Pipe`). Das `-tt` erzwingt ein PTY,
  das console.pl erwartet.
- **Asynchrones, kontinuierliches Lesen:** Ein dedizierter Reader liest den stdout-Strom
  zeilen-/chunkweise in einen Puffer (Swift Concurrency, `AsyncStream`/`for await`),
  statt auf feste Wartezeiten zu setzen.
- **Prompt-Erkennung als Trennsignal:** Antworten werden anhand des Cluster-Prompts
  (z.B. `HB9HJI de HB9HJI-2 ...>`) abgegrenzt, nicht über Timeouts.
- **Zustandsmaschine:** `disconnected → connecting → authenticating → ready → busy → error`.
- **Auto-Reconnect & Health-Indikator:** klar sichtbarer Verbindungsstatus, definierte
  Backoff-Strategie bei Verbindungsabriss.
- **Robustheit:** Timeouts, Abbruch (Task-Cancellation), saubere Prozess-Beendigung beim
  Schließen der Verbindung.

---

## 5. Datenmodell & Parsing

- **Modelle:** `ClusterUser`, `ClusterNode`, `PrivilegeLevel` (0–9), `ConnectionState`.
- **Parsing-Strategie:** DXSpider gibt freien Text in festen Spalten aus, der je nach
  Version variieren kann. Parser werden **tolerant** gebaut und gegen echte Ausgaben des
  HB9HJI-2 getestet (Fixtures). **Roh-Text-Fallback**, falls das Format unerwartet ist.
- **Tests:** Die Parser sind reine Funktionen (Text → Modell) und werden mit Unit-Tests
  abgesichert — der Kern bleibt ohne laufenden Server testbar.

---

## 6. UI-Struktur (macOS-nativ)

Feste linke **Sidebar** zur Navigation, Hauptbereich für Detailansichten
(`NavigationSplitView`).

| Bereich | UI-Elemente | DXSpider-Befehle (Hintergrund) |
| :-- | :-- | :-- |
| **Verbindung** | Profil-Auswahl, Verbindungsstatus, Read-only-Schalter, Audit-Log | (SSH/console.pl) |
| **User- & Node-Verwaltung** *(MVP)* | Datentabelle mit Suchfilter, Privilege-Dropdown, Node-Status-Toggle, „Station trennen" (rot, mit Bestätigung) | `show/users`, `show/nodes`, `set/priv <1-5> <call>`, `set/node <call>`, `boot <call>` |
| **Command Builder** *(später)* | Eingabemasken (z.B. Neuregistrierung), Status-Buttons, scrollbare Konsolen-Ausgabe | `set/register <call>`, `show/configuration`, `show/route <call>` |
| **Visueller Filter-Editor** *(später)* | Regel-Baukasten (Accept/Reject), Band-Checkboxen (HF/VHF/UHF), Origin-Felder, Vorschau des generierten Befehls | `accept/spots <n> <regel>`, `reject/spots <n> <regel>`, `clear/spots <n>` |

---

## 7. Roadmap / Meilensteine

- **M0 — Fundament:** Repo, Doku, Changelog, Memory, testbares `DXSpiderCore`-Gerüst. ✅
- **M1 — Verbindungs-Layer:** SSH+console.pl-Subprozess, async Reader, Prompt-Erkennung,
  Zustandsmaschine, manuelles Befehls-Senden mit Audit-Log + Read-only-Default, SwiftUI-App-
  Target, Settings-/Audit-Persistenz. ✅
- **M2 — User/Node-Verwaltung (MVP-Ziel):** `show/users`/`show/nodes` parsen, Tabelle,
  Suchfilter, Aktionen mit Bestätigung & Rate-Limiting. ✅
- **M3 — Command Builder** inkl. Dry-Run-Preview. ✅
- **M4 — Visueller Filter-Editor** (`SpotFilter`) inkl. Befehls-Vorschau. ✅
- **M5 — Polish & Distribution:** Hardened Runtime (Release), App-Sandbox-Entscheidung,
  Asset-Katalog, App-Versionsanzeige, Notarisierungs-Skript & Distributions-Doku. ✅

> **Alle geplanten Meilensteine (M0–M5) sind abgeschlossen.** Verbleibende Punkte sind
> betrieblicher/hardwaregebundener Natur und kein offener Entwicklungs-Scope mehr: App-Icon
> (1024 px) einlegen, echte Notarisierung mit Developer-ID-Account (`scripts/notarize.sh`)
> sowie der Live-Test gegen HB9HJI-2 zur Verfeinerung der Parser (siehe §10).

---

## 8. Tech-Stack & Projektstruktur

- **Swift 6.x / SwiftUI**, Xcode 26.x, Concurrency (`async/await`, `AsyncStream`).
- **`DXSpiderCore`** als Swift Package (reine Logik, ohne UI) → testbar & wiederverwendbar.
- **App-Target** als Xcode-Projekt (macOS 26+), bindet `DXSpiderCore` ein.

```
DXSpiderAdmin/
├─ docs/                  Konzept & Doku
├─ Core/                  Swift Package "DXSpiderCore" (Logik, Tests)
│  ├─ Package.swift
│  ├─ Sources/DXSpiderCore/
│  └─ Tests/DXSpiderCoreTests/
├─ App/                   (M1) Xcode-App-Target, SwiftUI
├─ CHANGELOG.md
└─ README.md
```

---

## 9. Distribution

- Apple-Developer-Account vorhanden → **Code-Signing + Notarisierung** für Gatekeeper.
- Auslieferung als notarisiertes `.app`, optional als DMG. Ablauf & Skript: `docs/Distribution.md`,
  `scripts/notarize.sh`.
- **Vertriebsweg: Developer ID (nicht App Store), Hardened Runtime AN, App-Sandbox AUS.**
  Begründung: Die App startet `/usr/bin/ssh` als Subprozess und nutzt `ssh-agent`/`~/.ssh` —
  das ist mit der strikten App-Sandbox unvereinbar; der Hardened Runtime ist für die
  Notarisierung Pflicht und erlaubt das Spawnen des System-`ssh` ohne Zusatz-Entitlement.
  Kein Zugriff auf Secrets nötig (System-SSH).

---

## 10. Offene Punkte

- Genaues Prompt-Format und Ausgabeformate des HB9HJI-2 (für Parser-Fixtures) erfassen —
  `ShowUsersParser`/`ShowNodesParser` und `SpotFilter`-Syntax danach verifizieren/verfeinern.
- ~~SSH-Aufruf in der Sandbox~~: **entschieden** — keine App-Sandbox, Developer ID +
  Hardened Runtime (siehe §9 / `docs/Distribution.md`).
- ~~Mapping der Filter-UI auf exakte DXSpider-Filter-Syntax~~: in `SpotFilter` umgesetzt
  (provisorisch, gegen den echten Node noch zu bestätigen).
- App-Icon (1024 px) in `Assets.xcassets/AppIcon.appiconset` einlegen.
