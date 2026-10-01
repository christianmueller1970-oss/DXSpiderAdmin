#!/usr/bin/env bash
#
# Baut aus der notarisierten App (App/build/export/DXSpiderAdmin.app) eine DMG mit
# "nach Programme ziehen"-Layout, signiert sie mit Developer ID, notarisiert und stapelt sie.
# Danach signiert es die DMG für Sparkle und schreibt `appcast.xml` im Repo-Root neu
# (Release-Notes aus dem CHANGELOG-Abschnitt der Version). Veröffentlicht wird erst mit
# ./scripts/publish-release.sh. Voraussetzung: vorher ./scripts/notarize.sh ausführen.
# Siehe docs/Distribution.md.
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
echo "==> DMG fertig: ${DMG}"
spctl -a -t open --context context:primary-signature -vv "${DMG}" || true

# --- Sparkle: Update-Liste ---------------------------------------------------------
REPO_ROOT="$(cd "${PROJECT_DIR}/.." && pwd)"
REPO_URL="https://github.com/christianmueller1970-oss/DXSpiderAdmin"
SPARKLE_DIR="${BUILD_DIR}/sparkle"
# Sparkles Werkzeuge kommen mit dem Swift-Package; der Archiv-Build hat es aufgelöst.
SPARKLE_BIN="$(find "${BUILD_DIR}" "${HOME}/Library/Developer/Xcode/DerivedData" \
  -path '*artifacts/sparkle/Sparkle/bin/generate_appcast' 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)"
[[ -x "${SPARKLE_BIN}/generate_appcast" ]] || { echo "Sparkle-Werkzeuge nicht gefunden (Paket aufgelöst?)." >&2; exit 1; }

echo "==> Release-Notes aus CHANGELOG [${VERSION}]…"
rm -rf "${SPARKLE_DIR}" && mkdir -p "${SPARKLE_DIR}"
NOTES="${SPARKLE_DIR}/DXSpiderAdmin-${VERSION}.md"
awk -v v="${VERSION}" '
  $0 ~ "^## \\[" v "\\]" { found=1; next }
  found && /^## \[/ { exit }
  found { print }
' "${REPO_ROOT}/CHANGELOG.md" > "${NOTES}"
[[ -s "${NOTES}" ]] || { echo "CHANGELOG hat keinen Abschnitt ## [${VERSION}]." >&2; exit 1; }

echo "==> appcast.xml aktualisieren (signiert mit Schlüssel 'DXSpiderAdmin')…"
cp "${DMG}" "${SPARKLE_DIR}/"
[[ -f "${REPO_ROOT}/appcast.xml" ]] && cp "${REPO_ROOT}/appcast.xml" "${SPARKLE_DIR}/appcast.xml"
"${SPARKLE_BIN}/generate_appcast" \
  --account DXSpiderAdmin \
  --download-url-prefix "${REPO_URL}/releases/download/v${VERSION}/" \
  --full-release-notes-url "${REPO_URL}/releases/tag/v${VERSION}" \
  --link "${REPO_URL}" \
  --embed-release-notes \
  --maximum-deltas 0 \
  "${SPARKLE_DIR}"
cp "${SPARKLE_DIR}/appcast.xml" "${REPO_ROOT}/appcast.xml"
echo "==> appcast.xml geschrieben — veröffentlichen mit ./scripts/publish-release.sh"
