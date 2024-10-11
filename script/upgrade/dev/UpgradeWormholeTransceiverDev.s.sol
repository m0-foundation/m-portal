// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Script.sol";

import { UpgradeBase } from "../UpgradeBase.sol";

contract UpgradeWormholeTransceiverDev is UpgradeBase {
    function run() public {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        if (block.chainid == _SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();

            _upgradeWormholeTransceiver(
                deployer_,
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: _SEPOLIA_WORMHOLE_CORE_BRIDGE,
                    wormholeRelayerAddr: _SEPOLIA_WORMHOLE_RELAYER,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );

            vm.stopBroadcast();
        } else if (block.chainid == _BASE_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();

            _upgradeWormholeTransceiver(
                deployer_,
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _BASE_SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: _BASE_SEPOLIA_WORMHOLE_CORE_BRIDGE,
                    wormholeRelayerAddr: _BASE_SEPOLIA_WORMHOLE_RELAYER,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );

            vm.stopBroadcast();
        } else if (block.chainid == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast();

            _upgradeWormholeTransceiver(
                deployer_,
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: _OPTIMISM_SEPOLIA_WORMHOLE_CORE_BRIDGE,
                    wormholeRelayerAddr: _OPTIMISM_SEPOLIA_WORMHOLE_RELAYER,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );

            vm.stopBroadcast();
        } else {
            console2.log("Chain id: {}", block.chainid);
            revert("Unsupported chain id.");
        }
    }
}
