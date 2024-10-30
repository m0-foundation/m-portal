// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../../lib/forge-std/src/Script.sol";

import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { Utils } from "../helpers/Utils.sol";

contract ConfigureBase is Script, Utils {
    struct ChainConfig {
        uint16 chainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        bytes32 portal;
        bytes32 wormholeTransceiver;
    }

    function _configurePortal(
        INttManager portal_,
        ChainConfig[] memory targetConfigs_,
        uint16 sourceWormholeChainId_
    ) internal {
        for (uint256 i_; i_ < targetConfigs_.length; ++i_) {
            ChainConfig memory targetConfig_ = targetConfigs_[i_];

            if (targetConfig_.chainId == sourceWormholeChainId_) {
                continue;
            } else {
                portal_.setPeer(targetConfig_.chainId, targetConfig_.portal, _M_TOKEN_DECIMALS, 0);
                console2.log("Peer set for chain: %s", targetConfig_.chainId);
            }
        }
    }

    function _configureWormholeTransceiver(
        IWormholeTransceiver wormholeTransceiver_,
        ChainConfig[] memory targetConfigs_,
        uint16 sourceWormholeChainId_
    ) internal {
        for (uint256 i_; i_ < targetConfigs_.length; ++i_) {
            ChainConfig memory targetConfig_ = targetConfigs_[i_];

            if (targetConfig_.chainId == sourceWormholeChainId_) {
                continue;
            } else {
                if (targetConfig_.isWormholeRelayingEnabled) {
                    wormholeTransceiver_.setIsWormholeRelayingEnabled(targetConfig_.chainId, true);
                    console2.log("Wormhole relaying enabled for chain: %s", targetConfig_.chainId);
                } else if (targetConfig_.isSpecialRelayingEnabled) {
                    wormholeTransceiver_.setIsSpecialRelayingEnabled(targetConfig_.chainId, true);
                    console2.log("Special relaying enabled for chain: %s", targetConfig_.chainId);
                }

                wormholeTransceiver_.setWormholePeer(targetConfig_.chainId, targetConfig_.wormholeTransceiver);
                console2.log("Wormhole peer set for chain: %s", targetConfig_.chainId);

                if (targetConfig_.isEvmChain) {
                    wormholeTransceiver_.setIsWormholeEvmChain(targetConfig_.chainId, true);
                    console2.log("EVM chain set for chain: %s", targetConfig_.chainId);
                } else {
                    console2.log("This is not an EVM chain, doing nothing.");
                }
            }
        }
    }
}
