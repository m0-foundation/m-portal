// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Script.sol";

import { DeployBase } from "../DeployBase.sol";

contract DeployDevSpoke is DeployBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));
        address migrationAdmin_ = deployer_;

        if (block.chainid == _BASE_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            (
                address spokeBaseSepoliaPortal_,
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

            (, address spokeBaseSepoliaVault_) = _deploySpokeVault(
                deployer_,
                spokeBaseSepoliaPortal_,
                _SEPOLIA_VAULT,
                _SEPOLIA_WORMHOLE_CHAIN_ID,
                migrationAdmin_
            );

            (
                address spokeBaseSepoliaSmartMTokenImplementation_,
                address spokeBaseSepoliaSmartMTokenProxy_
            ) = _deploySpokeSmartMToken(
                    deployer_,
                    spokeBaseSepoliaMToken_,
                    spokeBaseSepoliaRegistrar_,
                    spokeBaseSepoliaVault_,
                    migrationAdmin_,
                    _burnNonces
                );

            vm.stopBroadcast();

            console2.log("Base Sepolia Spoke Portal address:", spokeBaseSepoliaPortal_);
            console2.log("Base Sepolia Spoke Wormhole Transceiver address:", spokeBaseSepoliaWormholeTransceiver_);
            console2.log("Base Sepolia Spoke Registrar address:", spokeBaseSepoliaRegistrar_);
            console2.log("Base Sepolia Spoke MToken address:", spokeBaseSepoliaMToken_);
            console2.log("Base Sepolia Spoke Vault address:", spokeBaseSepoliaVault_);
            console2.log(
                "Base Sepolia SmartMToken implementation address:",
                spokeBaseSepoliaSmartMTokenImplementation_
            );
            console2.log("Base Sepolia Spoke MToken proxy address:", spokeBaseSepoliaSmartMTokenProxy_);
        } else if (block.chainid == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            (
                address spokeOptimismSepoliaPortal_,
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

            (, address spokeOptimismSepoliaVault_) = _deploySpokeVault(
                deployer_,
                spokeOptimismSepoliaPortal_,
                _SEPOLIA_VAULT,
                _SEPOLIA_WORMHOLE_CHAIN_ID,
                migrationAdmin_
            );

            (
                address spokeOptimismSepoliaSmartMTokenImplementation_,
                address spokeOptimismSepoliaSmartMTokenProxy_
            ) = _deploySpokeSmartMToken(
                    deployer_,
                    spokeOptimismSepoliaMToken_,
                    spokeOptimismSepoliaRegistrar_,
                    spokeOptimismSepoliaVault_,
                    migrationAdmin_,
                    _burnNonces
                );

            console2.log("Optimism Sepolia Spoke Portal address:", spokeOptimismSepoliaPortal_);
            console2.log(
                "Optimism Sepolia Spoke Wormhole Transceiver address:",
                spokeOptimismSepoliaWormholeTransceiver_
            );
            console2.log("Optimism Sepolia Spoke Registrar address:", spokeOptimismSepoliaRegistrar_);
            console2.log("Optimism Sepolia Spoke MToken address:", spokeOptimismSepoliaMToken_);
            console2.log("Optimism Sepolia Spoke Vault address:", spokeOptimismSepoliaVault_);
            console2.log(
                "Optimism Sepolia SmartMToken implementation address:",
                spokeOptimismSepoliaSmartMTokenImplementation_
            );
            console2.log("Optimism Sepolia Spoke MToken proxy address:", spokeOptimismSepoliaSmartMTokenProxy_);

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
