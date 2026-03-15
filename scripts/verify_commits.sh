#!/usr/bin/env bash
set -euo pipefail

TARGET_COUNT="${1:-80}"
ACTUAL_COUNT="$(git rev-list --count HEAD)"

if [[ "$ACTUAL_COUNT" != "$TARGET_COUNT" ]]; then
  echo "commit count mismatch: expected $TARGET_COUNT, got $ACTUAL_COUNT" >&2
  exit 1
fi

echo "commit count: $ACTUAL_COUNT"
