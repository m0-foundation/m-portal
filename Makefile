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
	FOUNDRY_PROFILE=$(profile) forge test --no-match-path 'test/fork/**/*.sol' --no-match-contract 'MerkleTreeBuilderTest|SortedLinkedListTest' --no-match-test 'testFuzz*' --gas-report > gasreport.ansi

sizes:
	./build.sh -p production -s

clean:
	forge clean && rm -rf ./abi && rm -rf ./bytecode && rm -rf ./types

# 
# 
# DEPLOY
# 
# 

# Default to actual deployment (not simulation)
DRY_RUN ?= false

# Verifier Options
VERIFIER ?= "etherscan"
VERIFIER_URL ?=
VERIFIER_API_KEY ?=

# Conditionally set verifier flags for custom verifier
ifeq ($(VERIFIER),"custom")
    VERIFIER_FLAGS = --verifier-url $(VERIFIER_URL)
    ifneq ($(VERIFIER_API_KEY),)
        VERIFIER_FLAGS += --verifier-api-key $(VERIFIER_API_KEY)
    endif
else
    VERIFIER_FLAGS =
endif

# Conditionally set broadcast and verify flags
ifeq ($(DRY_RUN),true)
    BROADCAST_FLAGS =
else
    BROADCAST_FLAGS = --broadcast --verify
endif

deploy:
	FOUNDRY_PROFILE=production MIGRATION_ADMIN=$(MIGRATION_ADMIN_ADDRESS) \
	PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script $(SCRIPT) \
	--rpc-url $(RPC_URL) \
	--etherscan-api-key $(ETHERSCAN_API_KEY) --verifier $(VERIFIER) $(VERIFIER_FLAGS) --skip test --slow --non-interactive \
	-v $(BROADCAST_FLAGS)

# Deploy Hub

deploy-hub: SCRIPT=script/deploy/DeployHub.s.sol:DeployHub
deploy-hub: deploy

# Deploy Spoke

deploy-spoke: SCRIPT=script/deploy/DeploySpoke.s.sol:DeploySpoke
deploy-spoke: deploy

# Chain-specific deployment Testnet

deploy-hub-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
deploy-hub-sepolia: deploy-hub

deploy-spoke-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
deploy-spoke-arbitrum-sepolia: deploy-spoke

deploy-spoke-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
deploy-spoke-optimism-sepolia: deploy-spoke

deploy-spoke-base-sepolia: RPC_URL=$(BASE_SEPOLIA_RPC_URL)
deploy-spoke-base-sepolia: deploy-spoke

deploy-spoke-moca-testnet: RPC_URL=$(MOCA_TESTNET_RPC_URL)
deploy-spoke-moca-testnet: VERIFIER="custom"
deploy-spoke-moca-testnet: VERIFIER_URL=$(MOCA_TESTNET_VERIFIER_URL)
deploy-spoke-moca-testnet: VERIFIER_API_KEY=$(MOCA_TESTNET_VERIFIER_API_KEY)
deploy-spoke-moca-testnet: deploy-spoke

# Chain-specific deployment Mainnet

# To run without broadcasting use make deploy-spoke-base DRY_RUN=true
# To broadcast use make deploy-spoke-base

deploy-hub-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-hub-ethereum: deploy-hub

deploy-spoke-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
deploy-spoke-arbitrum: deploy-spoke

deploy-spoke-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
deploy-spoke-optimism: deploy-spoke

deploy-spoke-base: RPC_URL=$(BASE_RPC_URL)
deploy-spoke-base: deploy-spoke

#
# Deploy Noble Hub Portal and Transceiver
#

deploy-noble: SCRIPT=script/deploy/DeployNobleHub.s.sol:DeployNobleHub
deploy-noble: deploy

deploy-noble-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-noble-ethereum: deploy-noble

deploy-noble-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
deploy-noble-sepolia: deploy-noble

#
# Deploy Merkle Tree Builder (used for Solana and non-EVM governance propagation)
#

deploy-merkle-tree-builder: SCRIPT=script/deploy/DeployMerkle.s.sol:DeployMerkleTreeBuilder
deploy-merkle-tree-builder: deploy

deploy-merkle-tree-builder-ethereum: RPC_URL=$(MAINNET_RPC_URL)
deploy-merkle-tree-builder-ethereum: deploy-merkle-tree-builder

