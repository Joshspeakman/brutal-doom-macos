#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcode-select -p >/dev/null 2>&1 || { echo 'Install the Xcode Command Line Tools: xcode-select --install' >&2; exit 1; }
mkdir -p build
swiftc Sources/Model.swift Tests/ModelTests.swift -o build/model-tests
build/model-tests
app='build/Brutal Doom.app'
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -O -target arm64-apple-macosx11.0 Sources/Model.swift Sources/Theme.swift Sources/main.swift -o "$app/Contents/MacOS/BrutalDoomLauncher"
python3 - <<'PY'
import plistlib
from pathlib import Path
p=Path('build/Brutal Doom.app/Contents/Info.plist')
p.write_bytes(plistlib.dumps(dict(CFBundleName='Brutal Doom',CFBundleDisplayName='Brutal Doom',CFBundleIdentifier='local.joshuaspeakman.brutaldoom',CFBundleExecutable='BrutalDoomLauncher',CFBundlePackageType='APPL',CFBundleShortVersionString='1.2',CFBundleVersion='20261012.3',LSMinimumSystemVersion='11.0',NSHighResolutionCapable=True)))
PY
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
