# Deployment

## Bootstrap

```bash
./scripts/bootstrap.sh
```

## Local Deploy

```bash
anvil
forge script script/00_DeployFractionalSystem.s.sol:DeployFractionalSystemScript \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast -vv
```

## Unichain Sepolia Deploy + Demo

```bash
make demo-testnet
```

Required `.env` keys:

- `SEPOLIA_PRIVATE_KEY`
- `UNICHAIN_SEPOLIA_RPC_URL` (or `SEPOLIA_RPC_URL`)
- `OWNER_ADDRESS` (optional; auto-updated if mismatch)

`make demo-testnet` automatically:

1. deploys contracts if missing
2. writes deployed addresses to `.env`
3. runs the full lifecycle script
4. prints tx explorer URLs
