# Testing

## Commands

```bash
forge test -vv
forge coverage
```

## Coverage Domains

- unit tests: accounting and vault behavior
- edge cases: first depositor, last redeemer, zero-paths, loss accounting
- fuzz tests: deposit/redeem conservation
- invariants: supply/value consistency
- integration: pool + hook + swap lifecycle