deploy-merkle-tree-builder-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
deploy-merkle-tree-builder-sepolia: deploy-merkle-tree-builder

#
#
# CONFIGURE
# 
# 

configure: PEERS ?= []
configure:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script script/configure/Configure.s.sol:Configure --sig "run(uint16[])" $(PEERS) \
	--rpc-url $(RPC_URL) --skip test -v --slow --broadcast

# Chain-specific configure Testnet

configure-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
configure-sepolia: configure

configure-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
configure-arbitrum-sepolia: configure

configure-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
configure-optimism-sepolia: configure

configure-base-sepolia: RPC_URL=$(BASE_SEPOLIA_RPC_URL)
configure-base-sepolia: configure

configure-moca-testnet: RPC_URL=$(MOCA_TESTNET_RPC_URL)
configure-moca-testnet: configure

# Chain-specific configure Mainnet

configure-ethereum: RPC_URL=$(MAINNET_RPC_URL)
configure-ethereum: configure

configure-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
configure-arbitrum: configure

configure-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
configure-optimism: configure

configure-base: RPC_URL=$(BASE_RPC_URL)
configure-base: configure

#
# Propose configure transactions to Safe Multisig
#

propose-configure: PEERS ?= []
propose-configure:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script script/configure/ProposeConfigure.s.sol:ProposeConfigure \
	--sig "run(uint16[])" $(PEERS) --rpc-url $(RPC_URL) \
	--skip test --slow --non-interactive --broadcast --ffi

propose-configure-ethereum: RPC_URL=$(MAINNET_RPC_URL)
propose-configure-ethereum: propose-configure

propose-configure-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
propose-configure-arbitrum: propose-configure

propose-configure-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
propose-configure-optimism: propose-configure

propose-configure-base: RPC_URL=$(OPTIMISM_RPC_URL)
propose-configure-base: propose-configure

#
# Configure Noble Portal
#

configure-noble-ethereum:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script script/configure/ConfigureNobleHub.s.sol:ConfigureNobleHub \
	--rpc-url $(MAINNET_RPC_URL) \
	--skip test --broadcast -v --slow

# 
# 
# UPGRADE
# 
# 

upgrade-transceiver:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) CONFIG=$(CONFIG_PATH) \
	forge script script/upgrade/UpgradeWormholeTransceiver.s.sol:UpgradeWormholeTransceiver --rpc-url $(RPC_URL) \
	--etherscan-api-key $(ETHERSCAN_API_KEY) --skip test --broadcast --slow -v --verify

# Chain-specific upgrade transceiver Testnet

upgrade-transceiver-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
upgrade-transceiver-sepolia: upgrade-transceiver

upgrade-transceiver-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
upgrade-transceiver-arbitrum-sepolia: upgrade-transceiver

upgrade-transceiver-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
upgrade-transceiver-optimism-sepolia: upgrade-transceiver

# Chain-specific upgrade transceiver Mainnet

upgrade-transceiver-ethereum: RPC_URL=$(MAINNET_RPC_URL)
upgrade-transceiver-ethereum: upgrade-transceiver

upgrade-transceiver-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
upgrade-transceiver-arbitrum: upgrade-transceiver

upgrade-transceiver-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
upgrade-transceiver-optimism: upgrade-transceiver

#
# Upgrade Hub Portal
#

upgrade-hub-portal:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script script/upgrade/UpgradeHubPortal.s.sol:UpgradeHubPortal \
	--rpc-url $(RPC_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --skip test \
	--slow -v --broadcast --verify

upgrade-hub-portal-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
upgrade-hub-portal-sepolia: upgrade-hub-portal

upgrade-hub-portal-ethereum: RPC_URL=$(MAINNET_RPC_URL)
upgrade-hub-portal-ethereum: upgrade-hub-portal

#
# Upgrade Spoke Portal
#

upgrade-spoke-portal:
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) CONFIG=$(CONFIG_PATH) \
	forge script script/upgrade/UpgradeSpokePortal.s.sol:UpgradeSpokePortal --rpc-url $(RPC_URL) \
	--etherscan-api-key $(ETHERSCAN_API_KEY) --skip test  --slow -v --broadcast --verify

upgrade-spoke-portal-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
upgrade-spoke-portal-arbitrum-sepolia: upgrade-spoke-portal

upgrade-spoke-portal-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
upgrade-spoke-portal-optimism-sepolia: upgrade-spoke-portal

