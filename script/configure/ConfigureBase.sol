// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { Utils } from "../helpers/Utils.sol";

contract ConfigureBase is Script, Utils {
    using stdJson for string;

    struct ChainConfig {
        uint256 chainId;
        uint16 wormholeChainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        address portal;
        address wormholeTransceiver;
    }

    function _configurePortal(
        INttManager portal_,
        ChainConfig[] memory targetConfigs_,
        uint16 sourceWormholeChainId_
    ) internal {
        for (uint256 i_; i_ < targetConfigs_.length; ++i_) {
            ChainConfig memory targetConfig_ = targetConfigs_[i_];

            if (targetConfig_.wormholeChainId != sourceWormholeChainId_) {
                portal_.setPeer(
                    targetConfig_.wormholeChainId,
                    _toUniversalAddress(targetConfig_.portal),
                    _M_TOKEN_DECIMALS,
                    0
                );

                console.log("Peer set for chain: %s", targetConfig_.chainId);
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
                    _toUniversalAddress(targetConfig_.wormholeTransceiver)
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
        string memory file_ = vm.readFile(filepath_);
        string[] memory configKeys_ = vm.parseJsonKeys(file_, "$.config");
        uint256 configKeysLength_ = configKeys_.length;

        chainConfig_ = new ChainConfig[](configKeysLength_);

        console.log("Chains config for chain ID %s loaded.", chainId_);
        console.log("=======================================================");

        for (uint256 i_; i_ < configKeysLength_; ++i_) {
            string memory configKey_ = string.concat("$.config.", configKeys_[i_], ".");

            chainConfig_[i_].chainId = vm.parseUint(configKeys_[i_]);
            chainConfig_[i_].wormholeChainId = uint16(file_.readUint(_readKey(configKey_, "wormhole_chain_id")));
            chainConfig_[i_].isEvmChain = file_.readBool(_readKey(configKey_, "is_evm_chain"));
            chainConfig_[i_].isSpecialRelayingEnabled = file_.readBool(
                _readKey(configKey_, "is_special_relaying_enabled")
            );
            chainConfig_[i_].isWormholeRelayingEnabled = file_.readBool(
                _readKey(configKey_, "is_wormhole_relaying_enabled")
            );
            chainConfig_[i_].portal = file_.readAddress(_readKey(configKey_, "portal"));
            chainConfig_[i_].wormholeTransceiver = file_.readAddress(_readKey(configKey_, "wormhole_transceiver"));

            console.log("Config for chain ID:", chainConfig_[i_].chainId);
            console.log("Wormhole chain ID:", chainConfig_[i_].wormholeChainId);
            console.log("Is EVM chain:", chainConfig_[i_].isEvmChain);
            console.log("Is special relaying enabled:", chainConfig_[i_].isSpecialRelayingEnabled);
            console.log("Is Wormhole relaying enabled:", chainConfig_[i_].isWormholeRelayingEnabled);
            console.log("Portal:", vm.toString(chainConfig_[i_].portal));
            console.log("Wormhole transceiver:", vm.toString(chainConfig_[i_].wormholeTransceiver));
            console.log("=======================================================");
        }
    }
}
