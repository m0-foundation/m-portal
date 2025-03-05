// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { ManagerBase } from "../../lib/native-token-transfers/evm/src/NttManager/ManagerBase.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";
import { OwnableUpgradeable } from "../../lib/native-token-transfers/evm/src/libraries/external/OwnableUpgradeable.sol";
import { WrappedMToken } from "../../lib/wrapped-m-token/src/WrappedMToken.sol";

import { SpokeVault } from "../../src/SpokeVault.sol";
import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { IPortal } from "../../src/interfaces/IPortal.sol";
import { IMTokenLike } from "../../src/interfaces/IMTokenLike.sol";
import { Chains } from "../config/Chains.sol";
import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";
import { WormholeConfig, WormholeTransceiverConfig } from "../config/WormholeConfig.sol";
import { ScriptBase } from "../ScriptBase.sol";

contract GetPortalInfo is ScriptBase {
    using WormholeConfig for uint256;
    using TypeConverter for *;

    function run() public {
        uint256 chainId_ = block.chainid;

        (
            address mToken_,
            address portal_,
            address registrar_,
            address transceiver_,
            address vault_,
            address wrappedMToken_
        ) = _readDeployment(chainId_);

        console.log("Chain Id:                ", chainId_);
        console.log("M Token:                 ", mToken_);
        console.log("Portal:                  ", portal_);
        console.log("Registrar:               ", registrar_);
        console.log("WrappedM Token:          ", wrappedMToken_);
        console.log("Vault:                   ", vault_);

        console.log("");
        console.log("WORMHOLE SETTINGS");
        console.log("====================================================================");
        console.log("Wormhole Chain Id:       ", ManagerBase(portal_).chainId());
        console.log("Transceiver:             ", transceiver_);
        console.log("Consistency Level:       ", WormholeTransceiver(transceiver_).consistencyLevel());
        console.log("Gas Limit:               ", WormholeTransceiver(transceiver_).gasLimit());
        console.log("Core Bridge:             ", address(WormholeTransceiver(transceiver_).wormhole()));
        console.log("Wormhole Relayer:        ", address(WormholeTransceiver(transceiver_).wormholeRelayer()));
        console.log("Special Relayer:         ", address(WormholeTransceiver(transceiver_).specialRelayer()));
        console.log("Threshold:               ", INttManager(portal_).getThreshold());

        console.log("");
        console.log("EARNING STATUS");
        console.log("====================================================================");
        console.log("Portal Earning:          ", IMTokenLike(mToken_).isEarning(portal_));
        console.log("WrappedM Earning:        ", IMTokenLike(mToken_).isEarning(wrappedMToken_));

        console.log("");
        console.log("OWNERSHIP");
        console.log("====================================================================");
        console.log("Portal Owner:            ", OwnableUpgradeable(portal_).owner());
        console.log("Transceiver Owner:       ", OwnableUpgradeable(transceiver_).owner());
        console.log("WrappedM Migration Admin:", WrappedMToken(wrappedMToken_).migrationAdmin());

        if (!Chains.isHub(chainId_)) {
            console.log("Vault Migration Admin:   ", SpokeVault(payable(vault_)).migrationAdmin());
        }

        _listPeers(chainId_, portal_, transceiver_, mToken_, wrappedMToken_);
    }

    function _listPeers(
        uint256 chainId_,
        address portal_,
        address transceiver_,
        address mToken_,
        address wrappedMToken_
    ) private {
        console.log("");
        console.log("PEERS");
        console.log("====================================================================");
        uint256[] memory peers_ = PeersConfig.getPeerChains(chainId_);
        uint256 peersCount_ = peers_.length;
        for (uint256 i = 0; i < peersCount_; i++) {
            uint256 peerChainId_ = peers_[i];
            uint16 peerWormholeChainId_ = peerChainId_.toWormholeChainId();
            bool isEvm_ = WormholeTransceiver(transceiver_).isWormholeEvmChain(peerWormholeChainId_);
            bytes32 peerPortal_ = INttManager(portal_).getPeer(peerWormholeChainId_).peerAddress;
            bytes32 peerTransceiver_ = WormholeTransceiver(transceiver_).getWormholePeer(peerWormholeChainId_);
            bytes32 peerMToken_ = IPortal(portal_).destinationMToken(peerWormholeChainId_);

            console.log("Peer ChainId:            ", peerChainId_);
            console.log("Peer Wormhole ChainId:   ", peerWormholeChainId_);
            if (isEvm_) {
                console.log("Peer Portal:             ", peerPortal_.toAddress());
                console.log("Peer MToken:             ", peerMToken_.toAddress());
                console.log("Peer Transceiver:        ", peerTransceiver_.toAddress());
            } else {
                console.log("Peer Portal:");
                console.logBytes32(peerPortal_);
                console.log("Peer MToken:");
                console.logBytes32(peerMToken_);
                console.log("Peer Transceiver:");
                console.logBytes32(peerTransceiver_);
            }

            // bridging paths
            console.log(
                "Bridging M => M:         ",
                IPortal(portal_).supportedBridgingPath(mToken_, peerWormholeChainId_, peerMToken_)
            );
            console.log(
                "Bridging wM => M:        ",
                IPortal(portal_).supportedBridgingPath(wrappedMToken_, peerWormholeChainId_, peerMToken_)
            );
            if (isEvm_) {
                (, , , , , address peerWrappedMToken_) = _readDeployment(peerChainId_);
                console.log(
                    "Bridging M => wM:        ",
                    IPortal(portal_).supportedBridgingPath(
                        mToken_,
                        peerWormholeChainId_,
                        peerWrappedMToken_.toBytes32()
                    )
                );
                console.log(
                    "Bridging wM => wM:       ",
                    IPortal(portal_).supportedBridgingPath(
                        wrappedMToken_,
                        peerWormholeChainId_,
                        peerWrappedMToken_.toBytes32()
                    )
                );
            }

            console.log("====================================================================");
        }
    }
}
