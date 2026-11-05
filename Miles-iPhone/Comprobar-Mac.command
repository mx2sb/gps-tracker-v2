#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcodebuild -version; then
  echo 'Instala Xcode y selecciónalo en Xcode > Settings > Locations > Command Line Tools.'
  exit 1
fi
swift test
xcodebuild -project Miles.xcodeproj -scheme Miles -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
echo 'Compilación de simulador completada. Falta firmar e instalar en el iPhone desde Xcode.'
