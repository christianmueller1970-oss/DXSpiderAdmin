#!/usr/bin/env bash
#
# Archiviert, signiert (Developer ID), notarisiert und stapelt DXSpiderAdmin.
# Verteilung außerhalb des App Store, Hardened Runtime AN, keine App-Sandbox
# (die App startet /usr/bin/ssh als Subprozess) — siehe docs/Distribution.md.
#
# Voraussetzungen:
#   - Zertifikat "Developer ID Application" im Schlüsselbund
#   - notarytool-Profil (xcrun notarytool store-credentials …)
#   - scripts/ExportOptions.plist (aus ExportOptions.example.plist, teamID gesetzt)
#
# Aufruf:
#   NOTARY_PROFILE=DXSpiderAdmin-Notary ./scripts/notarize.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../App" && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
SCHEME="DXSpiderAdmin"
APP_NAME="DXSpiderAdmin.app"
ARCHIVE="${BUILD_DIR}/DXSpiderAdmin.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
ZIP_PATH="${BUILD_DIR}/DXSpiderAdmin.zip"
EXPORT_OPTIONS="${SCRIPTS_DIR}/ExportOptions.plist"
: "${NOTARY_PROFILE:?Bitte NOTARY_PROFILE setzen (notarytool-Schlüsselbund-Profil)}"

if [[ ! -f "${EXPORT_OPTIONS}" ]]; then
  echo "Fehlt: ${EXPORT_OPTIONS} — aus ExportOptions.example.plist erstellen und teamID setzen." >&2
  exit 1
fi

echo "==> Archiviere (Release, Hardened Runtime)…"
xcodebuild -project "${PROJECT_DIR}/DXSpiderAdmin.xcodeproj" \
  -scheme "${SCHEME}" -configuration Release \
  -archivePath "${ARCHIVE}" archive

echo "==> Exportiere mit Developer-ID-Signatur…"
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  -exportPath "${EXPORT_DIR}"

echo "==> Packe ZIP fürs Einreichen…"
/usr/bin/ditto -c -k --keepParent "${EXPORT_DIR}/${APP_NAME}" "${ZIP_PATH}"

echo "==> Reiche bei Apple ein (wartet auf Ergebnis)…"
xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait

echo "==> Hefte Notarisierungs-Ticket an…"
xcrun stapler staple "${EXPORT_DIR}/${APP_NAME}"

echo "==> Fertig: ${EXPORT_DIR}/${APP_NAME}"
codesign -dvvv "${EXPORT_DIR}/${APP_NAME}" 2>&1 | grep -E "Signature|flags" || true
spctl -a -vvv "${EXPORT_DIR}/${APP_NAME}" || true
