# Security

## Threats Considered

- share inflation
- sandwich around deposits
- unauthorized fee accounting writes
- rounding arbitrage
- insolvency from stale accounting

## Controls

- strict ownership and hook caller gates
- `ReentrancyGuard` on external value transfer operations
- deterministic formulas centralized in `AccountingLibrary`
- invariant tests for accounting conservation

## Residual Risk

The hook forwards fee signals to vault accounting. Incorrect external fee signaling can skew price unless integrated with stronger fee source validation.

Independent audit is required before production release.
