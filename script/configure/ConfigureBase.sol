// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormholeTransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiver.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { ScriptBase } from "../ScriptBase.sol";
import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";

contract ConfigureBase is ScriptBase {
    using TypeConverter for address;

    function _configurePeers(
        address portal_,
        address mToken_,
        address wrappedMToken_,
        address transceiver_,
        PeerConfig[] memory peers_
    ) internal {
        uint256 peersCount_ = peers_.length;

        for (uint256 i; i < peersCount_; i++) {
            PeerConfig memory peer_ = peers_[i];
            uint16 destinationChainId_ = peer_.wormholeChainId;

            INttManager(portal_).setPeer(destinationChainId_, peer_.portal, _M_TOKEN_DECIMALS, 0);
            IPortal(portal_).setDestinationMToken(destinationChainId_, peer_.mToken);

            // Supported Bridging Paths
            // M => M
            IPortal(portal_).setSupportedBridgingPath(mToken_, destinationChainId_, peer_.mToken, true);
            // M => Wrapped M
            if (peer_.wrappedMToken != address(0).toBytes32()) {
                IPortal(portal_).setSupportedBridgingPath(mToken_, destinationChainId_, peer_.wrappedMToken, true);
            }
            // Wrapped M => M
            IPortal(portal_).setSupportedBridgingPath(wrappedMToken_, destinationChainId_, peer_.mToken, true);
            // Wrapped M => Wrapped M
            if (peer_.wrappedMToken != address(0).toBytes32()) {
                IPortal(portal_).setSupportedBridgingPath(wrappedMToken_, destinationChainId_, peer_.wrappedMToken, true);
            }

            // Transceiver Peer Setup
            if (peer_.wormholeRelaying) {
                IWormholeTransceiver(transceiver_).setIsWormholeRelayingEnabled(destinationChainId_, true);
            } else if (peer_.specialRelaying) {
                IWormholeTransceiver(transceiver_).setIsSpecialRelayingEnabled(destinationChainId_, true);
            }

            IWormholeTransceiver(transceiver_).setWormholePeer(destinationChainId_, peer_.transceiver);

            if (peer_.isEvm) {
                IWormholeTransceiver(transceiver_).setIsWormholeEvmChain(destinationChainId_, true);
            }
        }
    }
}
