#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIRED_V4_PERIPHERY_COMMIT="3779387e5d296f39df543d23524b050f89a62917"
V4_PERIPHERY_PATH="$ROOT_DIR/lib/uniswap-hooks/lib/v4-periphery"

cd "$ROOT_DIR"

echo "[bootstrap] Initializing submodules"
git submodule update --init --recursive

if [[ ! -d "$V4_PERIPHERY_PATH/.git" && ! -f "$V4_PERIPHERY_PATH/.git" ]]; then
  echo "[bootstrap] Missing path: $V4_PERIPHERY_PATH" >&2
  exit 1
fi

echo "[bootstrap] Pinning v4-periphery to $REQUIRED_V4_PERIPHERY_COMMIT"
git -C "$V4_PERIPHERY_PATH" fetch --all --tags --quiet
git -C "$V4_PERIPHERY_PATH" checkout "$REQUIRED_V4_PERIPHERY_COMMIT" >/dev/null

# Ensure nested dependency graph is deterministic from that commit.
git -C "$V4_PERIPHERY_PATH" submodule update --init --recursive

ACTUAL_V4_PERIPHERY_COMMIT="$(git -C "$V4_PERIPHERY_PATH" rev-parse HEAD)"
if [[ "$ACTUAL_V4_PERIPHERY_COMMIT" != "$REQUIRED_V4_PERIPHERY_COMMIT" ]]; then
  echo "[bootstrap] v4-periphery mismatch: expected $REQUIRED_V4_PERIPHERY_COMMIT, got $ACTUAL_V4_PERIPHERY_COMMIT" >&2
  exit 1
fi

echo "[bootstrap] Verifying lockfiles"
[[ -f "$ROOT_DIR/foundry.lock" ]] || { echo "[bootstrap] missing foundry.lock" >&2; exit 1; }
[[ -f "$ROOT_DIR/package-lock.json" ]] || { echo "[bootstrap] missing package-lock.json" >&2; exit 1; }

echo "[bootstrap] OK"
