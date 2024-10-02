// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Script.sol";

import { DeployBase } from "../DeployBase.sol";

contract DeployDevSpoke is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        if (block.chainid == _BASE_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            (
                address spokeBaseSepoliaNTTManager_,
                address spokeBaseSepoliaWormholeTransceiver_,
                address spokeBaseSepoliaRegistrar_,
                address spokeBaseSepoliaMToken_
            ) = _deploySpokeComponents(
                    deployer_,
                    _BASE_SEPOLIA_WORMHOLE_CHAIN_ID,
                    _BASE_SEPOLIA_WORMHOLE_CORE_BRIDGE,
                    _BASE_SEPOLIA_WORMHOLE_RELAYER,
                    address(0),
                    _burnNonces
                );

            vm.stopBroadcast();

            console2.log("Base Sepolia Spoke NTT Manager address:", spokeBaseSepoliaNTTManager_);
            console2.log("Base Sepolia Spoke Wormhole Transceiver address:", spokeBaseSepoliaWormholeTransceiver_);
            console2.log("Base Sepolia Spoke Registrar address:", spokeBaseSepoliaRegistrar_);
            console2.log("Base Sepolia Spoke MToken address:", spokeBaseSepoliaMToken_);
        } else if (block.chainid == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            (
                address spokeOptimismSepoliaNTTManager_,
                address spokeOptimismSepoliaWormholeTransceiver_,
                address spokeOptimismSepoliaRegistrar_,
                address spokeOptimismSepoliaMToken_
            ) = _deploySpokeComponents(
                    deployer_,
                    _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID,
                    _OPTIMISM_SEPOLIA_WORMHOLE_CORE_BRIDGE,
                    _OPTIMISM_SEPOLIA_WORMHOLE_RELAYER,
                    address(0),
                    _burnNonces
                );

            console2.log("Optimism Sepolia Spoke NTT Manager address:", spokeOptimismSepoliaNTTManager_);
            console2.log(
                "Optimism Sepolia Spoke Wormhole Transceiver address:",
                spokeOptimismSepoliaWormholeTransceiver_
            );
            console2.log("Optimism Sepolia Spoke Registrar address:", spokeOptimismSepoliaRegistrar_);
            console2.log("Optimism Sepolia Spoke MToken address:", spokeOptimismSepoliaMToken_);

            vm.stopBroadcast();
        } else {
            console2.log("Chain id: {}", block.chainid);
            revert("Unsupported chain id.");
        }
    }

    function _burnNonces(address account_, uint64 startingNonce_, uint64 targetNonce_) internal {
        for (uint64 i_; i_ < targetNonce_ - startingNonce_; ++i_) {
            payable(account_).transfer(0);
        }
    }
}
