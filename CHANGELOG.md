# Changelog

Alle nennenswerten Änderungen an DXSpiderAdmin. Format nach
[Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung nach [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Added
- Projekt-Setup (M0): Repository, `README.md`, `CHANGELOG.md`, `.gitignore`.
- Konzeptdokument V4 (`docs/Konzeptdokument.md`): Architektur SSH + `console.pl`,
  Sicherheits-/Datenschutzgrundsätze, UI-Struktur, Roadmap M0–M5.
- Swift Package `DXSpiderCore` (Gerüst): Modelle (`PrivilegeLevel`, `ClusterUser`,
  `ClusterNode`), `ConnectionState`, Command-Builder (`DXCommand`), `SysopChannel`-Protokoll,
  vorläufiger `ShowUsersParser` sowie erste Unit-Tests.
- M1 (Verbindungs-Layer, testbares Fundament): `PromptDetector` (Prompt-Erkennung als
  Trennsignal), `ResponseAccumulator` (kontinuierliches Puffern → vollständige Antwort),
  `ChannelMode` (Read-only-Default + Guard gegen destruktive Befehle), `CommandAuditLog`
  (`AuditEntry`/`AuditSink`/`InMemoryAuditLog` — jede gesendete Zeile, auch blockierte) und
  `InMemorySysopChannel` (vollständig testbarer Referenz-Kanal). `SysopChannel` um `state`
  erweitert. 12 neue Unit-Tests (gesamt 20, grün).
- M1 (echter SSH-Kanal): `SSHConnectionConfig` (nicht-geheime Verbindungsdaten + testbarer
  `ssh`-Argument-Builder, `BatchMode=yes` für Key-only) und `ProcessSysopChannel` — startet
  `/usr/bin/ssh -tt … console.pl` als Subprozess, liest stdout kontinuierlich asynchron über
  `ResponseAccumulator`/`PromptDetector`, setzt `ChannelMode`-Guard + Audit + Timeouts durch,
  beendet den Prozess sauber. Key-Auth bleibt vollständig beim System (`ssh-agent`/`~/.ssh`).
  5 neue Unit-Tests (gesamt 25, grün).
- M1 (App-Target): Xcode-Projekt `App/DXSpiderAdmin.xcodeproj` (macOS 26, SwiftUI,
  Synchronized-Groups-Format, lokales Package `../Core`). Erste UI nach Konzeptdokument §6
  „Verbindung": `DXSpiderAdminApp`, `ContentView` (Sidebar Verbindung/User), MVVM-
  `ConnectionViewModel` (`@Observable`, Demo- & SSH-Backend, Read-only-Schalter, Status,
  Audit-Log) und `ConnectionView` (Node-Felder, Konsole, manuelles Befehls-Senden,
  Status-Badge). Demo-Backend macht die App ohne Server bedienbar. Baut grün via
  `xcodebuild` (ad-hoc-signiert, lauffähig).
- M1 (Settings & Audit-Persistenz, schließt M1 ab): `AppSettings`/`SettingsStore` lädt &
  speichert die nicht-geheimen Verbindungsdaten als `~/Documents/DXSpiderAdmin/settings.json`
  (Verzeichnis injizierbar, testbar); `FileAuditLog` (AuditSink → `audit.log`) und
  `CompositeAuditSink` (Fan-out In-Memory + Datei). App lädt Settings beim Start, sichert sie
  beim SSH-Verbinden bzw. per Button und schreibt jede Befehlszeile zusätzlich in die
  Audit-Datei. 5 neue Unit-Tests (gesamt 30, grün).
- M2 (User- & Node-Verwaltung, MVP): geteiltes `Callsign`-Util, `ShowNodesParser`
  (tolerant, `show/nodes` → `[ClusterNode]` mit Verbindungs-Heuristik) und `RateLimiter`
  (Mindest-Abstand zwischen Befehlen, deterministisch testbar). App: `ManagementView` mit
  User-/Node-Listen, Suchfilter (`searchable`), Privilege-Menü und „Station trennen" — alle
  destruktiven Aktionen nur im Schreibmodus und mit Bestätigungsdialog. `ConnectionViewModel`
  um `users`/`nodes`, Filter, `refreshAll`/`refreshUsers`/`refreshNodes` und einen
  rate-limitierten `dispatch`-Pfad erweitert. 3 neue Unit-Tests (gesamt 33, grün).
- M3 (Command Builder): `DXCommand` um `unsetRegister` (Register-Toggle) erweitert.
  App: `CommandBuilderView` mit Eingabemasken für Registrierung (`set/register`/
  `unset/register`), read-only-Abfragen (`show/configuration`, `show/route <call>`) und
  freier Eingabe — jeweils mit **Dry-Run-Preview** des exakt erzeugten Befehls (§2),
  Bestätigung für destruktive Aktionen, Rufzeichen-Validierung und geteilter Konsolen-
  Ausgabe. Neuer Sidebar-Eintrag „Command Builder". 2 neue Unit-Tests (gesamt 35, grün).
- M4 (Visueller Filter-Editor): `SpotFilter` (Core) komponiert die DXSpider-Filterregel aus
  Aktion (accept/reject), Slot, Bändern (HF/VHF/UHF → `on …`), Spotter (`by`) und Origin —
  inkl. `command`/`clearCommand` und Token-Parser; die (laut §10 noch zu verifizierende)
  Syntax liegt damit an einer getesteten Stelle. App: `FilterEditorView` mit Band-Checkboxen,
  Stationsfeldern, Live-Befehls-Vorschau und Anwenden/Leeren (destruktiv → Bestätigung).
  Neuer Sidebar-Eintrag „Filter-Editor". 6 neue Unit-Tests (gesamt 41, grün).
- M5 (Polish & Distribution): **Hardened Runtime** im Release aktiviert (Signatur trägt das
  `runtime`-Flag), App-Sandbox bewusst **AUS** (ssh-Subprozess), Vertriebsweg **Developer ID**.
  Asset-Katalog (`AppIcon`-Slot + `AccentColor`) verdrahtet; App-Versionsanzeige in der
  Sidebar. Distributions-Doku `docs/Distribution.md`, Notarisierungs-Skript `scripts/notarize.sh`
  und `scripts/ExportOptions.example.plist`. Konzeptdokument-Roadmap (§7) auf M0–M4 ✅ /
  M5 ⏳ aktualisiert, Sandbox-Frage (§9/§10) entschieden.
- Live-Test-Vorbereitung: read-only-CLI `dxspider-capture` (Executable im Swift Package),
  das via `ProcessSysopChannel` verbindet und echte `show/*`-Ausgaben als Fixtures nach
  `~/Documents/DXSpiderAdmin/fixtures/` schreibt (Konfiguration aus `settings.json` oder
  Flags). Anleitung `docs/LiveTest.md`. Dient der Verifikation/Verfeinerung der Parser (§10).
- Live-Test gegen HB9HJI-2 durchgeführt (Befund in `docs/NodeProtocol.md`): `console.pl` ist
  eine **Curses-TUI** und als zeilenbasierter Kanal ungeeignet. Der saubere Transport ist der
  **DXSpider-Console-Socket** (`127.0.0.1:27754`): zeilenbasiertes Protokoll mit Attach
  `A<call>|…`, Befehl `I<call>|…` und Antworten `<sort><call>|<zeile>` (`D`=Ausgabe inkl.
  bestätigtem Prompt-Format, `X`=Spot-Broadcast, `Z`=Ende). Sysop-Rechte ohne Challenge.
  → Transport-Layer wird darauf umgestellt (nächster Schritt); `PromptDetector` passt bereits.
- `ConsoleSocketChannel` (neuer, echter Transport): spricht das Console-Socket-Protokoll über
  eine SSH+Perl-Bridge (`A<call>|…` Attach, `I<call>|…` Befehle), parst `<sort><call>|<zeile>`
  via `ConsoleProtocol`/`ConsoleMessage` (nur `D` als Antwort, `X`/`Z` separat), nutzt
  `ResponseAccumulator`/`PromptDetector`/`ChannelMode`/Audit weiter. App-Backend „SSH
  (Console-Socket)" + `dxspider-capture` umgestellt; Verbindungs-UI mit Sysop-Rufzeichen-Feld.
  **Live gegen HB9HJI-2 verifiziert** (volle Sysop-Konsole, `show/configuration`/`show/users`/
  `show/route`). 6 neue Unit-Tests (`ConsoleProtocol`), gesamt 47 grün.
- Kommando-/Parser-Anpassung an echtes DXSpider (Live-Befunde): `DXCommand.showNodes` von
  ungültigem `show/nodes` auf **`show/configuration/nodes`** korrigiert. `ShowNodesParser`
  überspringt eingerückte Fortsetzungszeilen (User-Listen) und wertet Nodes als verbunden,
  sofern nicht „disconnected". `ShowUsersParser` überspringt die Kopfzeile „Callsigns
  connected to <NODE>". Live verifiziert (Node-Tabelle), 2 neue Tests (gesamt 49 grün).
- App-Icon: vollständiger macOS-Icon-Satz (16–512 px @1x/@2x) aus dem gelieferten Motiv
  (Spinne/„DX"/Funk/Zahnrad) in `Assets.xcassets/AppIcon.appiconset`; kompiliert ohne Warnung
  als `AppIcon.icns`. `docs/Distribution.md` um die API-Key-Variante (`notarytool
  store-credentials --key …`) ergänzt.
- **Erster notarisierter Build** erstellt (`scripts/notarize.sh`): Developer-ID-signiert,
  Hardened Runtime, Apple-Notarisierung „Accepted", Ticket gestapelt, `spctl` „accepted —
  source=Notarized Developer ID". Die App ist damit weitergebbar (Gatekeeper-konform).
  `.gitignore` schützt zusätzlich `*.p8`/`AuthKey_*`.
- `scripts/build-dmg.sh`: baut aus der notarisierten App eine DMG („nach Programme ziehen"),
  signiert sie mit Developer ID, notarisiert und stapelt sie. Ergebnis live erzeugt:
  `DXSpiderAdmin-0.1.dmg` (Notarisierung „Accepted", `spctl` akzeptiert, Gatekeeper-konform).
- Registrierung anzeigen: read-only `DXCommand.showRegistered` → `show/registered` (am
  Node-Quellcode verifiziert — Anzeige heißt `registered` mit „ed", anders als die
  schreibenden `set/register`/`unset/register`). Neuer Button „Registrierte anzeigen" in der
  Sektion „Registrierung" des `CommandBuilderView` (read-only, daher ohne Bestätigung). 1
  neuer Unit-Test (gesamt 50 grün).

- Mehrfach-Registrierung & Bad-Spotter-Verwaltung im Command Builder: `set/register` und
  `unset/register` nehmen jetzt **mehrere** Rufzeichen (Leerzeichen-getrennt); neue Befehle
  `set/badspotter`/`unset/badspotter` (mehrere Calls, Node strippt SSID, priv ≥ 6) und
  read-only `show/badspotter`. UI: Registrierungs-Sektion mit Mehrfach-Feld; neue Sektion
  „Bad Spotter" (Sperren/Freigeben/Anzeigen). **Am Node-Quellcode verifiziert** (Live):
  `show/registered <arg>` macht **kein** Wildcard-Matching — Leerzeichen und `*` werden
  gestrippt, also nur *ein exaktes* Rufzeichen prüfbar (leer = alle); das Feld ist daher
  „Einzelnes Rufzeichen prüfen". `show/badspotter` ignoriert Argumente und listet immer alle.
  4 neue Unit-Tests (gesamt 54 grün).

- Durchsuchbare Registrierten-Liste & weitere Verwaltungsbefehle: neuer `ShowRegisteredParser`
  (Core) parst `show/registered` (Calls ohne `(level)`-Suffix, Status „Required/NOT Required").
  In „User & Nodes" neuer Tab **„Registriert"** mit Suchfeld (client-seitiger Filter — der Node
  kann kein Wildcard, siehe oben) und „Aufheben" je Zeile (mit Bestätigung). `ConnectionViewModel`
  um `registered`/`filteredRegistered`/`refreshRegistered()`/`unregister()` erweitert.
  Neue Befehle im Command Builder über eine wiederverwendbare `MultiCommandSection` (mehrere
  Einträge je Feld): **Lockout** (`set/unset/lockout`), **Bad Node**, **Bad DX**, **Bad Words**
  (`set/badword` nimmt Wörter statt Calls). **Live verifiziert:** `show/lockout` braucht ein
  Argument (`<call>|ALL`) → wir senden `show/lockout ALL`; die übrigen `show/bad…` ignorieren
  Argumente. 6 neue Unit-Tests (gesamt 59 grün).

### Fixed
- Antwort-Framing für geforkte Befehle (`spawn_cmd`, z. B. `show/registered`): Diese drucken
  am Console-Socket den **Prompt vor dem Output**, wodurch der bisherige prompt-basierte
  Abschluss eine leere Antwort lieferte und der eigentliche Output am *nächsten* Befehl klebte
  (Symptom: „erster Klick nichts, zweiter Klick zeigt es"). `ConsoleSocketChannel` schließt
  eine Antwort jetzt über ein kurzes Ruhefenster ab (`settleDelay`, Default 400 ms) und filtert
  alle Prompt-Zeilen heraus — beide Reihenfolgen (Output→Prompt und Prompt→Output) werden
  korrekt erfasst. Live am Socket mit Zeitstempeln verifiziert. 2 neue Unit-Tests (gesamt 52).

### Entscheidungen
- Sprache: Swift / SwiftUI (Doku DE, Code EN), Ziel macOS 26+.
- Verbindung: SSH + `console.pl` (volle Sysop-Rechte), nur SSH-Key über System-SSH.
- MVP: Verbindungs-Layer + User/Node-Verwaltung.
- Harte Regel: keine Secrets/Einstellungen im Programm oder in Git; Settings ggf. lokal
  im Dokumente-Ordner.
- App-Target vorerst **ohne App-Sandbox & ohne Hardened Runtime**, damit der
  `/usr/bin/ssh`-Subprozess in der Entwicklung funktioniert. Sandbox/Entitlements und
  Notarisierung werden in M5 entschieden (vgl. Konzeptdokument §9/§10).
