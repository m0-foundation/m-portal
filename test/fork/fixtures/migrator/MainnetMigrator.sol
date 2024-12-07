// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IMigrator } from "../../../../src/governance/interfaces/IMigrator.sol";
import { Migrator } from "../../../../src/governance/Migrator.sol";

/**
 * @title  Mainnet migrator contract.
 * @author M^0 Labs
 */
contract MainnetMigrator is Migrator {
    /// @dev Mainnet Wormhole chain ID.
    uint16 internal constant _MAINNET_WORMHOLE_CHAIN_ID = 2;

    /// @dev Base Wormhole chain ID.
    uint16 internal constant _BASE_WORMHOLE_CHAIN_ID = 30;

    /// @dev Optimism Wormhole chain ID.
    uint16 internal constant _OPTIMISM_WORMHOLE_CHAIN_ID = 24;

    /// @dev Mainnet MToken address.
    address internal constant _MAINNET_M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;

    /// @dev Mainnet Smart MToken address.
    address internal constant _MAINNET_SMART_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    /// @dev Mainnet Registrar address.
    address internal constant _MAINNET_REGISTRAR = 0x975Bf5f212367D09CB7f69D3dc4BA8C9B440aD3A;

    /// @dev Finalized consistency level for Wormhole transceivers.
    uint8 internal constant _FINALIZED_CONSISTENCY_LEVEL = 15;

    /// @dev Gas limit for Wormhole messages.
    uint256 internal constant _HIGH_WORMHOLE_GAS_LIMIT = 300_000;

    /**
     * @dev    Constructs the MainnetMigrator contract.
     * @param  portal_              The address of the Portal.
     * @param  wormholeTransceiver_ The address of the WormholeTransceiver.
     * @param  vault_               The address of the Vault.
     */
    constructor(
        address portal_,
        address wormholeTransceiver_,
        address vault_
    ) Migrator(portal_, wormholeTransceiver_, vault_) {}

    /// @inheritdoc IMigrator
    function migrate() external override {
        if (block.chainid == 1) {
            _migrateHubPortal(
                PortalMigrateParams({
                    mToken: _MAINNET_M_TOKEN,
                    smartMToken: _MAINNET_SMART_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID
                })
            );

            _migrateWormholeTransceiver(
                WormholeTransceiverMigrateParams({
                    wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B,
                    wormholeRelayerAddr: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _HIGH_WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 8453) {
            _migrateSpokePortal(
                PortalMigrateParams({
                    mToken: _MAINNET_M_TOKEN,
                    smartMToken: _MAINNET_SMART_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _BASE_WORMHOLE_CHAIN_ID
                })
            );

            _migrateWormholeTransceiver(
                WormholeTransceiverMigrateParams({
                    wormholeChainId: _BASE_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0xbebdb6C8ddC678FfA9f8748f85C815C556Dd8ac6,
                    wormholeRelayerAddr: 0x706F82e9bb5b0813501714Ab5974216704980e31,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _HIGH_WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 10) {
            _migrateSpokePortal(
                PortalMigrateParams({
                    mToken: _MAINNET_M_TOKEN,
                    smartMToken: _MAINNET_SMART_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _OPTIMISM_WORMHOLE_CHAIN_ID
                })
            );

            _migrateWormholeTransceiver(
                WormholeTransceiverMigrateParams({
                    wormholeChainId: _OPTIMISM_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0xEe91C335eab126dF5fDB3797EA9d6aD93aeC9722,
                    wormholeRelayerAddr: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _HIGH_WORMHOLE_GAS_LIMIT
                })
            );
        }
    }
}
