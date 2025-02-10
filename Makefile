# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# dapp deps
update:; forge update


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

# 
# 
# DEPLOY
# 
# 

DEV_DEPLOY_CONFIG=config/deploy/sepolia.json
PROD_DEPLOY_CONFIG=config/deploy/mainnet.json

deploy:
	FOUNDRY_PROFILE=production MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) CONFIG=$(CONFIG_PATH) forge script $(SCRIPT) --rpc-url $(RPC_URL) --etherscan-api-key $(SCAN_API_KEY) --skip test --broadcast --slow -v --verify

# Deploy Hub

deploy-hub: SCRIPT=script/deploy/DeployHub.s.sol:DeployHub
deploy-hub: deploy

# Deploy Spoke

deploy-spoke: SCRIPT=script/deploy/DeploySpoke.s.sol:DeploySpoke
deploy-spoke: deploy

# Deploy Hub Testnet

deploy-hub-dev: CONFIG_PATH=$(DEV_DEPLOY_CONFIG)
deploy-hub-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
deploy-hub-dev: deploy-hub

# Deploy Hub Mainnet

deploy-hub-prod: CONFIG_PATH=$(PROD_DEPLOY_CONFIG)
deploy-hub-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
deploy-hub-prod: deploy-hub

# Deploy Spoke Testnet

deploy-spoke-dev: CONFIG_PATH=$(DEV_DEPLOY_CONFIG)
deploy-spoke-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
deploy-spoke-dev: deploy-spoke

# Deploy Spoke Mainnet

deploy-spoke-prod: CONFIG_PATH=$(PROD_DEPLOY_CONFIG)
deploy-spoke-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
deploy-spoke-prod: deploy-spoke

# Chain-specific deployment Testnet

deploy-hub-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
deploy-hub-dev-sepolia: SCAN_API_KEY=$(ETHERSCAN_API_KEY)
deploy-hub-dev-sepolia: deploy-hub-dev

deploy-spoke-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
deploy-spoke-dev-arbitrum-sepolia: SCAN_API_KEY=$(ARBITRUM_ETHERSCAN_API_KEY)
deploy-spoke-dev-arbitrum-sepolia: deploy-spoke-dev

deploy-spoke-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
deploy-spoke-dev-optimism-sepolia: SCAN_API_KEY=$(OPTIMISM_ETHERSCAN_API_KEY)
deploy-spoke-dev-optimism-sepolia: deploy-spoke-dev

# Chain-specific deployment Mainnet

deploy-hub-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
deploy-hub-prod-eth: SCAN_API_KEY=$(ETHERSCAN_API_KEY)
deploy-hub-prod-eth: deploy-hub-prod

deploy-spoke-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
deploy-spoke-prod-arbitrum: SCAN_API_KEY=$(ARBITRUM_ETHERSCAN_API_KEY)
deploy-spoke-prod-arbitrum: deploy-spoke-prod

deploy-spoke-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
deploy-spoke-prod-optimism: SCAN_API_KEY=$(OPTIMISM_ETHERSCAN_API_KEY)
deploy-spoke-prod-optimism: deploy-spoke-prod

# 
# 
# CONFIGURE
# 
# 

configure:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) CONFIG=$(CONFIG_PATH) forge script script/configure/Configure.s.sol:Configure --rpc-url $(RPC_URL) --skip test --broadcast --slow -v

# Configure Testnet

configure-dev: CONFIG_PATH=config/configure/sepolia.json
configure-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
configure-dev: configure

# Configure Mainnet

configure-prod: CONFIG_PATH=config/configure/mainnet.json
configure-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
configure-prod: configure

# Chain-specific configure Testnet

configure-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
configure-dev-sepolia: configure-dev

configure-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
configure-dev-arbitrum-sepolia: configure-dev

configure-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
configure-dev-optimism-sepolia: configure-dev

# Chain-specific configure Mainnet

configure-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
configure-prod-eth: configure-prod

