# DXSpiderAdmin

Native macOS-App (SwiftUI) als grafische Schaltzentrale für den DXSpider-Cluster-Node
**HB9HJI-2**. Eigenständig, signierbar/notarisierbar und weitergebbar.

> Status: **M0–M5 abgeschlossen** (funktional vollständig, distributions-bereit).
> Offen: App-Icon, echte Notarisierung und Live-Test gegen den Node. Details unten und in
> [`docs/Konzeptdokument.md`](docs/Konzeptdokument.md).

## Überblick

- **Verbindung:** SSH + `console.pl` auf dem Node → volle Sysop-Rechte über einen
  einzigen, per SSH-Key gesicherten Kanal. Kein Telnet im MVP.
- **Kern:** [`Core/`](Core/) enthält das Swift Package `DXSpiderCore` (reine, testbare
  Logik: Modelle, Command-Builder, Parser, Verbindungs-Layer, Filter-Builder).
- **App:** [`App/`](App/) ist das SwiftUI-Target (macOS 26) mit vier Bereichen — Verbindung,
  User & Nodes, Command Builder und Filter-Editor — über ein gemeinsames ViewModel.
  Ein Demo-Backend macht die App ohne laufenden Server bedienbar.

## Roadmap

| Meilenstein | Inhalt | Status |
| :-- | :-- | :-- |
| **M0** | Fundament: Repo, Doku, testbares `DXSpiderCore`-Gerüst | ✅ |
| **M1** | Verbindungs-Layer (SSH+`console.pl`, Prompt-Erkennung, Read-only, Audit), App-Target, Settings-/Audit-Persistenz | ✅ |
| **M2** | User/Node-Verwaltung: Parsen, Tabelle, Suchfilter, Aktionen mit Bestätigung & Rate-Limiting | ✅ |
| **M3** | Command Builder inkl. Dry-Run-Preview | ✅ |
| **M4** | Visueller Filter-Editor (`SpotFilter`) mit Befehls-Vorschau | ✅ |
| **M5** | Polish & Distribution: Hardened Runtime, Developer-ID-Signierung, Notarisierung | ✅ Build-Setup |

Offene Punkte: App-Icon (1024 px), Notarisierung mit Developer-ID-Account
([`docs/Distribution.md`](docs/Distribution.md)) und Live-Test gegen HB9HJI-2 (Erfassen echter
Ausgabe-Formate zur Verfeinerung der Parser). Vollständige Historie: [`CHANGELOG.md`](CHANGELOG.md).

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

# App bauen (bzw. in Xcode öffnen und ⌘R)
cd ../App
xcodebuild -scheme DXSpiderAdmin -destination 'platform=macOS' build
```

Voraussetzungen: macOS 26+, Xcode 26.x / Swift 6.x.

Distribution (Developer ID + Notarisierung): siehe [`docs/Distribution.md`](docs/Distribution.md)
und [`scripts/notarize.sh`](scripts/notarize.sh).

## Projektstruktur

```
DXSpiderAdmin/
├─ docs/        Konzept & Dokumentation (inkl. Distribution.md)
├─ Core/        Swift Package "DXSpiderCore" (Logik + Tests)
├─ App/         SwiftUI-App-Target (DXSpiderAdmin.xcodeproj)
├─ scripts/     Notarisierungs-Skript & ExportOptions-Vorlage
├─ CHANGELOG.md
└─ README.md
```
