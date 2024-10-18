// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IConfigurator } from "../interfaces/IConfigurator.sol";

import { Configurator } from "./Configurator.sol";

/**
 * @title  Mainnet configurator contract.
 * @author M^0 Labs
 */
contract MainnetConfigurator is Configurator {
    struct ChainConfig {
        uint16 chainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        bytes32 portal;
        bytes32 wormholeTransceiver;
    }

    uint16 internal constant _MAINNET_WORMHOLE_CHAIN_ID = 2;
    uint16 internal constant _BASE_WORMHOLE_CHAIN_ID = 30;
    uint16 internal constant _OPTIMISM_WORMHOLE_CHAIN_ID = 24;

    constructor(address portal_, address wormholeTransceiver_) Configurator(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IConfigurator
    function execute() external override {
        bytes32 portalUniversalAddress_ = _toUniversalAddress(portal);
        bytes32 wormholeTransceiverUniversalAddress_ = _toUniversalAddress(wormholeTransceiver);

        ChainConfig[] memory mainnetConfig_ = new ChainConfig[](3);
        mainnetConfig_[0] = ChainConfig({
            chainId: _MAINNET_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        mainnetConfig_[1] = ChainConfig({
            chainId: _BASE_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        mainnetConfig_[2] = ChainConfig({
            chainId: _OPTIMISM_WORMHOLE_CHAIN_ID,
            isEvmChain: true,
            isSpecialRelayingEnabled: false,
            isWormholeRelayingEnabled: true,
            portal: portalUniversalAddress_,
            wormholeTransceiver: wormholeTransceiverUniversalAddress_
        });

        if (block.chainid == 1) {
            _configurePortal(mainnetConfig_, _MAINNET_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(mainnetConfig_, _MAINNET_WORMHOLE_CHAIN_ID);
        } else if (block.chainid == 8453) {
            _configurePortal(mainnetConfig_, _BASE_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(mainnetConfig_, _BASE_WORMHOLE_CHAIN_ID);
        } else if (block.chainid == 10) {
            _configurePortal(mainnetConfig_, _OPTIMISM_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(mainnetConfig_, _OPTIMISM_WORMHOLE_CHAIN_ID);
        }
    }

    function _configurePortal(ChainConfig[] memory targetConfigs_, uint16 sourceWormholeChainId_) internal {
        for (uint256 i_; i_ < targetConfigs_.length; ++i_) {
            ChainConfig memory targetConfig_ = targetConfigs_[i_];

            if (targetConfig_.chainId == sourceWormholeChainId_) {
                continue;
            } else {
                _setPeerPortal(targetConfig_.chainId, targetConfig_.portal);
            }
        }
    }

    function _configureWormholeTransceiver(
        ChainConfig[] memory targetConfigs_,
        uint16 sourceWormholeChainId_
    ) internal {
        for (uint256 i_; i_ < targetConfigs_.length; ++i_) {
            ChainConfig memory targetConfig_ = targetConfigs_[i_];

            if (targetConfig_.chainId == sourceWormholeChainId_) {
                continue;
            } else {
                if (targetConfig_.isWormholeRelayingEnabled) {
                    _setIsWormholeRelayingEnabled(targetConfig_.chainId, true);
                } else if (targetConfig_.isSpecialRelayingEnabled) {
                    _setIsSpecialRelayingEnabled(targetConfig_.chainId, true);
                }

                _setPeerWormholeTransceiver(targetConfig_.chainId, targetConfig_.wormholeTransceiver);

                if (targetConfig_.isEvmChain) {
                    _setIsWormholeEvmChain(targetConfig_.chainId, true);
                }
            }
        }
    }

    function _toUniversalAddress(address evmAddr_) internal pure returns (bytes32 converted_) {
        assembly ("memory-safe") {
            converted_ := and(0xffffffffffffffffffffffffffffffffffffffff, evmAddr_)
        }
    }
}
