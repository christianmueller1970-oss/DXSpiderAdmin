# DXSpiderAdmin

Native macOS-App (SwiftUI) als grafische Schaltzentrale für den DXSpider-Cluster-Node
**HB9HJI-2**. Eigenständig, signierbar/notarisierbar und weitergebbar.

> Status: **M0 – Fundament** (Setup, Doku, Core-Gerüst). Siehe Roadmap in
> [`docs/Konzeptdokument.md`](docs/Konzeptdokument.md).

## Überblick

- **Verbindung:** SSH + `console.pl` auf dem Node → volle Sysop-Rechte über einen
  einzigen, per SSH-Key gesicherten Kanal. Kein Telnet im MVP.
- **Kern:** [`Core/`](Core/) enthält das Swift Package `DXSpiderCore` (reine, testbare
  Logik: Modelle, Command-Builder, Parser). Die SwiftUI-App (`App/`) folgt in M1.

## Sicherheit & Datenschutz (verbindliche Grundsätze)

- Die App speichert **niemals** Zugänge, Keys, Passwörter oder Einstellungen im Programm.
- **Nichts davon gelangt jemals in Git.**
- SSH-Key-Handling übernimmt ausschließlich das System (`ssh-agent`, `~/.ssh`).
- Nicht-geheime Einstellungen liegen — falls nötig — lokal unter
  `~/Documents/DXSpiderAdmin/` und sind per `.gitignore` ausgeschlossen.
- Der DXSpider-Code wird nie verändert; der Node-Betrieb nie beeinträchtigt
  (Read-only-Default, Bestätigung destruktiver Befehle, Rate-Limiting, Audit-Log).

## Entwicklung

```bash
# Core-Logik bauen & testen (ohne laufenden Server)
cd Core
swift build
swift test
```

Voraussetzungen: macOS 26+, Xcode 26.x / Swift 6.x.

## Projektstruktur

```
DXSpiderAdmin/
├─ docs/        Konzept & Dokumentation
├─ Core/        Swift Package "DXSpiderCore" (Logik + Tests)
├─ App/         (ab M1) SwiftUI-App-Target
├─ CHANGELOG.md
└─ README.md
```
