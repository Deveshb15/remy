#!/bin/zsh
# Builds build/Remy.dmg. Uses Developer ID signing when a "Developer ID Application" identity for the
# project's team is in the keychain; otherwise a development-signed DMG that only runs on this Mac.
# Notarizes + staples (app, then DMG) when REMY_NOTARY_PROFILE names a `xcrun notarytool store-credentials` profile,
# e.g. REMY_NOTARY_PROFILE=macd-notary ./scripts/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=$(awk '/DEVELOPMENT_TEAM:/{print $2; exit}' project.yml)
ARCHIVE=build/Remy.xcarchive
EXPORT=build/export
DMG=build/Remy.dmg

if security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($TEAM)"; then
  METHOD=developer-id
else
  METHOD=development
  print -P "%F{yellow}No Developer ID Application identity for team $TEAM: building a development DMG.%f"
  print -P "%F{yellow}It runs on this Mac only. Other Macs need a Developer ID build plus notarization.%f"
fi

xcodegen generate -q
rm -rf "$ARCHIVE" "$EXPORT" "$DMG" build/dmgart
xcodebuild -project Remy.xcodeproj -scheme Remy -configuration Release -archivePath "$ARCHIVE" \
  -clonedSourcePackagesDirPath build/spm -allowProvisioningUpdates archive -quiet

if [[ "$METHOD" == developer-id ]]; then
  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
    -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates -quiet
else
  # Free teams can't export; the archived app is already development-signed.
  mkdir -p "$EXPORT" && ditto "$ARCHIVE/Products/Applications/Remy.app" "$EXPORT/Remy.app"
fi

# Notarize + staple the app first, so it passes Gatekeeper offline even after being copied out of the DMG.
if [[ -n "${REMY_NOTARY_PROFILE:-}" && "$METHOD" == developer-id ]]; then
  ditto -c -k --keepParent "$EXPORT/Remy.app" build/Remy-app.zip
  xcrun notarytool submit build/Remy-app.zip --keychain-profile "$REMY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$EXPORT/Remy.app"
  rm -f build/Remy-app.zip
fi

# Window art (arrow + hint) at 1x/2x, then a laid-out DMG. dmgbuild writes Finder's view settings directly.
mkdir -p build/dmgart
swift scripts/dmg-background.swift build/dmgart
tiffutil -cathidpicheck build/dmgart/dmg-background.png build/dmgart/dmg-background@2x.png -out build/dmgart/background.tiff >/dev/null
uvx dmgbuild -s scripts/dmg-settings.py -D app="$EXPORT/Remy.app" -D background=build/dmgart/background.tiff Remy "$DMG" >/dev/null

if [[ "$METHOD" == developer-id ]]; then
  # Sign the disk image itself so Gatekeeper sees a Developer ID signature on the download, not just the app inside.
  IDENTITY=$(security find-identity -v -p codesigning | sed -n "s/.*\"\(Developer ID Application: .*($TEAM)\)\"/\1/p" | head -1)
  codesign --sign "$IDENTITY" --timestamp "$DMG"
fi

if [[ -n "${REMY_NOTARY_PROFILE:-}" && "$METHOD" == developer-id ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$REMY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

print "Built $DMG ($METHOD)"
