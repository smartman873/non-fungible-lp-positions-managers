#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
DEPLOY_SCRIPT="script/00_DeployFractionalSystem.s.sol:DeployFractionalSystemScript"
DEMO_SCRIPT="script/02_DemoUnichainLifecycle.s.sol:DemoUnichainLifecycleScript"
EXPECTED_CHAIN_ID="1301"
EXPLORER_BASE_DEFAULT="https://sepolia.uniscan.xyz"
DEFAULT_GAS_PRICE="1gwei"

DEFAULT_USER_A_PK="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
DEFAULT_USER_B_PK="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"

log() {
  printf "\n[%s] %s\n" "$(date -u +%H:%M:%S)" "$*"
}

die() {
  printf "\n[error] %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

load_env() {
  [[ -f "$ENV_FILE" ]] || die ".env file not found at $ENV_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

require_var() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "missing required env var: $name"
}

upsert_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    perl -i -pe "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf "%s=%s\n" "$key" "$value" >>"$ENV_FILE"
  fi
}

has_code() {
  local addr="$1"
  local code
  code="$(cast code "$addr" --rpc-url "$RPC_URL" 2>/dev/null || true)"
  [[ -n "$code" && "$code" != "0x" ]]
}

normalize_pk() {
  local pk="$1"
  if [[ "$pk" == 0x* ]]; then
    printf "%s" "$pk"
  else
    printf "0x%s" "$pk"
  fi
}

random_pk() {
  printf "0x%s" "$(openssl rand -hex 32)"
}

resolve_eoa_pk() {
  local pk="$1"
  local label="$2"
  local addr

  pk="$(normalize_pk "$pk")"
  while :; do
    addr="$(cast wallet address --private-key "$pk")"
    if ! has_code "$addr"; then
      printf "%s" "$pk"
      return 0
    fi
    log "$label key resolves to contract address onchain ($addr), generating fresh EOA demo key" >&2
    pk="$(random_pk)"
  done
}

ensure_demo_user_keys() {
  local pk_a pk_b addr_a addr_b

  pk_a="$(resolve_eoa_pk "${USER_A_PRIVATE_KEY:-$DEFAULT_USER_A_PK}" "user A")"
  addr_a="$(cast wallet address --private-key "$pk_a")"

  pk_b="$(resolve_eoa_pk "${USER_B_PRIVATE_KEY:-$DEFAULT_USER_B_PK}" "user B")"
  addr_b="$(cast wallet address --private-key "$pk_b")"

  while [[ "$addr_a" == "$addr_b" ]]; do
    pk_b="$(resolve_eoa_pk "$(random_pk)" "user B")"
    addr_b="$(cast wallet address --private-key "$pk_b")"
  done

  DEMO_USER_A_PK="$pk_a"
  DEMO_USER_B_PK="$pk_b"

  upsert_env "USER_A_PRIVATE_KEY" "$DEMO_USER_A_PK"
  upsert_env "USER_B_PRIVATE_KEY" "$DEMO_USER_B_PK"
  export USER_A_PRIVATE_KEY="$DEMO_USER_A_PK"
  export USER_B_PRIVATE_KEY="$DEMO_USER_B_PK"
}

