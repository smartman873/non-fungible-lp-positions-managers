# Testing

## Commands

```bash
forge test -vv
forge coverage --report summary --exclude-tests --no-match-coverage "test/|script/|src/mocks/|src/interfaces/|test/utils/|test/invariants/"
```

## Coverage Domains

- unit tests: accounting and vault behavior
- edge cases: first depositor, last redeemer, zero-paths, loss accounting
- fuzz tests: deposit/redeem conservation
- invariants: supply/value consistency
- integration: pool + hook + swap lifecycle
