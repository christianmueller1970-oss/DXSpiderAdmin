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
2. Notarytool-Zugangsdaten als Schlüsselbund-Profil hinterlegen — **eine** der beiden Varianten:

   **a) App-Store-Connect-API-Key** (empfohlen; der „App Key" `.p8` aus dem Dev-Account →
   Users and Access → Integrations → App Store Connect API):
   ```sh
   xcrun notarytool store-credentials DXSpiderAdmin-Notary \
     --key /pfad/AuthKey_XXXXXXXXXX.p8 \
     --key-id "XXXXXXXXXX" \
     --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```
   (Key-ID = Teil des Dateinamens; Issuer-ID steht oben auf der API-Keys-Seite.)

   **b) Apple-ID + app-spezifisches Passwort:**
   ```sh
   xcrun notarytool store-credentials DXSpiderAdmin-Notary \
     --apple-id "deine@apple-id.example" \
     --team-id "DEINETEAMID" \
     --password "app-spezifisches-passwort"
   ```

   > Zum **Signieren** ist zusätzlich ein Zertifikat **„Developer ID Application"** im
   > Schlüsselbund nötig (Dev-Account → Certificates). Das ist unabhängig vom Notary-Key.
3. In `scripts/ExportOptions.example.plist` `teamID` setzen und als `scripts/ExportOptions.plist`
   speichern (Letztere ist per `.gitignore` ausgeschlossen).

## Build + Notarisierung

```sh
TEAM_ID=DEINETEAMID NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/notarize.sh
```

Das Skript archiviert (Release, Hardened Runtime), exportiert mit Developer-ID-Signatur,
reicht das ZIP bei Apple ein (`--wait`) und heftet das Ticket an (`stapler staple`).
Ergebnis: `build/export/DXSpiderAdmin.app` — verteilbar.

## DMG bauen (optional, zum Weitergeben)

Nach `notarize.sh`:
```sh
NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/build-dmg.sh
```
Erzeugt `build/DXSpiderAdmin-<version>.dmg` mit „nach Programme ziehen"-Layout, signiert
sie mit Developer ID, notarisiert und stapelt das Ticket. Ergebnis ist Gatekeeper-konform
weitergebbar (auch offline).

## Automatische Updates (Sparkle 2)

Die App prüft über [Sparkle](https://sparkle-project.org) selbst auf neue Versionen
(Menü «DXSpider Admin → Nach Updates suchen …», zusätzlich automatisch im Hintergrund).

- **Update-Liste:** `appcast.xml` im Repo-Root, gelesen über
  `https://raw.githubusercontent.com/christianmueller1970-oss/DXSpiderAdmin/main/appcast.xml`
  (`SUFeedURL` in `App/Info.plist`). Das Repo ist öffentlich, damit das ohne Anmeldung geht.
- **Downloads:** die DMG als Anhang des GitHub-Releases `v<version>`.
- **Signatur:** Jede DMG wird zusätzlich mit einem EdDSA-Schlüssel signiert. Der private Teil
  liegt **nur im Schlüsselbund** (Konto `DXSpiderAdmin`, angelegt mit
  `generate_keys --account DXSpiderAdmin`), der öffentliche steht als `SUPublicEDKey` in
  `App/Info.plist`. Geht der private Schlüssel verloren, können bestehende Installationen
  keine Updates mehr annehmen → Sicherung exportieren
  (`generate_keys --account DXSpiderAdmin -x <datei>`) und ausserhalb des Repos verwahren.
- **Build-Nummer:** Sparkle vergleicht `CFBundleVersion` — vor jedem Release erhöhen.

### Release-Ablauf

1. `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` erhöhen, CHANGELOG-Abschnitt
   `## [<version>] — <datum>` schreiben, committen und nach `main` pushen.
2. `NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/notarize.sh`
3. `NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/build-dmg.sh` — schreibt zusätzlich
   `appcast.xml` (Release-Notes = CHANGELOG-Abschnitt).
4. `./scripts/publish-release.sh` — Tag, GitHub-Release mit DMG, danach `appcast.xml` pushen.

## Prüfen

```sh
codesign -dvvv build/export/DXSpiderAdmin.app   # flags müssen "runtime" enthalten
spctl -a -vvv build/export/DXSpiderAdmin.app    # "accepted, source=Notarized Developer ID"
```
