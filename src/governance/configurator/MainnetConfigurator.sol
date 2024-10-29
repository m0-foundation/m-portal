// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IConfigurator } from "../interfaces/IConfigurator.sol";

import { Configurator } from "./Configurator.sol";

/**
 * @title  Mainnet configurator contract.
 * @author M^0 Labs
 */
contract MainnetConfigurator is Configurator {
    /// @dev Ethereum Mainnet Wormhole chain ID.
    uint16 internal constant _MAINNET_WORMHOLE_CHAIN_ID = 2;

    /// @dev Base Wormhole chain ID
    uint16 internal constant _BASE_WORMHOLE_CHAIN_ID = 30;

    /// @dev Optimism Wormhole chain ID.
    uint16 internal constant _OPTIMISM_WORMHOLE_CHAIN_ID = 24;

    /**
     * @dev    Constructs the MainnetConfigurator contract.
     * @param  portal_              The address of the Portal.
     * @param  wormholeTransceiver_ The address of the Wormhole transceiver.
     */
    constructor(address portal_, address wormholeTransceiver_) Configurator(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IConfigurator
    function configure() external override {
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
}
