// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IUpgrader } from "../interfaces/IUpgrader.sol";

import { Upgrader } from "./Upgrader.sol";

/**
 * @title  Mainnet upgrader contract.
 * @author M^0 Labs
 */
contract MainnetUpgrader is Upgrader {
    uint16 internal constant _MAINNET_WORMHOLE_CHAIN_ID = 2;
    uint16 internal constant _BASE_WORMHOLE_CHAIN_ID = 30;
    uint16 internal constant _OPTIMISM_WORMHOLE_CHAIN_ID = 24;

    address internal constant _MAINNET_M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MAINNET_REGISTRAR = 0x975Bf5f212367D09CB7f69D3dc4BA8C9B440aD3A;

    uint8 internal constant _FINALIZED_CONSISTENCY_LEVEL = 15;
    uint256 internal constant _WORMHOLE_GAS_LIMIT = 200_000;

    constructor(address portal_, address wormholeTransceiver_) Upgrader(portal_, wormholeTransceiver_) {}

    /// @inheritdoc IUpgrader
    function execute() external override {
        if (block.chainid == 1) {
            _upgradeHubPortal(
                PortalUpgradeParams({
                    mToken: _MAINNET_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _MAINNET_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B,
                    wormholeRelayerAddr: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 8453) {
            _upgradeSpokePortal(
                PortalUpgradeParams({
                    mToken: _MAINNET_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _BASE_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _BASE_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0xbebdb6C8ddC678FfA9f8748f85C815C556Dd8ac6,
                    wormholeRelayerAddr: 0x706F82e9bb5b0813501714Ab5974216704980e31,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        } else if (block.chainid == 10) {
            _upgradeSpokePortal(
                PortalUpgradeParams({
                    mToken: _MAINNET_M_TOKEN,
                    registrar: _MAINNET_REGISTRAR,
                    wormholeChainId: _OPTIMISM_WORMHOLE_CHAIN_ID
                })
            );

            _upgradeWormholeTransceiver(
                WormholeTransceiverUpgradeParams({
                    wormholeChainId: _OPTIMISM_WORMHOLE_CHAIN_ID,
                    wormholeCoreBridge: 0xEe91C335eab126dF5fDB3797EA9d6aD93aeC9722,
                    wormholeRelayerAddr: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayerAddr: address(0),
                    consistencyLevel: _FINALIZED_CONSISTENCY_LEVEL,
                    gasLimit: _WORMHOLE_GAS_LIMIT
                })
            );
        }
    }
}