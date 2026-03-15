# Demo

## Local Demo Flow

```bash
anvil
make demo-local
```

Lifecycle executed by script:

1. deploys Uniswap v4 artifacts + mock tokens
2. deploys hook and vault
3. creates pool and seeds liquidity
4. user A deposits, user B deposits
5. swap executes and fee signal accrues
6. user A redeems
7. prints deterministic summary values

## Targets

- `make demo-local`
- `make demo-testnet`
- `make demo-fractional`