configure-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
configure-prod-arbitrum: configure-prod

configure-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
configure-prod-optimism: configure-prod

# 
# 
# UPGRADE
# 
# 

upgrade-transceiver:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) CONFIG=$(CONFIG_PATH) forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url $(RPC_URL) --skip test --broadcast --slow -v

# Upgrade transceiver Testnet

upgrade-transceiver-dev: CONFIG_PATH=config/upgrade/sepolia.json
upgrade-transceiver-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
upgrade-transceiver-dev: upgrade-transceiver

# Upgrade transceiver Mainnet

upgrade-transceiver-prod: CONFIG_PATH=config/upgrade/mainnet.json
upgrade-transceiver-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
upgrade-transceiver-prod: upgrade-transceiver

# Chain-specific upgrade transceiver Testnet

upgrade-transceiver-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
upgrade-transceiver-dev-sepolia: upgrade-transceiver-dev

upgrade-transceiver-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
upgrade-transceiver-dev-arbitrum-sepolia: upgrade-transceiver-dev

upgrade-transceiver-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
upgrade-transceiver-dev-optimism-sepolia: upgrade-transceiver-dev

# Chain-specific upgrade transceiver Mainnet

upgrade-transceiver-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
upgrade-transceiver-prod-eth: upgrade-transceiver-prod

upgrade-transceiver-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
upgrade-transceiver-prod-arbitrum: upgrade-transceiver-prod

upgrade-transceiver-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
upgrade-transceiver-prod-optimism: upgrade-transceiver-prod

#
# Upgrade Hub Portal
#

upgrade-hub-portal:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) CONFIG=$(CONFIG_PATH) forge script script/upgrade/UpgradeHubPortal.s.sol:UpgradeHubPortal --rpc-url $(RPC_URL) --skip test --broadcast --slow -v

upgrade-hub-portal-dev-sepolia: CONFIG_PATH=config/upgrade/sepolia.json
upgrade-hub-portal-dev-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
upgrade-hub-portal-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
upgrade-hub-portal-dev-sepolia: upgrade-hub-portal

upgrade-hub-portal-prod-eth: CONFIG_PATH=config/upgrade/mainnet.json
upgrade-hub-portal-prod-eth: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
upgrade-hub-portal-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
upgrade-hub-portal-prod-eth: upgrade-hub-portal

#
# Upgrade Spoke Portal
#

upgrade-spoke-portal:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) CONFIG=$(CONFIG_PATH) forge script script/upgrade/UpgradeSpokePortal.s.sol:UpgradeSpokePortal --rpc-url $(RPC_URL) --skip test --broadcast --slow -v

upgrade-spoke-portal-dev: CONFIG_PATH=config/upgrade/sepolia.json
upgrade-spoke-portal-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
upgrade-spoke-portal-dev: upgrade-spoke-portal

upgrade-spoke-portal-prod: CONFIG_PATH=config/upgrade/mainnet.json
upgrade-spoke-portal-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
upgrade-spoke-portal-prod: upgrade-spoke-portal

upgrade-spoke-portal-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
upgrade-spoke-portal-dev-arbitrum-sepolia: upgrade-spoke-portal-dev

upgrade-spoke-portal-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
upgrade-spoke-portal-dev-optimism-sepolia: upgrade-spoke-portal-dev

upgrade-spoke-portal-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
upgrade-spoke-portal-prod-arbitrum: upgrade-spoke-portal-prod

upgrade-spoke-portal-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
upgrade-spoke-portal-prod-optimism: upgrade-spoke-portal-prod

# 
# 
# TASKS
# 
# 

task:
	PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) forge script $(SCRIPT) --rpc-url $(RPC_URL) --skip test --broadcast --slow -v

# 
# Regular transfer
# 

transfer: SCRIPT=script/tasks/Transfer.s.sol:Transfer
transfer: task

# Testnet

transfer-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
transfer-dev: transfer

# Mainnet

transfer-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
transfer-prod: transfer

# Chain-specific transfers Testnet

