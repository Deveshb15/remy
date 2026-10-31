#!/bin/zsh
# Ship a Remy update end to end. Policy and checklist: docs/releasing.md
#
#   scripts/release.sh <version> <notes.md> [--beta] [--critical] [--phased-hours N] [--dry-run]
#
# Order matters: the GitHub release (with the DMG) is published BEFORE appcast.xml is pushed, so no user is ever
# offered an update whose download doesn't exist yet.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: scripts/release.sh <version> <notes.md> [--beta] [--critical] [--phased-hours N] [--dry-run]}
NOTES=${2:?release notes markdown file required}
shift 2
BETA=0 CRITICAL=0 PHASED=0 DRY=0
while (( $# )); do
  case $1 in
    --beta) BETA=1 ;; --critical) CRITICAL=1 ;; --dry-run) DRY=1 ;;
    --phased-hours) PHASED=$2; shift ;;
    *) echo "unknown option $1"; exit 64 ;;
  esac
  shift
done
export REMY_NOTARY_PROFILE=${REMY_NOTARY_PROFILE:-macd-notary}
SIGN_UPDATE=build/spm/artifacts/sparkle/Sparkle/bin/sign_update

# Preconditions
[[ -f $NOTES ]] || { echo "notes file $NOTES not found"; exit 66; }
[[ $VERSION =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo "version must look like 1.2.3"; exit 64; }
if (( ! DRY )); then
  [[ $(git branch --show-current) == main ]] || { echo "release from main"; exit 1; }
  [[ -z $(git status --porcelain) ]] || { echo "working tree must be clean"; exit 1; }
  git pull --ff-only -q
fi
CURRENT=$(awk -F'"' '/MARKETING_VERSION:/{print $2; exit}' project.yml)
BUILD=$(( $(awk -F'"' '/CURRENT_PROJECT_VERSION:/{print $2; exit}' project.yml) + 1 ))
[[ $(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1) == "$VERSION" && $CURRENT != "$VERSION" ]] \
  || { echo "version $VERSION must be greater than current $CURRENT"; exit 1; }

echo "==> Remy $CURRENT -> $VERSION (build $BUILD)"
sed -i '' -e "s/MARKETING_VERSION: \"$CURRENT\"/MARKETING_VERSION: \"$VERSION\"/" \
          -e "s/CURRENT_PROJECT_VERSION: \"$(( BUILD - 1 ))\"/CURRENT_PROJECT_VERSION: \"$BUILD\"/" project.yml

echo "==> Build, notarize, staple"
./scripts/make-dmg.sh
[[ -x $SIGN_UPDATE ]] || xcodebuild -resolvePackageDependencies -project Remy.xcodeproj -scheme Remy -clonedSourcePackagesDirPath build/spm -quiet
spctl -a -t open --context context:primary-signature build/Remy.dmg  # must be notarized Developer ID

echo "==> Sign update (EdDSA, keychain account 'remy')"
SIG_LINE=$($SIGN_UPDATE --account remy build/Remy.dmg)
SIGNATURE=$(sed -E 's/.*sparkle:edSignature="([^"]+)".*/\1/' <<< "$SIG_LINE")
LENGTH=$(sed -E 's/.*length="([0-9]+)".*/\1/' <<< "$SIG_LINE")
$SIGN_UPDATE --account remy --verify build/Remy.dmg "$SIGNATURE"

FLAGS=()
(( BETA )) && FLAGS+=(--beta)
(( CRITICAL )) && FLAGS+=(--critical)
(( PHASED )) && FLAGS+=(--phased-hours "$PHASED")
python3 scripts/appcast.py add --version "$VERSION" --build "$BUILD" --notes "$NOTES" --signature "$SIGNATURE" --length "$LENGTH" "${FLAGS[@]}"

if (( DRY )); then
  echo "==> Dry run: built and signed build/Remy.dmg; appcast.xml and project.yml are modified locally (not committed)."
  exit 0
fi

echo "==> Publish GitHub release (DMG first)"
GH_FLAGS=()
(( BETA )) && GH_FLAGS+=(--prerelease)
{ cat "$NOTES"; printf '\n\nSHA-256: `%s`\n' "$(shasum -a 256 build/Remy.dmg | cut -d' ' -f1)"; } > build/release-notes.md
gh release create "v$VERSION" build/Remy.dmg --title "Remy $VERSION" --notes-file build/release-notes.md --target main "${GH_FLAGS[@]}"

echo "==> Push appcast (this is what makes the update go live)"
git add project.yml appcast.xml
git commit -q -m "release: v$VERSION"
git push -q origin main
echo "==> Done. Remy $VERSION is live$( (( BETA )) && echo ' on the beta channel' )."
