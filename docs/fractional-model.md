# Fractional Model

## Mint Formula

`sharesMinted = depositValue * totalShares / totalVaultValue`

Bootstrap: `sharesMinted = depositValue` when vault is empty.

## Burn Formula

`withdrawAmount = sharesBurned * totalVaultValue / totalShares`

## Share Price

`sharePriceX96 = totalVaultValue * 2^96 / totalShares`

## Rounding Rules

- floor division is used for deterministic integer math
- zero-amount and zero-denominator paths revert
- tiny deposits can mint minimum 1 share to avoid silent dust loss