transfer-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
transfer-dev-sepolia: transfer-dev

transfer-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-dev-optimism-sepolia: transfer-dev

transfer-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-dev-arbitrum-sepolia: transfer-dev

# Chain-specific transfers Mainnet

transfer-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
transfer-prod-eth: transfer-prod

transfer-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-prod-optimism: transfer-prod

transfer-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-prod-arbitrum: transfer-prod

# 
# M-like token transfers
# 

transfer-m-like-token: SCRIPT=script/tasks/TransferMLikeToken.s.sol:TransferMLikeToken
transfer-m-like-token: task

# Testnet

transfer-m-like-token-dev: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
transfer-m-like-token-dev: transfer-m-like-token

# Mainnet

transfer-m-like-token-prod: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
transfer-m-like-token-prod: transfer-m-like-token

# Chain-specific transfers Testnet

transfer-m-like-token-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
transfer-m-like-token-dev-sepolia: transfer-m-like-token-dev

transfer-m-like-token-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-m-like-token-dev-optimism-sepolia: transfer-m-like-token-dev

transfer-m-like-token-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-m-like-token-dev-arbitrum-sepolia: transfer-m-like-token-dev

# Chain-specific transfers Mainnet

transfer-m-like-token-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
transfer-m-like-token-prod-eth: transfer-m-like-token-prod

transfer-m-like-token-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-m-like-token-prod-optimism: transfer-m-like-token-prod

transfer-m-like-token-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-m-like-token-prod-arbitrum: transfer-m-like-token-prod

# 
# Send M index
# 

send-m-token-index: SCRIPT=script/tasks/SendMTokenIndex.s.sol:SendMTokenIndex
send-m-token-index: task

# Testnet

send-m-token-index-dev-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
send-m-token-index-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-m-token-index-dev-sepolia: send-m-token-index

# Mainnet

send-m-token-index-prod-eth: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
send-m-token-index-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
send-m-token-index-prod-eth: send-m-token-index

# 
# Registrar key
# 

send-registrar-key: SCRIPT=script/tasks/SendRegistrarKey.s.sol:SendRegistrarKey
send-registrar-key: task

# Testnet

send-registrar-key-dev-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
send-registrar-key-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-registrar-key-dev-sepolia: send-registrar-key

# Mainnet

send-registrar-key-prod-eth: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
send-registrar-key-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
send-registrar-key-prod-eth: send-registrar-key

# 
# Registrar list status
# 

send-registrar-list-status: SCRIPT=script/tasks/SendRegistrarListStatus.s.sol:SendRegistrarListStatus
send-registrar-list-status: task

# Testnet

send-registrar-list-status-dev-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
send-registrar-list-status-dev-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-registrar-list-status-dev-sepolia: send-registrar-list-status

# Mainnet

send-registrar-list-status-prod-eth: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
send-registrar-list-status-prod-eth: RPC_URL=$(MAINNET_RPC_URL)
send-registrar-list-status-prod-eth: send-registrar-list-status

# 
# Transfer Excess M
# 

transfer-excess-m: SCRIPT=script/tasks/TransferExcessM.s.sol:TransferExcessM
transfer-excess-m: task

# Testnet

transfer-excess-m-dev-arbitrum-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
transfer-excess-m-dev-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-excess-m-dev-arbitrum-sepolia: transfer-excess-m

transfer-excess-m-dev-optimism-sepolia: SIGNER_PRIVATE_KEY=$(DEV_PRIVATE_KEY)
transfer-excess-m-dev-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-excess-m-dev-optimism-sepolia: transfer-excess-m

# Mainnet

transfer-excess-m-prod-arbitrum: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
transfer-excess-m-prod-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-excess-m-prod-arbitrum: transfer-excess-m

transfer-excess-m-prod-optimism: SIGNER_PRIVATE_KEY=$(PRIVATE_KEY)
transfer-excess-m-prod-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-excess-m-prod-optimism: transfer-excess-m

