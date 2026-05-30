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

### Entscheidungen
- Sprache: Swift / SwiftUI (Doku DE, Code EN), Ziel macOS 26+.
- Verbindung: SSH + `console.pl` (volle Sysop-Rechte), nur SSH-Key über System-SSH.
- MVP: Verbindungs-Layer + User/Node-Verwaltung.
- Harte Regel: keine Secrets/Einstellungen im Programm oder in Git; Settings ggf. lokal
  im Dokumente-Ordner.
- App-Target vorerst **ohne App-Sandbox & ohne Hardened Runtime**, damit der
  `/usr/bin/ssh`-Subprozess in der Entwicklung funktioniert. Sandbox/Entitlements und
  Notarisierung werden in M5 entschieden (vgl. Konzeptdokument §9/§10).
