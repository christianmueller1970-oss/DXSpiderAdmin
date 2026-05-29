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

### Entscheidungen
- Sprache: Swift / SwiftUI (Doku DE, Code EN), Ziel macOS 26+.
- Verbindung: SSH + `console.pl` (volle Sysop-Rechte), nur SSH-Key über System-SSH.
- MVP: Verbindungs-Layer + User/Node-Verwaltung.
- Harte Regel: keine Secrets/Einstellungen im Programm oder in Git; Settings ggf. lokal
  im Dokumente-Ordner.
