# Live-Test gegen HB9HJI-2 (§10)

Ziel: den `ProcessSysopChannel` einmal gegen den echten Node fahren und die echten
Ausgabe-Formate erfassen, um `ShowUsersParser`, `ShowNodesParser` und die `SpotFilter`-Syntax
zu verifizieren/verfeinern. Dafür gibt es das read-only-CLI **`dxspider-capture`**.

## Vorbereitung

1. **SSH-Key in den Agent laden** (der Kanal nutzt `BatchMode=yes`, also keine interaktive
   Passphrase-Abfrage):
   ```sh
   ssh-add ~/.ssh/id_ed25519
   ssh-add -l            # sollte den Key jetzt listen
   ```
2. **Erreichbarkeit prüfen** (einmalig, akzeptiert ggf. den Host-Key):
   ```sh
   ssh -p <PORT> <USER>@<HOST> true
   ```
3. **Verbindungsdaten** entweder in der App unter „Verbindung“ → „Einstellungen sichern“
   ablegen (schreibt `~/Documents/DXSpiderAdmin/settings.json`) **oder** unten als Flags
   übergeben.

## Ausführen

```sh
cd Core
# nutzt settings.json:
swift run dxspider-capture --route HB9HJI
# oder vollständig per Flags:
swift run dxspider-capture --host <HOST> --user <USER> --port <PORT> \
  --console /spider/perl/console.pl --route HB9HJI
```

Erfasst read-only: `show/configuration`, `show/users`, `show/nodes` und optional
`show/route <CALL>`. Jede Antwort wird nach `~/Documents/DXSpiderAdmin/fixtures/<name>.txt`
geschrieben und auf der Konsole ausgegeben.

## Danach

- Formate sichten und Parser anpassen (z. B. `show/users` real mit Name/Priv/Registered).
- **Datenschutz:** Die Fixtures enthalten echte Rufzeichen und liegen bewusst **außerhalb des
  Repos**. Vor dem Anlegen von Test-Fixtures im Repo anonymisieren (Rufzeichen ersetzen).
