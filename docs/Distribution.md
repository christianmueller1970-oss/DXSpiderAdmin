# Distribution & Notarisierung (M5)

Diese Notiz beschreibt, wie aus DXSpiderAdmin ein signiertes, notarisiertes und
weitergebbares `.app` entsteht — und warum die Sicherheits­einstellungen so gewählt sind.

## Entscheidung: Developer ID, Hardened Runtime AN, App-Sandbox AUS

Die App startet das System-`/usr/bin/ssh` als **Subprozess** und ist auf `ssh-agent`/`~/.ssh`
angewiesen (Konzeptdokument §3/§4). Das ist mit der **strikten App-Sandbox unvereinbar**
(kein Spawnen externer Prozesse, kein Zugriff auf fremde Pfade). Gleichzeitig verlangt die
**Notarisierung den Hardened Runtime**.

Daraus folgt der Vertriebsweg:

| Aspekt | Wahl | Grund |
| :-- | :-- | :-- |
| Verteilung | **Developer ID** (außerhalb des Mac App Store) | App Store erzwingt Sandbox → unmöglich mit ssh-Subprozess |
| Hardened Runtime | **AN** (Release) | Pflicht für Notarisierung; Spawnen von `/usr/bin/ssh` ist erlaubt |
| App-Sandbox | **AUS** | Subprozess + `~/.ssh`/`ssh-agent` nicht sandbox-fähig |
| Secrets | bleiben beim System | Die App speichert nie Keys/Passwörter (Konzeptdokument §2) |

> Hinweis: Es werden **keine** zusätzlichen Hardened-Runtime-Ausnahmen (`com.apple.security.cs.*`)
> benötigt — das Starten eines signierten System-Binaries ist ohne Entitlement zulässig.

## Voraussetzungen (einmalig)

1. Apple-Developer-Account, Zertifikat **„Developer ID Application"** im Schlüsselbund.
2. Notarytool-Zugangsdaten als Schlüsselbund-Profil hinterlegen:
   ```sh
   xcrun notarytool store-credentials DXSpiderAdmin-Notary \
     --apple-id "deine@apple-id.example" \
     --team-id "DEINETEAMID" \
     --password "app-spezifisches-passwort"
   ```
3. In `scripts/ExportOptions.example.plist` `teamID` setzen und als `scripts/ExportOptions.plist`
   speichern (Letztere ist per `.gitignore` ausgeschlossen).

## Build + Notarisierung

```sh
TEAM_ID=DEINETEAMID NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/notarize.sh
```

Das Skript archiviert (Release, Hardened Runtime), exportiert mit Developer-ID-Signatur,
reicht das ZIP bei Apple ein (`--wait`) und heftet das Ticket an (`stapler staple`).
Ergebnis: `build/export/DXSpiderAdmin.app` — verteilbar (optional als DMG verpacken).

## Prüfen

```sh
codesign -dvvv build/export/DXSpiderAdmin.app   # flags müssen "runtime" enthalten
spctl -a -vvv build/export/DXSpiderAdmin.app    # "accepted, source=Notarized Developer ID"
```
