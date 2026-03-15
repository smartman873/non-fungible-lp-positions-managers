# API Surface

## LiquidityVault

- `deposit(uint256 amount0, uint256 amount1, address receiver)`
- `redeem(uint256 sharesBurned, address receiver)`
- `recordAccruedFees(uint256 feeValue)` (`onlyHook`)
- `syncLiquidity(uint256 newLiquidity)` (`onlyHook`)
- `recordLoss(uint256 lossValue)` (`onlyOwner`)
- `snapshot()`

## FractionalLPHook

- `registerPool(PoolKey key)` (`onlyOwner`)
- `beforeSwap(...)`
- `afterSwap(...)`

## FractionalToken

- `mint(address to, uint256 amount)` (`onlyOwner`)
- `burnFrom(address from, uint256 amount)` (`onlyOwner`)
