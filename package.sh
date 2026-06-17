#!/bin/bash
# Construit Stickdown.app (bundle macOS double-cliquable).
set -e
cd "$(dirname "$0")"
NAME=Stickdown

echo "▸ Build release…"
swift build -c release

APP="$NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp ".build/release/$NAME" "$APP/Contents/MacOS/$NAME"
cp packaging/Info.plist "$APP/Contents/Info.plist"
if [ -f packaging/AppIcon.icns ]; then
    cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Signature ad-hoc (utile pour SMAppService / Gatekeeper en local)
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "✅ $APP créé. Déplace-le dans /Applications puis double-clique."
