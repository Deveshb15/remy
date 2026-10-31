#!/bin/zsh
# Promote a beta release to everyone: drop its beta channel in appcast.xml and mark the GitHub release as latest.
#   scripts/promote.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:?usage: scripts/promote.sh <version>}
[[ $(git branch --show-current) == main && -z $(git status --porcelain) ]] || { echo "clean main required"; exit 1; }
git pull --ff-only -q
python3 scripts/appcast.py promote --version "$VERSION"
gh release edit "v$VERSION" --prerelease=false --latest
git add appcast.xml && git commit -q -m "release: promote v$VERSION to everyone" && git push -q origin main
echo "Remy $VERSION is now live for everyone."
