# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update

# Deployment helpers
deploy-local-hub:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeployHub.s.sol:DeployHub --rpc-url localhost --skip test --broadcast -v

deploy-local-spoke:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeploySpoke.s.sol:DeploySpoke --rpc-url localhost --skip test --non-interactive --broadcast -v

deploy-dev-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeployHub.s.sol:DeployHub --rpc-url $(SEPOLIA_RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

deploy-dev-base-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeploySpoke.s.sol:DeploySpoke --rpc-url $(BASE_SEPOLIA_RPC_URL) --etherscan-api-key $(BASE_ETHERSCAN_API_KEY) --skip test --non-interactive --broadcast --slow -v --verify

deploy-dev-optimism-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeploySpoke.s.sol:DeploySpoke --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --etherscan-api-key $(OPTIMISM_ETHERSCAN_API_KEY) --skip test --non-interactive --broadcast --slow -v --verify

deploy-dev-arbitrum-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/deploy/sepolia.json" MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/deploy/DeploySpoke.s.sol:DeploySpoke --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --etherscan-api-key $(ARBITRUM_ETHERSCAN_API_KEY) --skip test --non-interactive --broadcast --slow -v --verify

# Configuration helpers
configure-local:
	CONFIG="config/configure/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/configure/Configure.s.sol:Configure --rpc-url localhost --skip test --broadcast -v

configure-dev-sepolia:
	CONFIG="config/configure/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/configure/Configure.s.sol:Configure --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

configure-dev-base-sepolia:
	CONFIG="config/configure/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/configure/Configure.s.sol:Configure --rpc-url $(BASE_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

configure-dev-optimism-sepolia:
	CONFIG="config/configure/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/configure/Configure.s.sol:Configure --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

configure-dev-arbitrum-sepolia:
	CONFIG="config/configure/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/configure/Configure.s.sol:Configure --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

# Upgrade helpers
upgrade-transceiver-local:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url localhost --skip test --broadcast -v

upgrade-transceiver-dev-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url $(SEPOLIA_RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

upgrade-transceiver-dev-base-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url $(BASE_SEPOLIA_RPC_URL) --etherscan-api-key $(BASE_ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

upgrade-transceiver-dev-optimism-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --etherscan-api-key $(OPTIMISM_ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

upgrade-hub-portal-local:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeHubPortal.s.sol:UpgradeHubPortal --rpc-url localhost --skip test --broadcast -v

upgrade-spoke-portal-local:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeSpokePortal.s.sol:UpgradeSpokePortal --rpc-url localhost --skip test --broadcast -v

upgrade-portal-dev-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeHubPortal.s.sol:UpgradeHubPortal --rpc-url $(SEPOLIA_RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

upgrade-portal-dev-base-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeSpokePortal.s.sol:UpgradeSpokePortal --rpc-url $(BASE_SEPOLIA_RPC_URL) --etherscan-api-key $(BASE_ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

upgrade-portal-dev-optimism-sepolia:
	FOUNDRY_PROFILE=production CONFIG="config/upgrade/sepolia.json" PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/upgrade/UpgradeSpokePortal.s.sol:UpgradeSpokePortal --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --etherscan-api-key $(OPTIMISM_ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

# Tasks
send-m-token-index-local:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendMTokenIndex.s.sol:SendMTokenIndex --rpc-url localhost --skip test --broadcast -v

cast-transfer-dev-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/Transfer.s.sol:Transfer --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-dev-optimism-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/Transfer.s.sol:Transfer --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-dev-arbitrum-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/Transfer.s.sol:Transfer --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-m-like-token-dev-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferMLikeToken.s.sol:TransferMLikeToken --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-m-like-token-dev-optimism-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferMLikeToken.s.sol:TransferMLikeToken --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-m-like-token-dev-arbitrum-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferMLikeToken.s.sol:TransferMLikeToken --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-send-m-token-index-dev-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendMTokenIndex.s.sol:SendMTokenIndex --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-send-registrar-key-local:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendRegistrarKey.s.sol:SendRegistrarKey --rpc-url localhost --skip test --broadcast -v

cast-send-registrar-key-dev-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendRegistrarKey.s.sol:SendRegistrarKey --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-send-registrar-list-status-local:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendRegistrarListStatus.s.sol:SendRegistrarListStatus --rpc-url localhost --skip test --broadcast -v

cast-send-registrar-list-status-dev-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/SendRegistrarListStatus.s.sol:SendRegistrarListStatus --rpc-url $(SEPOLIA_RPC_URL) --skip test --broadcast --slow -v

cast-transfer-excess-m-local:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferExcessM.s.sol:TransferExcessM --rpc-url localhost --skip test --broadcast -v

cast-transfer-excess-m-base-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferExcessM.s.sol:TransferExcessM --rpc-url $(BASE_SEPOLIA_RPC_URL) --skip test --broadcast -v

cast-transfer-excess-m-optimism-sepolia:
	PRIVATE_KEY=$(DEV_PRIVATE_KEY) forge script script/tasks/TransferExcessM.s.sol:TransferExcessM --rpc-url $(OPTIMISM_SEPOLIA_RPC_URL) --skip test --broadcast -v

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
	FOUNDRY_PROFILE=$(profile) forge coverage --no-match-path 'test/fork/**/*.sol' --report lcov && lcov --extract lcov.info --rc lcov_branch_coverage=1 --rc derive_function_end_line=0 -o lcov.info 'src/*' && genhtml lcov.info --rc branch_coverage=1 --rc derive_function_end_line=0 -o coverage

gas-report:
	FOUNDRY_PROFILE=$(profile) forge test --no-match-path 'test/fork/**/*.sol'  --no-match-test 'testFuzz*' --gas-report > gasreport.ansi

sizes:
	./build.sh -p production -s

clean:
	forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types
