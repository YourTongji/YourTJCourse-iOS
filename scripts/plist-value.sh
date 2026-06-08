#!/usr/bin/env bash
#
# Read a top-level key from a plist. Portable across macOS (plutil) and Linux
# (XML scrape), so it works both locally and in CI.
#
# Usage: scripts/plist-value.sh <Key> [plist]
#   Key    e.g. CFBundleShortVersionString
#   plist  default: App/Info.plist
set -euo pipefail

KEY="${1:?usage: plist-value.sh <Key> [plist]}"
PLIST="${2:-App/Info.plist}"

if command -v plutil >/dev/null 2>&1; then
  plutil -extract "$KEY" raw "$PLIST"
else
  awk -v key="$KEY" '
    $0 ~ "<key>" key "</key>" { found=1; next }
    found {
      line=$0
      sub(/^[[:space:]]*<(string|integer)>/, "", line)
      sub(/<\/(string|integer)>.*/, "", line)
      print line
      exit
    }
  ' "$PLIST"
fi
