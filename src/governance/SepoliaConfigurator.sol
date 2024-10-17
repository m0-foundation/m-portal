// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IConfigurator } from "./interfaces/IConfigurator.sol";

import { Configurator } from "./Configurator.sol";

/**
 * @title  Sepolia configurator contract.
 * @author M^0 Labs
 */
contract SepoliaConfigurator is Configurator {
    struct ChainConfig {
        uint16 chainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        bytes32 portal;
        bytes32 wormholeTransceiver;
    }

    uint16 internal constant _SEPOLIA_WORMHOLE_CHAIN_ID = 10002;
    uint16 internal constant _BASE_SEPOLIA_WORMHOLE_CHAIN_ID = 10004;
    uint16 internal constant _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID = 10005;

    constructor(address portal_, address wormholeTransceiver_) Configurator(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IConfigurator
    function execute() external override {
        bytes32 portalUniversalAddress_ = _toUniversalAddress(portal);
        bytes32 wormholeTransceiverUniversalAddress_ = _toUniversalAddress(wormholeTransceiver);

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

        if (block.chainid == 11155111) {
            _configurePortal(sepoliaConfig_, _SEPOLIA_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(sepoliaConfig_, _SEPOLIA_WORMHOLE_CHAIN_ID);
        } else if (block.chainid == 84532) {
            _configurePortal(sepoliaConfig_, _BASE_SEPOLIA_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(sepoliaConfig_, _BASE_SEPOLIA_WORMHOLE_CHAIN_ID);
        } else if (block.chainid == 11155420) {
            _configurePortal(sepoliaConfig_, _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID);
            _configureWormholeTransceiver(sepoliaConfig_, _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID);
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