upgrade-spoke-portal-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
upgrade-spoke-portal-arbitrum: upgrade-spoke-portal

upgrade-spoke-portal-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
upgrade-spoke-portal-optimism: upgrade-spoke-portal

#
#
# PROPOSE UPGRADE VIA MULTISIG
#
#

propose-upgrade: 
	FOUNDRY_PROFILE=production PRIVATE_KEY=$(PRIVATE_KEY) \
	forge script $(SCRIPT) --rpc-url $(RPC_URL) \
	--etherscan-api-key $(ETHERSCAN_API_KEY) --skip test --slow -v --ffi --broadcast --verify

propose-hub-portal-upgrade-ethereum: SCRIPT=script/upgrade/ProposeUpgradeHubPortal.s.sol:ProposeUpgradeHubPortal
propose-hub-portal-upgrade-ethereum: RPC_URL=$(MAINNET_RPC_URL)
propose-hub-portal-upgrade-ethereum: propose-upgrade

propose-spoke-portal-upgrade-arbitrum: SCRIPT=script/upgrade/ProposeUpgradeSpokePortal.s.sol:ProposeUpgradeSpokePortal
propose-spoke-portal-upgrade-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
propose-spoke-portal-upgrade-arbitrum: propose-upgrade

propose-spoke-portal-upgrade-optimism: SCRIPT=script/upgrade/ProposeUpgradeSpokePortal.s.sol:ProposeUpgradeSpokePortal
propose-spoke-portal-upgrade-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
propose-spoke-portal-upgrade-optimism: propose-upgrade

# 
# 
# TASKS
#
#

task:
	PRIVATE_KEY=$(PRIVATE_KEY) forge script $(SCRIPT) --rpc-url $(RPC_URL) --skip test --broadcast --slow -v --ffi

# 
# Regular transfer
# 

transfer: SCRIPT=script/tasks/Transfer.s.sol:Transfer
transfer: task

# Chain-specific transfers Testnet

transfer-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
transfer-sepolia: transfer

transfer-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-optimism-sepolia: transfer

transfer-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-arbitrum-sepolia: transfer

transfer-base-sepolia: RPC_URL=$(BASE_SEPOLIA_RPC_URL)
transfer-base-sepolia: transfer

transfer-moca-testnet: RPC_URL=$(MOCA_TESTNET_RPC_URL)
transfer-moca-testnet: transfer

# Chain-specific transfers Mainnet

transfer-ethereum: RPC_URL=$(MAINNET_RPC_URL)
transfer-ethereum: transfer

transfer-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-optimism: transfer

transfer-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-arbitrum: transfer

transfer-base: RPC_URL=$(BASE_RPC_URL)
transfer-base: transfer

# 
# M-like token transfers
# 

transfer-m-like-token: SCRIPT=script/tasks/TransferMLikeToken.s.sol:TransferMLikeToken
transfer-m-like-token: task

# Chain-specific transfers Testnet

transfer-m-like-token-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
transfer-m-like-token-sepolia: transfer-m-like-token

transfer-m-like-token-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-m-like-token-optimism-sepolia: transfer-m-like-token

transfer-m-like-token-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-m-like-token-arbitrum-sepolia: transfer-m-like-token

transfer-m-like-token-base-sepolia: RPC_URL=$(BASE_SEPOLIA_RPC_URL)
transfer-m-like-token-base-sepolia: transfer-m-like-token

transfer-m-like-token-moca-testnet: RPC_URL=$(MOCA_TESTNET_RPC_URL)
transfer-m-like-token-moca-testnet: transfer-m-like-token

# Chain-specific transfers Mainnet

transfer-m-like-token-ethereum: RPC_URL=$(MAINNET_RPC_URL)
transfer-m-like-token-ethereum: transfer-m-like-token

transfer-m-like-token-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-m-like-token-optimism: transfer-m-like-token

transfer-m-like-token-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-m-like-token-arbitrum: transfer-m-like-token

transfer-m-like-token-base: RPC_URL=$(BASE_RPC_URL)
transfer-m-like-token-base: transfer-m-like-token

# 
# Send M index
# 

send-m-token-index: SCRIPT=script/tasks/SendMTokenIndex.s.sol:SendMTokenIndex
send-m-token-index: task

send-m-token-index-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-m-token-index-sepolia: send-m-token-index

