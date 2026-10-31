#!/bin/zsh
# Builds build/Remy.dmg. Uses Developer ID signing when a "Developer ID Application" identity for the
# project's team is in the keychain; otherwise a development-signed DMG that only runs on this Mac.
# Notarizes + staples when REMY_NOTARY_PROFILE names a `xcrun notarytool store-credentials` profile.
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
rm -rf "$ARCHIVE" "$EXPORT" "$DMG" build/dmg
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

mkdir -p build/dmg
ditto "$EXPORT/Remy.app" build/dmg/Remy.app
ln -s /Applications build/dmg/Applications
hdiutil create -volname Remy -srcfolder build/dmg -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

if [[ -n "${REMY_NOTARY_PROFILE:-}" && "$METHOD" == developer-id ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$REMY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

print "Built $DMG ($METHOD)"
