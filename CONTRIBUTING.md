# Contributing

## Setup

```bash
./scripts/bootstrap.sh
forge build
forge test -vv
```

## Standards

- use custom errors and explicit access controls
- keep deterministic math in `AccountingLibrary`
- add tests for every behavior change
- keep dependency versions consistent across repo

## Commit Style

Use conventional prefixes:

- `feat:` new functionality
- `fix:` bug fix
- `test:` test coverage
- `docs:` documentation
- `chore:` tooling/maintenance
