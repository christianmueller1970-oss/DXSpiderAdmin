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

### Entscheidungen
- Sprache: Swift / SwiftUI (Doku DE, Code EN), Ziel macOS 26+.
- Verbindung: SSH + `console.pl` (volle Sysop-Rechte), nur SSH-Key über System-SSH.
- MVP: Verbindungs-Layer + User/Node-Verwaltung.
- Harte Regel: keine Secrets/Einstellungen im Programm oder in Git; Settings ggf. lokal
  im Dokumente-Ordner.
