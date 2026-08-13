#!/bin/sh
# Nimmt eine Ansicht der App als PNG auf, um Layout-Fehler zu finden, die kein Compiler
# meldet (leere Bereiche, kollabierte Stacks). Startet eine eigene Debug-Instanz im
# Demo-Backend und fotografiert nur deren Fenster — eine laufende App bleibt unberührt.
#
#   ./scripts/uisnapshot.sh info [zieldatei.png]
#
# Bereich = rawValue aus SidebarItem: connection | info | users | commands | blocklists | filters
set -eu

AREA="${1:-info}"
# Optional: QUERY=show/node ./scripts/uisnapshot.sh info — führt die Abfrage gleich mit aus.
OUT="${2:-/tmp/dxspideradmin-$AREA.png}"
APP="$(cd "$(dirname "$0")/.." && pwd)/App/build/testbuild/Build/Products/Debug/DXSpiderAdmin.app"

[ -d "$APP" ] || { echo "Debug-Build fehlt: $APP" >&2; exit 1; }

"$APP/Contents/MacOS/DXSpiderAdmin" -uiSmokeTest "$AREA" ${QUERY:+-uiSmokeQuery "$QUERY"} &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT
sleep 5

# Fenster-ID dieser PID suchen und gezielt aufnehmen (kein Vollbild-Screenshot).
WID=$(python3 - "$PID" <<'PY'
import sys, Quartz
pid = int(sys.argv[1])
windows = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID) or []
best, area = None, 0
for w in windows:
    if w.get("kCGWindowOwnerPID") != pid:
        continue
    bounds = w.get("kCGWindowBounds", {})
    size = bounds.get("Width", 0) * bounds.get("Height", 0)
    if size > area:
        best, area = w.get("kCGWindowNumber"), size
print(best if best else "")
PY
)

[ -n "$WID" ] || { echo "Kein Fenster für PID $PID gefunden" >&2; exit 1; }
screencapture -x -o -l"$WID" "$OUT"
echo "$OUT"
