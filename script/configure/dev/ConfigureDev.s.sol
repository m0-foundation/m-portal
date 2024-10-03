// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console2 } from "../../../lib/forge-std/src/Script.sol";

import { INttManager } from "../../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { ConfigureBase } from "../ConfigureBase.sol";

contract ConfigureDev is ConfigureBase {
    function run() external {
        address deployer_ = vm.rememberKey(vm.envUint("DEV_PRIVATE_KEY"));

        address portal_ = _getCreate3Address(deployer_, _computeSalt(deployer_, "Portal"));
        bytes32 portalUniversalAddress_ = _toUniversalAddress(portal_);

        address wormholeTransceiver_ = _getCreate3Address(deployer_, _computeSalt(deployer_, "WormholeTransceiver"));
        bytes32 wormholeTransceiverUniversalAddress_ = _toUniversalAddress(wormholeTransceiver_);

        ChainConfig[] memory sepoliaConfig_ = new ChainConfig[](3);
        sepoliaConfig_[0] = ChainConfig({
            chainId: _SEPOLIA_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        sepoliaConfig_[1] = ChainConfig({
            chainId: _BASE_SEPOLIA_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        sepoliaConfig_[2] = ChainConfig({
            chainId: _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        if (block.chainid == _SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            _configureWormholeTransceiver(
                IWormholeTransceiver(wormholeTransceiver_),
                sepoliaConfig_,
                _SEPOLIA_WORMHOLE_CHAIN_ID
            );
            _configurePortal(INttManager(portal_), sepoliaConfig_, _SEPOLIA_WORMHOLE_CHAIN_ID);

            vm.stopBroadcast();
        } else if (block.chainid == _BASE_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            _configureWormholeTransceiver(
                IWormholeTransceiver(wormholeTransceiver_),
                sepoliaConfig_,
                _BASE_SEPOLIA_WORMHOLE_CHAIN_ID
            );

            _configurePortal(INttManager(portal_), sepoliaConfig_, _BASE_SEPOLIA_WORMHOLE_CHAIN_ID);

            vm.stopBroadcast();
        } else if (block.chainid == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            vm.startBroadcast(deployer_);

            _configureWormholeTransceiver(
                IWormholeTransceiver(wormholeTransceiver_),
                sepoliaConfig_,
                _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID
            );

            _configurePortal(INttManager(portal_), sepoliaConfig_, _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID);

            vm.stopBroadcast();
        } else {
            console2.log("Chain id: {}", block.chainid);
            revert("Unsupported chain id.");
        }
    }
}
