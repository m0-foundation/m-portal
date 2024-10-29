// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IConfigurator } from "../../../../src/governance/interfaces/IConfigurator.sol";
import { Configurator } from "../../../../src/governance/Configurator.sol";

/**
 * @title  Sepolia configurator contract.
 * @author M^0 Labs
 */
contract SepoliaConfigurator is Configurator {
    /// @dev Sepolia Wormhole chain ID.
    uint16 internal constant _SEPOLIA_WORMHOLE_CHAIN_ID = 10002;

    /// @dev Base Sepolia Wormhole chain ID.
    uint16 internal constant _BASE_SEPOLIA_WORMHOLE_CHAIN_ID = 10004;

    /// @dev Optimism Sepolia Wormhole chain ID.
    uint16 internal constant _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID = 10005;

    /**
     * @dev    Constructs the SepoliaConfigurator contract.
     * @param  portal_              The address of the Portal.
     * @param  wormholeTransceiver_ The address of the Wormhole transceiver.
     */
    constructor(address portal_, address wormholeTransceiver_) Configurator(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IConfigurator
    function configure() external override {
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
}
