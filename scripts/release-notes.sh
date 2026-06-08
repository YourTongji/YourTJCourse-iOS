#!/usr/bin/env bash
#
# Generate Markdown release notes for a version.
#
# Produces two things the release page needs:
#   1. 概要 / Summary  — conventional commits grouped by type (tester-friendly).
#   2. 完整提交记录 / Full Changelog — every commit since the previous version.
#
# Usage:
#   scripts/release-notes.sh <version> [current_tag]
#     version      Marketing version without the leading "v", e.g. 1.2.0
#     current_tag  Tag being released. Default: v<version>
#
# The previous version is auto-detected as the most recent v* tag that is an
# ancestor of <current_tag>. If none exists, the notes cover the whole history.
#
# Repo slug for the compare link is read from $GITHUB_REPOSITORY, falling back to
# the origin remote.
set -euo pipefail

VERSION="${1:?usage: release-notes.sh <version> [current_tag]}"
CUR_TAG="${2:-v${VERSION}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- repo slug (owner/name) -------------------------------------------------
REPO_SLUG="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO_SLUG" ]]; then
  origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  # Strip a trailing .git, then everything up to and including the host part,
  # leaving owner/repo. Portable across macOS/BSD and GNU sed.
  REPO_SLUG="$(printf '%s' "$origin_url" | sed -E -e 's#\.git$##' -e 's#^.*github\.com[:/]##')"
fi

# --- build number (best effort) ---------------------------------------------
BUILD=""
if [[ -f App/Info.plist ]]; then
  BUILD="$("$SCRIPT_DIR/plist-value.sh" CFBundleVersion 2>/dev/null || true)"
fi

# --- previous tag / commit range --------------------------------------------
PREV_TAG="$(git describe --tags --abbrev=0 --match 'v*' "${CUR_TAG}^" 2>/dev/null || true)"
if [[ -n "$PREV_TAG" ]]; then
  RANGE="${PREV_TAG}..${CUR_TAG}"
else
  RANGE="$CUR_TAG"
fi

# --- collect + categorize commits -------------------------------------------
US=$'\x1f' # unit separator, safe field delimiter

feat=();  fix=();  perf=();  refactor=();  style=();  docs=();  test=();  chore=();  other=()
full=()
count=0

while IFS="$US" read -r hash subject author; do
  [[ -z "$hash" ]] && continue
  count=$((count + 1))
  full+=("- \`${hash}\` ${subject} — ${author}")

  # type(scope)!: description  -> type / scope / description
  type="$(printf '%s' "$subject" | sed -nE 's/^([a-zA-Z]+)(\([^)]*\))?!?:[[:space:]].*/\1/p' | tr '[:upper:]' '[:lower:]')"
  scope="$(printf '%s' "$subject" | sed -nE 's/^[a-zA-Z]+\(([^)]*)\)!?:[[:space:]].*/\1/p')"
  desc="$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]+//')"

  if [[ -n "$scope" ]]; then
    line="- **${scope}**: ${desc} (\`${hash}\`)"
  elif [[ -n "$type" ]]; then
    line="- ${desc} (\`${hash}\`)"
  else
    line="- ${subject} (\`${hash}\`)"
  fi

  case "$type" in
    feat)            feat+=("$line") ;;
    fix)             fix+=("$line") ;;
    perf)            perf+=("$line") ;;
    refactor)        refactor+=("$line") ;;
    style|ui)        style+=("$line") ;;
    docs)            docs+=("$line") ;;
    test)            test+=("$line") ;;
    build|ci|chore)  chore+=("$line") ;;
    *)               other+=("$line") ;;
  esac
done < <(git log --no-merges --pretty=format:"%h${US}%s${US}%an" "$RANGE")

# --- emit markdown ----------------------------------------------------------
header="版本 ${VERSION}"
[[ -n "$BUILD" ]] && header="${header}（Build ${BUILD}）"
header="${header} · 共 ${count} 处改动 · $(date +%Y-%m-%d)"

printf '# YourTJ Course v%s\n\n' "$VERSION"
printf '> %s\n\n' "$header"

printf '## 📋 概要 / Summary\n\n'

emit_group() {
  local title="$1"; shift
  local arr=("$@")
  [[ ${#arr[@]} -eq 0 ]] && return 0
  printf '### %s\n' "$title"
  printf '%s\n' "${arr[@]}"
  printf '\n'
}

emit_group "✨ 新增"        "${feat[@]+"${feat[@]}"}"
emit_group "🐛 修复"        "${fix[@]+"${fix[@]}"}"
emit_group "⚡️ 性能"        "${perf[@]+"${perf[@]}"}"
emit_group "♻️ 重构"        "${refactor[@]+"${refactor[@]}"}"
emit_group "💅 优化"        "${style[@]+"${style[@]}"}"
emit_group "📝 文档"        "${docs[@]+"${docs[@]}"}"
emit_group "✅ 测试"        "${test[@]+"${test[@]}"}"
emit_group "🔧 工程 / CI"   "${chore[@]+"${chore[@]}"}"
emit_group "📦 其他"        "${other[@]+"${other[@]}"}"

if [[ $count -eq 0 ]]; then
  printf '_自上个版本以来没有代码改动。_\n\n'
fi

printf '## 📝 完整提交记录 / Full Changelog\n\n'
if [[ ${#full[@]} -gt 0 ]]; then
  printf '%s\n' "${full[@]}"
else
  printf '_无提交。_\n'
fi
printf '\n'

printf '## 🔗 版本对比 / Compare\n\n'
if [[ -n "$PREV_TAG" ]]; then
  if [[ -n "$REPO_SLUG" ]]; then
    printf '`%s` → `%s`：https://github.com/%s/compare/%s...%s\n' \
      "$PREV_TAG" "$CUR_TAG" "$REPO_SLUG" "$PREV_TAG" "$CUR_TAG"
  else
    printf '`%s` → `%s`\n' "$PREV_TAG" "$CUR_TAG"
  fi
else
  printf '🎉 首次发布（无上一个版本作为基准）。\n'
fi
