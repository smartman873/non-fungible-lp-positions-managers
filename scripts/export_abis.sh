#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
TARGET_DIR="$ROOT_DIR/shared/abis"

mkdir -p "$TARGET_DIR"

forge build >/dev/null

jq '.abi' "$OUT_DIR/FractionalLPHook.sol/FractionalLPHook.json" > "$TARGET_DIR/FractionalLPHook.json"
jq '.abi' "$OUT_DIR/LiquidityVault.sol/LiquidityVault.json" > "$TARGET_DIR/LiquidityVault.json"
jq '.abi' "$OUT_DIR/FractionalToken.sol/FractionalToken.json" > "$TARGET_DIR/FractionalToken.json"
jq '.abi' "$OUT_DIR/PositionNFT.sol/PositionNFT.json" > "$TARGET_DIR/PositionNFT.json"

echo "ABIs exported to $TARGET_DIR"
