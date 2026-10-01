#!/usr/bin/env bash
#
# Veröffentlicht ein mit notarize.sh + build-dmg.sh gebautes Release:
#   1. Tag v<Version> setzen und pushen
#   2. GitHub-Release mit der DMG und den Release-Notes aus dem CHANGELOG anlegen
#   3. erst danach appcast.xml committen und pushen — so bietet Sparkle nie ein Update
#      an, dessen DMG noch nicht herunterladbar ist.
#
# Aufruf (auf main, nach build-dmg.sh):
#   ./scripts/publish-release.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/App/build"
APP="${BUILD_DIR}/export/DXSpiderAdmin.app"
cd "${REPO_ROOT}"

VERSION="$(defaults read "${APP}/Contents/Info" CFBundleShortVersionString)"
BUILD="$(defaults read "${APP}/Contents/Info" CFBundleVersion)"
TAG="v${VERSION}"
DMG="${BUILD_DIR}/DXSpiderAdmin-${VERSION}.dmg"
NOTES="${BUILD_DIR}/sparkle/DXSpiderAdmin-${VERSION}.md"

echo "==> Prüfe Release ${TAG} (Build ${BUILD})…"
[[ "$(git branch --show-current)" == "main" ]] || { echo "Bitte auf main veröffentlichen." >&2; exit 1; }
[[ -f "${DMG}" && -f "${NOTES}" ]] || { echo "DMG oder Release-Notes fehlen — zuerst build-dmg.sh." >&2; exit 1; }
grep -q "<sparkle:version>${BUILD}</sparkle:version>" appcast.xml \
  || { echo "appcast.xml kennt Build ${BUILD} nicht — zuerst build-dmg.sh." >&2; exit 1; }
if [[ -n "$(git status --porcelain -- . ':!appcast.xml')" ]]; then
  echo "Arbeitsverzeichnis nicht sauber (ausser appcast.xml)." >&2; exit 1
fi
if git ls-remote --exit-code --tags origin "${TAG}" >/dev/null 2>&1; then
  echo "Tag ${TAG} existiert schon auf GitHub." >&2; exit 1
fi
git fetch -q origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] \
  || { echo "main ist nicht synchron mit origin/main." >&2; exit 1; }

echo "==> Tag ${TAG} setzen und pushen…"
git tag -a "${TAG}" -m "DXSpiderAdmin ${VERSION} (Build ${BUILD})"
git push -q origin "${TAG}"

echo "==> GitHub-Release anlegen…"
gh release create "${TAG}" "${DMG}" --title "DXSpiderAdmin ${VERSION}" \
  --notes-file "${NOTES}" --verify-tag

echo "==> appcast.xml veröffentlichen…"
git add appcast.xml
git commit -q -m "Appcast: Version ${VERSION} (Build ${BUILD}) veröffentlicht"
git push -q origin main

echo "==> Fertig. Download-Test:"
curl -sL -o /dev/null -w "   DMG: HTTP %{http_code}\n" \
  "https://github.com/christianmueller1970-oss/DXSpiderAdmin/releases/download/${TAG}/DXSpiderAdmin-${VERSION}.dmg"
echo "   Hinweis: raw.githubusercontent.com cached die appcast.xml bis zu ~5 Minuten."
