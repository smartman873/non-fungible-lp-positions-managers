#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRED_V4_PERIPHERY_COMMIT="3779387e5d296f39df543d23524b050f89a62917"
V4_PERIPHERY_PATH="$ROOT_DIR/lib/uniswap-hooks/lib/v4-periphery"

ACTUAL="$(git -C "$V4_PERIPHERY_PATH" rev-parse HEAD)"
if [[ "$ACTUAL" != "$REQUIRED_V4_PERIPHERY_COMMIT" ]]; then
  echo "v4-periphery commit mismatch: expected $REQUIRED_V4_PERIPHERY_COMMIT, got $ACTUAL" >&2
  exit 1
fi

[[ -f "$ROOT_DIR/foundry.lock" ]] || { echo "missing foundry.lock" >&2; exit 1; }
[[ -f "$ROOT_DIR/package-lock.json" ]] || { echo "missing package-lock.json" >&2; exit 1; }

echo "dependency integrity: PASS"
