# Architecture

## Components

- `FractionalLPHook`: Uniswap v4 swap callback integration.
- `LiquidityVault`: share mint/burn and accounting core.
- `FractionalToken`: fungible ownership claims.
- `PositionNFT`: optional vault ownership metadata.

## Interaction Diagram

```mermaid
graph TD
    FE[Frontend] --> VAULT[LiquidityVault]
    FE --> HOOK[FractionalLPHook]
    VAULT --> FT[FractionalToken]
    HOOK --> PM[PoolManager]
    PM --> POOL[Pool]
    HOOK --> VAULT
```
