#!/usr/bin/env bash
#
# Baut aus der notarisierten App (App/build/export/DXSpiderAdmin.app) eine DMG mit
# "nach Programme ziehen"-Layout, signiert sie mit Developer ID, notarisiert und stapelt sie.
# Voraussetzung: vorher ./scripts/notarize.sh ausführen. Siehe docs/Distribution.md.
#
# Aufruf:
#   NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/build-dmg.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../App" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP="${BUILD_DIR}/export/DXSpiderAdmin.app"
STAGE="${BUILD_DIR}/dmg-stage"
: "${NOTARY_PROFILE:?Bitte NOTARY_PROFILE setzen (notarytool-Schlüsselbund-Profil)}"

if [[ ! -d "${APP}" ]]; then
  echo "Fehlt: ${APP} — bitte zuerst ./scripts/notarize.sh ausführen." >&2
  exit 1
fi

VERSION="$(defaults read "${APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "0.0")"
DMG="${BUILD_DIR}/DXSpiderAdmin-${VERSION}.dmg"

echo "==> Staging vorbereiten…"
rm -rf "${STAGE}" "${DMG}"
mkdir -p "${STAGE}"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

echo "==> DMG erstellen…"
hdiutil create -volname "DXSpider Admin" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}"

echo "==> DMG signieren…"
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')"
[[ -n "${IDENTITY}" ]] || { echo "Kein 'Developer ID Application'-Zertifikat gefunden." >&2; exit 1; }
codesign --force --sign "${IDENTITY}" --timestamp "${DMG}"

echo "==> DMG notarisieren (wartet auf Ergebnis)…"
xcrun notarytool submit "${DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "==> Ticket anheften…"
xcrun stapler staple "${DMG}"

rm -rf "${STAGE}"
echo "==> Fertig: ${DMG}"
spctl -a -t open --context context:primary-signature -vv "${DMG}" || true