print_tx_urls() {
  local json_file="$1"
  local heading="$2"
  local explorer_base="${UNICHAIN_EXPLORER_URL:-$EXPLORER_BASE_DEFAULT}"

  [[ -f "$json_file" ]] || die "broadcast file not found: $json_file"

  log "$heading transactions"
  jq -r '
    .transactions[]
    | [
        (.transactionType // "CALL"),
        (.contractName // "-"),
        (.function // "-"),
        (.hash // .transactionHash // ""),
        (.contractAddress // "-")
      ]
    | @tsv
  ' "$json_file" | while IFS=$'\t' read -r tx_type contract_name fn_sig tx_hash contract_addr; do
    [[ -n "$tx_hash" ]] || continue
    printf " - %-6s %-22s %-38s %s/tx/%s\n" \
      "$tx_type" "$contract_name" "$fn_sig" "$explorer_base" "$tx_hash"
    if [[ ( "$tx_type" == "CREATE" || "$tx_type" == "CREATE2" ) && "$contract_addr" != "-" ]]; then
      printf "   contract: %s\n" "$contract_addr"
    fi
  done
}

parse_deployment_addresses() {
  local deploy_json="$1"
  VAULT_ADDRESS="$(jq -r '.transactions[] | select(.transactionType=="CREATE" and .contractName=="LiquidityVault") | .contractAddress' "$deploy_json" | tail -n1)"
  HOOK_ADDRESS="$(jq -r '.transactions[] | select((.transactionType=="CREATE" or .transactionType=="CREATE2") and .contractName=="FractionalLPHook") | .contractAddress' "$deploy_json" | tail -n1)"

  [[ -n "$VAULT_ADDRESS" && "$VAULT_ADDRESS" != "null" ]] || die "failed to parse VAULT_ADDRESS from deployment run"
  [[ -n "$HOOK_ADDRESS" && "$HOOK_ADDRESS" != "null" ]] || die "failed to parse HOOK_ADDRESS from deployment run"

  TOKEN0_ADDRESS="$(cast call "$VAULT_ADDRESS" "token0()(address)" --rpc-url "$RPC_URL")"
  TOKEN1_ADDRESS="$(cast call "$VAULT_ADDRESS" "token1()(address)" --rpc-url "$RPC_URL")"
  SHARE_TOKEN_ADDRESS="$(cast call "$VAULT_ADDRESS" "shareToken()(address)" --rpc-url "$RPC_URL")"
  POSITION_NFT_ADDRESS="$(cast call "$VAULT_ADDRESS" "positionNFT()(address)" --rpc-url "$RPC_URL")"
}

needs_deployments() {
  [[ -z "${TOKEN0_ADDRESS:-}" || -z "${TOKEN1_ADDRESS:-}" || -z "${VAULT_ADDRESS:-}" || -z "${HOOK_ADDRESS:-}" ]] && return 0
  has_code "$TOKEN0_ADDRESS" || return 0
  has_code "$TOKEN1_ADDRESS" || return 0
  has_code "$VAULT_ADDRESS" || return 0
  has_code "$HOOK_ADDRESS" || return 0
  return 1
}

summarize_onchain_state() {
  local user_a_address="$1"
  local user_b_address="$2"

  local vault_value share_price total_supply user_a_shares user_b_shares vault_bal0 vault_bal1
  vault_value="$(cast call "$VAULT_ADDRESS" "totalVaultValue()(uint256)" --rpc-url "$RPC_URL")"
  share_price="$(cast call "$VAULT_ADDRESS" "sharePriceX96()(uint256)" --rpc-url "$RPC_URL")"
  total_supply="$(cast call "$SHARE_TOKEN_ADDRESS" "totalSupply()(uint256)" --rpc-url "$RPC_URL")"
  user_a_shares="$(cast call "$SHARE_TOKEN_ADDRESS" "balanceOf(address)(uint256)" "$user_a_address" --rpc-url "$RPC_URL")"
  user_b_shares="$(cast call "$SHARE_TOKEN_ADDRESS" "balanceOf(address)(uint256)" "$user_b_address" --rpc-url "$RPC_URL")"
  vault_bal0="$(cast call "$TOKEN0_ADDRESS" "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "$RPC_URL")"
  vault_bal1="$(cast call "$TOKEN1_ADDRESS" "balanceOf(address)(uint256)" "$VAULT_ADDRESS" --rpc-url "$RPC_URL")"

  log "judge summary"
  printf " - vault value:          %s\n" "$vault_value"
  printf " - share price X96:      %s\n" "$share_price"
  printf " - share total supply:   %s\n" "$total_supply"
  printf " - user A shares:        %s\n" "$user_a_shares"
  printf " - user B shares:        %s\n" "$user_b_shares"
  printf " - vault token0 balance: %s\n" "$vault_bal0"
  printf " - vault token1 balance: %s\n" "$vault_bal1"
}

main() {
  require_cmd forge
  require_cmd cast
  require_cmd jq
  require_cmd perl
  require_cmd openssl

  load_env
  require_var SEPOLIA_PRIVATE_KEY

  RPC_URL="${UNICHAIN_SEPOLIA_RPC_URL:-${SEPOLIA_RPC_URL:-}}"
  [[ -n "$RPC_URL" ]] || die "missing RPC URL: set UNICHAIN_SEPOLIA_RPC_URL or SEPOLIA_RPC_URL"
  GAS_PRICE="${TX_GAS_PRICE:-$DEFAULT_GAS_PRICE}"

  local chain_id owner_address expected_owner
  local owner_address_lc expected_owner_lc
  chain_id="$(cast chain-id --rpc-url "$RPC_URL")"
  [[ "$chain_id" == "$EXPECTED_CHAIN_ID" ]] || die "expected chain ID $EXPECTED_CHAIN_ID (Unichain Sepolia), got $chain_id"

  owner_address="$(cast wallet address --private-key "$SEPOLIA_PRIVATE_KEY")"
  expected_owner="${OWNER_ADDRESS:-}"
  owner_address_lc="$(printf "%s" "$owner_address" | tr "[:upper:]" "[:lower:]")"
  expected_owner_lc="$(printf "%s" "$expected_owner" | tr "[:upper:]" "[:lower:]")"

  ensure_demo_user_keys

  log "preflight"
  printf " - chain id: %s\n" "$chain_id"
  printf " - owner:    %s\n" "$owner_address"
  printf " - gas:      %s\n" "$GAS_PRICE"
  if [[ -n "$expected_owner" && "$expected_owner_lc" != "$owner_address_lc" ]]; then
    printf " - note: OWNER_ADDRESS in .env differs from private key owner, updating OWNER_ADDRESS\n"
    upsert_env "OWNER_ADDRESS" "$owner_address"
  fi

  if needs_deployments; then
    log "phase 0 - deploy system contracts (missing/stale deployment detected)"
    forge script "$DEPLOY_SCRIPT" \
      --rpc-url "$RPC_URL" \
      --private-key "$SEPOLIA_PRIVATE_KEY" \
      --legacy \
      --with-gas-price "$GAS_PRICE" \
      --broadcast \
      --slow \
      -vvvv

    local deploy_json
    deploy_json="$ROOT_DIR/broadcast/00_DeployFractionalSystem.s.sol/$chain_id/run-latest.json"
    parse_deployment_addresses "$deploy_json"

    upsert_env "TOKEN0_ADDRESS" "$TOKEN0_ADDRESS"
    upsert_env "TOKEN1_ADDRESS" "$TOKEN1_ADDRESS"
    upsert_env "VAULT_ADDRESS" "$VAULT_ADDRESS"
    upsert_env "HOOK_ADDRESS" "$HOOK_ADDRESS"
    upsert_env "SHARE_TOKEN_ADDRESS" "$SHARE_TOKEN_ADDRESS"
    upsert_env "POSITION_NFT_ADDRESS" "$POSITION_NFT_ADDRESS"

    print_tx_urls "$deploy_json" "deployment"
  else
    log "phase 0 - using existing deployment from .env"
    printf " - token0: %s\n" "$TOKEN0_ADDRESS"
    printf " - token1: %s\n" "$TOKEN1_ADDRESS"
    printf " - vault:  %s\n" "$VAULT_ADDRESS"
    printf " - hook:   %s\n" "$HOOK_ADDRESS"
  fi

  load_env
  require_var TOKEN0_ADDRESS
  require_var TOKEN1_ADDRESS
  require_var VAULT_ADDRESS
  require_var HOOK_ADDRESS

  local user_a_address user_b_address
  user_a_address="$(cast wallet address --private-key "$DEMO_USER_A_PK")"
  user_b_address="$(cast wallet address --private-key "$DEMO_USER_B_PK")"

  log "phase 1-5 - run lifecycle demo"
  printf " - user A: %s\n" "$user_a_address"
  printf " - user B: %s\n" "$user_b_address"

  forge script "$DEMO_SCRIPT" \
    --rpc-url "$RPC_URL" \
    --private-key "$SEPOLIA_PRIVATE_KEY" \
    --legacy \
    --with-gas-price "$GAS_PRICE" \
    --broadcast \
    --slow \
    -vvvv

  local demo_json
  demo_json="$ROOT_DIR/broadcast/02_DemoUnichainLifecycle.s.sol/$chain_id/run-latest.json"
  print_tx_urls "$demo_json" "demo"

  summarize_onchain_state "$user_a_address" "$user_b_address"

  log "done"
  printf " - .env updated with deployed addresses for subsequent demo runs\n"
}

main "$@"
