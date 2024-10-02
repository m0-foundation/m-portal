# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# Deployment helpers
deploy-local-hub:
	FOUNDRY_PROFILE=production forge script script/deploy/dev/DeployDevHub.s.sol:DeployDevHub --private-key $(DEV_PRIVATE_KEY) --rpc-url localhost --skip test --broadcast -v

deploy-local-spoke:
	FOUNDRY_PROFILE=production forge script script/deploy/dev/DeployDevSpoke.s.sol:DeployDevSpoke --private-key $(DEV_PRIVATE_KEY) --rpc-url localhost --skip test --non-interactive --broadcast -v

deploy-dev-sepolia:
	FOUNDRY_PROFILE=production forge script script/deploy/dev/DeployDevHub.s.sol:DeployDevHub --private-key $(DEV_PRIVATE_KEY) --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

deploy-dev-base-sepolia:
	FOUNDRY_PROFILE=production forge script script/deploy/dev/DeployDevSpoke.s.sol:DeployDevSpoke --private-key $(DEV_PRIVATE_KEY) --rpc-url $(BASE_SEPOLIA_RPC_URL) --skip test --non-interactive --broadcast --slow -v

deploy-dev-optimism-sepolia:
	FOUNDRY_PROFILE=production forge script script/deploy/dev/DeployDevSpoke.s.sol:DeployDevSpoke --private-key $(DEV_PRIVATE_KEY) --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --skip test --non-interactive --broadcast --slow -v

# Configuration helpers
config-dev:
	forge script script/deploy/dev/ConfigDev.s.sol --skip src --skip test --multi --broadcast --slow -v

# Run slither
slither :; FOUNDRY_PROFILE=production forge build --build-info --skip '*/test/**' --skip '*/script/**' --force && slither --compile-force-framework foundry --ignore-compile --sarif results.sarif --config-file slither.config.json .

# Common tasks
profile ?=default

build:
	./build.sh -p production

tests:
	./test.sh -p $(profile)

fork:
	./test.sh -d test/fork -p $(profile)

fuzz:
	./test.sh -t testFuzz -p $(profile)

integration:
	./test.sh -d test/integration -p $(profile)

invariant:
	./test.sh -d test/invariant -p $(profile)

coverage:
	FOUNDRY_PROFILE=$(profile) forge coverage --no-match-path 'test/invariant/**/*.sol' --report lcov && lcov --extract lcov.info --rc lcov_branch_coverage=1 --rc derive_function_end_line=0 -o lcov.info 'src/*' && genhtml lcov.info --rc branch_coverage=1 --rc derive_function_end_line=0 -o coverage

gas-report:
	FOUNDRY_PROFILE=$(profile) forge test --gas-report > gasreport.ansi

sizes:
	./build.sh -p production -s

clean:
	forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types
