#!/usr/bin/env bash
#
# Confirm a release: tag the current commit as v<version> and push the tag,
# which triggers the Release workflow to publish the GitHub Release.
#
# Usage:
#   scripts/release.sh           # tag using the version in App/Info.plist
#   scripts/release.sh 1.2.0     # same, but assert Info.plist == 1.2.0 first
#
# Prerequisites (do these first, locally):
#   1. Bump CFBundleShortVersionString (and CFBundleVersion) in App/Info.plist.
#   2. Commit that change (and have it merged into the branch you tag).
#   3. Build + upload the same version to App Store Connect from Xcode.
#
# Tags are not affected by branch protection, so this works even though direct
# pushes to master require a PR.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PLIST_VERSION="$(scripts/plist-value.sh CFBundleShortVersionString)"
BUILD="$(scripts/plist-value.sh CFBundleVersion)"
VERSION="${1:-$PLIST_VERSION}"

if [[ "$VERSION" != "$PLIST_VERSION" ]]; then
  echo "error: requested version ($VERSION) != App/Info.plist ($PLIST_VERSION)." >&2
  echo "       Bump CFBundleShortVersionString and commit it first." >&2
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "error: version '$VERSION' is not a dotted numeric version (e.g. 1.2.0)." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean — commit the version bump first." >&2
  exit 1
fi

# Releases must be cut from master (its CI is green via branch protection), so the
# GitHub Releases page reflects shipped history — not feature-branch commits.
git fetch --no-tags --quiet origin master
if ! git merge-base --is-ancestor HEAD FETCH_HEAD; then
  echo "error: HEAD is not on origin/master — release only from master." >&2
  exit 1
fi

TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists locally." >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists on origin." >&2
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
SHA="$(git rev-parse --short HEAD)"
echo "About to release:"
echo "  version : $VERSION (build $BUILD)"
echo "  tag     : $TAG"
echo "  commit  : $SHA on $BRANCH"
echo
read -r -p "Create and push $TAG? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "aborted."; exit 1; }

git tag -a "$TAG" -m "Release $TAG (build $BUILD)"
git push origin "$TAG"

echo
echo "Pushed $TAG. The Release workflow will generate the changelog and publish"
echo "the GitHub Release. Track it at: Actions → Release."
