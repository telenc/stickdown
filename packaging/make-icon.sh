#!/bin/bash
# Génère packaging/AppIcon.icns à partir de icon.swift.
set -e
cd "$(dirname "$0")/.."

swift packaging/icon.swift
SRC=packaging/AppIcon-1024.png
SET=packaging/AppIcon.iconset
rm -rf "$SET"; mkdir -p "$SET"

for s in 16 32 128 256 512; do
    d=$((s * 2))
    sips -z "$s" "$s" "$SRC" --out "$SET/icon_${s}x${s}.png"     >/dev/null
    sips -z "$d" "$d" "$SRC" --out "$SET/icon_${s}x${s}@2x.png"  >/dev/null
done

iconutil -c icns "$SET" -o packaging/AppIcon.icns
rm -rf "$SET"
echo "✅ packaging/AppIcon.icns"
