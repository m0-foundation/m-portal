// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IUpgrader } from "../interfaces/IUpgrader.sol";

import { Upgrader } from "./Upgrader.sol";

/**
 * @title  Sepolia upgrader contract.
 * @author M^0 Labs
 */
contract SepoliaUpgrader is Upgrader {
    /// @dev Sepolia Wormhole chain ID.
    uint16 internal constant _SEPOLIA_WORMHOLE_CHAIN_ID = 10002;

    /// @dev Base Sepolia Wormhole chain ID.
    uint16 internal constant _BASE_SEPOLIA_WORMHOLE_CHAIN_ID = 10004;

    /// @dev Optimism Sepolia Wormhole chain ID.
    uint16 internal constant _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID = 10005;

    /// @dev Sepolia Spoke M token address.
    address internal constant _SEPOLIA_SPOKE_M_TOKEN = 0xCEC6566b227a95C76a0E3dbFdC7794CA795C7F9e;

    /// @dev Sepolia Spoke Registrar address.
    address internal constant _SEPOLIA_SPOKE_REGISTRAR = 0x39a5F8C5ADC500E1d30115c09A1016764D90bC94;

    /// @dev Instant consistency level.
    uint8 internal constant _INSTANT_CONSISTENCY_LEVEL = 200;

    /// @dev Wormhole gas limit.
    uint256 internal constant _WORMHOLE_GAS_LIMIT = 200_000;

    /**
     * @dev   Constructs the SepoliaUpgrader contract.
     * @param portal_              Address of the Portal contract.
     * @param wormholeTransceiver_ Address of the Wormhole transceiver contract.
     */
    constructor(address portal_, address wormholeTransceiver_) Upgrader(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IUpgrader
    function execute() external override {
        if (block.chainid == 11155111) {
            _upgradeHubPortal(
                PortalUpgradeParams({
                    mToken: 0x0c941AD94Ca4A52EDAeAbF203b61bdd1807CeEC0,
                    registrar: 0x975Bf5f212367D09CB7f69D3dc4BA8C9B440aD3A,
                    wormholeChainId: _SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78,
                    wormholeRelayerAddr: 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 84532) {
            _upgradeSpokePortal(
                PortalUpgradeParams({
                    mToken: _SEPOLIA_SPOKE_M_TOKEN,
                    registrar: _SEPOLIA_SPOKE_REGISTRAR,
                    wormholeChainId: _BASE_SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _BASE_SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0x79A1027a6A159502049F10906D333EC57E95F083,
                    wormholeRelayerAddr: 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 11155420) {
            _upgradeSpokePortal(
                PortalUpgradeParams({
                    mToken: _SEPOLIA_SPOKE_M_TOKEN,
                    registrar: _SEPOLIA_SPOKE_REGISTRAR,
                    wormholeChainId: _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0x31377888146f3253211EFEf5c676D41ECe7D58Fe,
                    wormholeRelayerAddr: 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        }
    }
}