send-m-token-index-ethereum: RPC_URL=$(MAINNET_RPC_URL)
send-m-token-index-ethereum: send-m-token-index

# 
# Registrar key
# 

send-registrar-key: SCRIPT=script/tasks/SendRegistrarKey.s.sol:SendRegistrarKey
send-registrar-key: task

send-registrar-key-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-registrar-key-sepolia: send-registrar-key

send-registrar-key-ethereum: RPC_URL=$(MAINNET_RPC_URL)
send-registrar-key-ethereum: send-registrar-key

# 
# Earner status
# 

send-earner-status: SCRIPT=script/tasks/SendEarnerStatus.s.sol:SendEarnerStatus
send-earner-status: task

send-earner-status-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
send-earner-status-sepolia: send-earner-status

send-earner-status-ethereum: RPC_URL=$(MAINNET_RPC_URL)
send-earner-status-ethereum: send-earner-status

# 
# Transfer Excess M
# 

transfer-excess-m: SCRIPT=script/tasks/TransferExcessM.s.sol:TransferExcessM
transfer-excess-m: task

transfer-excess-m-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
transfer-excess-m-arbitrum-sepolia: transfer-excess-m

transfer-excess-m-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
transfer-excess-m-optimism-sepolia: transfer-excess-m

# Mainnet

transfer-excess-m-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-excess-m-arbitrum: transfer-excess-m

transfer-excess-m-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-excess-m-optimism: transfer-excess-m

# 
# Transfer Portal and Transceiver Ownership
# 

transfer-ownership: SCRIPT=script/tasks/TransferOwnership.s.sol:TransferOwnership
transfer-ownership: task

# Mainnet
transfer-ownership-ethereum: RPC_URL=$(MAINNET_RPC_URL)
transfer-ownership-ethereum: transfer-ownership

transfer-ownership-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
transfer-ownership-arbitrum: transfer-ownership

transfer-ownership-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
transfer-ownership-optimism: transfer-ownership

#
# Propose to Unpause Portal to Multisig
#

unpause-portal: SCRIPT=script/tasks/ProposeUnpausePortal.s.sol:ProposeUnpausePortal
unpause-portal: task

unpause-portal-ethereum: RPC_URL=$(MAINNET_RPC_URL)
unpause-portal-ethereum: unpause-portal

unpause-portal-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
unpause-portal-arbitrum: unpause-portal

unpause-portal-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
unpause-portal-optimism: unpause-portal

#
# Propose Set Bridging Path
#

set-bridging-path: SCRIPT=script/tasks/ProposeSetBridgingPath.s.sol:ProposeSetBridgingPath
set-bridging-path: task

# Mainnet
set-bridging-path-ethereum: RPC_URL=$(MAINNET_RPC_URL)
set-bridging-path-ethereum: set-bridging-path

set-bridging-path-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
set-bridging-path-arbitrum: set-bridging-path

set-bridging-path-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
set-bridging-path-optimism: set-bridging-path

#
#
# QUERIES
#
#

query:
	forge script $(SCRIPT) --rpc-url $(RPC_URL) --skip test -v

#
# Get Portal Info
#

get-portal-info: SCRIPT=script/queries/GetPortalInfo.s.sol:GetPortalInfo
get-portal-info: query

get-portal-info-sepolia: RPC_URL=$(SEPOLIA_RPC_URL)
get-portal-info-sepolia: get-portal-info

get-portal-info-optimism-sepolia: RPC_URL=$(OPTIMISM_SEPOLIA_RPC_URL)
get-portal-info-optimism-sepolia: get-portal-info

get-portal-info-arbitrum-sepolia: RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
get-portal-info-arbitrum-sepolia: get-portal-info

get-portal-info-base-sepolia: RPC_URL=$(BASE_SEPOLIA_RPC_URL)
get-portal-info-base-sepolia: get-portal-info

get-portal-info-ethereum: RPC_URL=$(MAINNET_RPC_URL)
get-portal-info-ethereum: get-portal-info

get-portal-info-optimism: RPC_URL=$(OPTIMISM_RPC_URL)
get-portal-info-optimism: get-portal-info

get-portal-info-arbitrum: RPC_URL=$(ARBITRUM_RPC_URL)
get-portal-info-arbitrum: get-portal-info

get-portal-info-base: RPC_URL=$(BASE_RPC_URL)
get-portal-info-base: get-portal-info