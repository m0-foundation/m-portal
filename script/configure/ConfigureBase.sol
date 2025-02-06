// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { ScriptBase } from "../ScriptBase.sol";

contract ConfigureBase is ScriptBase {
    using stdJson for string;

    struct ChainConfig {
        uint256 chainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        address mToken;
        address portal;
        address transceiver;
        uint16 wormholeChainId;
        address wrappedMToken;
    }

    function _configurePortal(
        address portal_,
        ChainConfig[] memory targetChains_,
        ChainConfig memory sourceChain_
    ) internal {
        for (uint256 i_; i_ < targetChains_.length; ++i_) {
            ChainConfig memory targetChain_ = targetChains_[i_];

            if (targetChain_.wormholeChainId != sourceChain_.wormholeChainId) {
                uint16 destinationChainId_ = targetChain_.wormholeChainId;
                bytes32 destinationMToken_ = _toUniversalAddress(targetChain_.mToken);
                bytes32 destinationWrappedMToken_ = _toUniversalAddress(targetChain_.wrappedMToken);

                INttManager(portal_).setPeer(
                    destinationChainId_,
                    _toUniversalAddress(targetChain_.portal),
                    _M_TOKEN_DECIMALS,
                    0
                );
                console.log("Peer set for chain: %s", targetChain_.wormholeChainId);

                IPortal(portal_).setDestinationMToken(targetChain_.wormholeChainId, destinationMToken_);
                console.log("Destination M token set for chain: %s", targetChain_.wormholeChainId);

                IPortal(portal_).setSupportedBridgingPath(
                    sourceChain_.mToken,
                    targetChain_.wormholeChainId,
                    destinationMToken_,
                    true
                );
                IPortal(portal_).setSupportedBridgingPath(
                    sourceChain_.wrappedMToken,
                    targetChain_.wormholeChainId,
                    destinationMToken_,
                    true
                );
                IPortal(portal_).setSupportedBridgingPath(
                    sourceChain_.mToken,
                    targetChain_.wormholeChainId,
                    destinationWrappedMToken_,
                    true
                );
                IPortal(portal_).setSupportedBridgingPath(
                    sourceChain_.wrappedMToken,
                    targetChain_.wormholeChainId,
                    destinationWrappedMToken_,
                    true
                );
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

            if (targetConfig_.wormholeChainId != sourceWormholeChainId_) {
                if (targetConfig_.isWormholeRelayingEnabled) {
                    wormholeTransceiver_.setIsWormholeRelayingEnabled(targetConfig_.wormholeChainId, true);
                    console.log("Wormhole relaying enabled for chain: %s", targetConfig_.chainId);
                } else if (targetConfig_.isSpecialRelayingEnabled) {
                    wormholeTransceiver_.setIsSpecialRelayingEnabled(targetConfig_.wormholeChainId, true);
                    console.log("Special relaying enabled for chain: %s", targetConfig_.chainId);
                }

                wormholeTransceiver_.setWormholePeer(
                    targetConfig_.wormholeChainId,
                    _toUniversalAddress(targetConfig_.transceiver)
                );

                console.log("Wormhole peer set for chain: %s", targetConfig_.chainId);

                if (targetConfig_.isEvmChain) {
                    wormholeTransceiver_.setIsWormholeEvmChain(targetConfig_.wormholeChainId, true);
                    console.log("EVM chain set for chain: %s", targetConfig_.chainId);
                } else {
                    console.log("This is not an EVM chain, doing nothing.");
                }
            }
        }
    }

    function _loadChainConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (ChainConfig[] memory chainConfig_) {
        bytes memory data = vm.parseJson(vm.readFile(filepath_));
        chainConfig_ = abi.decode(data, (ChainConfig[]));

        uint256 configKeysLength_ = chainConfig_.length;

        console.log("Chains config for chain ID %s loaded.", chainId_);
        console.log("=======================================================");

        for (uint256 i_; i_ < configKeysLength_; ++i_) {
            console.log("Config for chain ID:", chainConfig_[i_].chainId);
            console.log("Wormhole chain ID:", chainConfig_[i_].wormholeChainId);
            console.log("Is EVM chain:", chainConfig_[i_].isEvmChain);
            console.log("Is special relaying enabled:", chainConfig_[i_].isSpecialRelayingEnabled);
            console.log("Is Wormhole relaying enabled:", chainConfig_[i_].isWormholeRelayingEnabled);
            console.log("Portal:", vm.toString(chainConfig_[i_].portal));
            console.log("Transceiver:", vm.toString(chainConfig_[i_].transceiver));
            console.log("M Token:", vm.toString(chainConfig_[i_].mToken));
            console.log("Wrapped M Token:", vm.toString(chainConfig_[i_].wrappedMToken));
            console.log("=======================================================");
        }
    }
}
