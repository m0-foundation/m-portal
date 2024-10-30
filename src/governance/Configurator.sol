// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { IConfigurator } from "./interfaces/IConfigurator.sol";

/**
 * @title  Base configurator contract.
 * @author M^0 Labs
 * @dev    Base contract that can be inherited by configurator contracts to perform configuration changes.
 */
abstract contract Configurator is IConfigurator {
    /* ============ Struct ============ */

    /// @dev Chain configuration.
    struct ChainConfig {
        uint16 chainId;
        bool isEvmChain;
        bool isSpecialRelayingEnabled;
        bool isWormholeRelayingEnabled;
        bytes32 portal;
        bytes32 wormholeTransceiver;
    }

    /* ============ Variables ============ */

    /// @inheritdoc IConfigurator
    address public immutable portal;

    /// @inheritdoc IConfigurator
    address public immutable wormholeTransceiver;

    /* ============ Constructor ============ */

    /**
     * @dev   Constructs the Configurator contract.
     * @param portal_              Address of the Portal being configured.
     * @param wormholeTransceiver_ Address of the WormholeTransceiver being configured.
     */
    constructor(address portal_, address wormholeTransceiver_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((wormholeTransceiver = wormholeTransceiver_) == address(0)) revert ZeroWormholeTransceiver();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IConfigurator
    function configure() external virtual {}

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev   Sets the Portal's peer for the given Wormhole chain ID.
     * @param peerChainId_ The Wormhole chain ID for which to set the Portal peer.
     * @param peerPortal_  The address of the Portal peer.
     */
    function _setPeerPortal(uint16 peerChainId_, bytes32 peerPortal_) internal {
        INttManager(portal).setPeer(peerChainId_, peerPortal_, 6, 0);
    }

    /**
     * @dev   Sets the Wormhole transceiver's peer for the given Wormhole chain ID.
     * @param peerChainId_             The Wormhole chain ID for which to set the Wormhole transceiver peer.
     * @param peerWormholeTransceiver_ The address of the Wormhole transceiver peer.
     */
    function _setPeerWormholeTransceiver(uint16 peerChainId_, bytes32 peerWormholeTransceiver_) internal {
        IWormholeTransceiver(wormholeTransceiver).setWormholePeer(peerChainId_, peerWormholeTransceiver_);
    }

    /**
     * @dev   Sets the Wormhole relaying enabled flag for the given Wormhole chain ID.
     * @param chainId_           The Wormhole chain ID to set the flag for.
     * @param isRelayingEnabled_ Whether Wormhole relaying is enabled or not.
     */
    function _setIsWormholeRelayingEnabled(uint16 chainId_, bool isRelayingEnabled_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsWormholeRelayingEnabled(chainId_, isRelayingEnabled_);
    }

    /**
     * @dev   Sets the special relaying enabled flag for the given Wormhole chain ID.
     * @param chainId_           The Wormhole chain ID to set the flag for.
     * @param isRelayingEnabled_ Whether special relaying is enabled or not.
     */
    function _setIsSpecialRelayingEnabled(uint16 chainId_, bool isRelayingEnabled_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsSpecialRelayingEnabled(chainId_, isRelayingEnabled_);
    }

    /**
     * @dev   Sets the EVM chain flag for the given Wormhole chain ID.
     * @param chainId_ The Wormhole chain ID to set the flag for.
     * @param isEvm_   Whether the chain is an EVM chain or not.
     */
    function _setIsWormholeEvmChain(uint16 chainId_, bool isEvm_) internal {
        IWormholeTransceiver(wormholeTransceiver).setIsWormholeEvmChain(chainId_, isEvm_);
    }

    /**
     * @dev   Configures the Portal for the given target chains.
     * @param targetConfigs_         The configuration for each target chain.
     * @param sourceWormholeChainId_ The Wormhole chain ID of the source chain.
     */
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

    /**
     * @dev   Configures the Wormhole transceiver for the given target chains.
     * @param targetConfigs_         The configuration for each target chain.
     * @param sourceWormholeChainId_ The Wormhole chain ID of the source chain.
     */
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

    /**
     * @dev    Converts an EVM address to a universal address.
     * @param  evmAddr_   The EVM address to convert.
     * @return converted_ The universal address.
     */
    function _toUniversalAddress(address evmAddr_) internal pure returns (bytes32 converted_) {
        assembly ("memory-safe") {
            converted_ := and(0xffffffffffffffffffffffffffffffffffffffff, evmAddr_)
        }
    }
}
