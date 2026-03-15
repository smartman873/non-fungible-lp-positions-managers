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
  --broadcast -vv
```

## Base Sepolia (preferred)

```bash
forge script script/00_DeployFractionalSystem.s.sol:DeployFractionalSystemScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --account $ACCOUNT \
  --sender $SENDER \
  --broadcast -vv
```
