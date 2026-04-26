#!/usr/bin/env bash
# Generates CHANGELOG.md locally and copies it into the iOS app's bundled
# resource location so the in-app Settings > Changelog screen shows it on
# the next build.
#
# Usage:
#   npm run changelog:local

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ROOT_CHANGELOG="$ROOT_DIR/CHANGELOG.md"
BUNDLED_CHANGELOG="$ROOT_DIR/src/Katsu/Resources/CHANGELOG.md"
HAD_ROOT_CHANGELOG=0
ROOT_CHANGELOG_BACKUP="$(mktemp -u -t katsu-changelog-backup.XXXXXX)"

cleanup() {
  if [[ "$HAD_ROOT_CHANGELOG" == "1" ]]; then
    if [[ -f "$ROOT_CHANGELOG_BACKUP" ]]; then
      mv "$ROOT_CHANGELOG_BACKUP" "$ROOT_CHANGELOG"
    fi
  else
    rm -f "$ROOT_CHANGELOG"
  fi
  rm -f "$ROOT_CHANGELOG_BACKUP"
}
trap cleanup EXIT

if [[ -f "$ROOT_CHANGELOG" ]]; then
  HAD_ROOT_CHANGELOG=1
  cp "$ROOT_CHANGELOG" "$ROOT_CHANGELOG_BACKUP"
fi

CHANGELOG_TITLE='# Changelog

All notable changes to Katsu are documented here. This file is generated automatically by [semantic-release](https://github.com/semantic-release/semantic-release) on each release.
'

echo "Generating local changelog from conventional commits..."

printf '%s\n' "$CHANGELOG_TITLE" >"$ROOT_CHANGELOG"

npx --yes -p conventional-changelog-cli@^5 conventional-changelog \
  -p angular \
  -r 0 \
  >>"$ROOT_CHANGELOG"

if grep -q '0.0.0-development' "$ROOT_CHANGELOG"; then
  python3 - "$ROOT_CHANGELOG" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()

text = re.sub(
    r"^# \[?0\.0\.0-development\]?(?:\([^)]*\))? \(([^)]+)\)",
    r"# Unreleased (\1)",
    text,
    flags=re.MULTILINE,
)

with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
PY
fi

if [[ ! -s "$ROOT_CHANGELOG" ]]; then
  echo "conventional-changelog produced no output." >&2
  exit 65
fi

echo "Copying generated CHANGELOG.md into $BUNDLED_CHANGELOG..."
cp "$ROOT_CHANGELOG" "$BUNDLED_CHANGELOG"

cat <<'EOF'

Done. Rebuild the iOS app to see the new changelog in Settings > Changelog.

Note: src/Katsu/Resources/CHANGELOG.md has been overwritten with the preview.
      Restore the dev placeholder when you're finished:

        git checkout src/Katsu/Resources/CHANGELOG.md

EOF
