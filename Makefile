SHELL := /bin/bash

.PHONY: bootstrap build test coverage lint abi-check demo-local demo-testnet demo-fractional verify-deps verify-commits

bootstrap:
	./scripts/bootstrap.sh

build:
	forge build

test:
	forge test -vv

coverage:
	forge coverage

lint:
	forge fmt --check

abi-check:
	./scripts/export_abis.sh

verify-deps:
	./scripts/verify_dependency_integrity.sh

verify-commits:
	./scripts/verify_commits.sh 80

demo-local:
	forge script script/01_DemoFractionalLifecycle.s.sol:DemoFractionalLifecycleScript --rpc-url http://127.0.0.1:8545 --broadcast -vv

demo-testnet:
	forge script script/00_DeployFractionalSystem.s.sol:DeployFractionalSystemScript --rpc-url $$BASE_SEPOLIA_RPC_URL --account $$ACCOUNT --sender $$SENDER --broadcast -vv

demo-fractional: demo-local
