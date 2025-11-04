// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    IWormholeTransceiverState
} from "../../lib/native-token-transfers/evm/src/interfaces/IWormholeTransceiverState.sol";

import { IPortal } from "../../src/interfaces/IPortal.sol";
import { PeersConfig, PeerConfig } from "../config/PeersConfig.sol";

import { Chains } from "../config/Chains.sol";
import { MultiSigBatchBase } from "../MultiSigBatchBase.sol";
import { ConfigureBase } from "./ConfigureBase.sol";

contract ProposeConfigure is ConfigureBase, MultiSigBatchBase {
    using Chains for *;

    address constant _SAFE_MULTISIG = 0xdcf79C332cB3Fe9d39A830a5f8de7cE6b1BD6fD1;

    function run(uint16[] memory peerChainIds_) external {
        address deployer_ = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        (address mToken_, address portal_, , address transceiver_, , address wrappedMToken_) = _readDeployment(
            block.chainid
        );

        uint256 peersCount_ = peerChainIds_.length;

        PeerConfig[] memory peers_ = PeersConfig.getPeersConfig(peerChainIds_);

        for (uint256 i; i < peersCount_; i++) {
            PeerConfig memory peer_ = peers_[i];
            uint16 destinationChainId_ = peer_.wormholeChainId;

            // Configure Peer
            _addToBatch(
                portal_,
                abi.encodeCall(INttManager.setPeer, (destinationChainId_, peer_.portal, _M_TOKEN_DECIMALS, 0))
            );

            // Destination M token
            _addToBatch(portal_, abi.encodeCall(IPortal.setDestinationMToken, (destinationChainId_, peer_.mToken)));

            // Supported Bridging Paths
            // M => M
            _addToBatch(
                portal_,
                abi.encodeCall(IPortal.setSupportedBridgingPath, (mToken_, destinationChainId_, peer_.mToken, true))
            );

            // Wrapped M => M
            _addToBatch(
                portal_,
                abi.encodeCall(
                    IPortal.setSupportedBridgingPath,
                    (wrappedMToken_, destinationChainId_, peer_.mToken, true)
                )
            );

            if (peer_.wrappedMToken != bytes32(0)) {
                // M => Wrapped M
                _addToBatch(
                    portal_,
                    abi.encodeCall(
                        IPortal.setSupportedBridgingPath,
                        (mToken_, destinationChainId_, peer_.wrappedMToken, true)
                    )
                );
                // Wrapped M => Wrapped M
                _addToBatch(
                    portal_,
                    abi.encodeCall(
                        IPortal.setSupportedBridgingPath,
                        (wrappedMToken_, destinationChainId_, peer_.wrappedMToken, true)
                    )
                );
            }

            // Transceiver Peer Setup
            if (peer_.wormholeRelaying) {
                _addToBatch(
                    transceiver_,
                    abi.encodeCall(IWormholeTransceiverState.setIsWormholeRelayingEnabled, (destinationChainId_, true))
                );
            } else if (peer_.specialRelaying) {
                _addToBatch(
                    transceiver_,
                    abi.encodeCall(IWormholeTransceiverState.setIsSpecialRelayingEnabled, (destinationChainId_, true))
                );
            }

            _addToBatch(
                transceiver_,
                abi.encodeCall(IWormholeTransceiverState.setWormholePeer, (destinationChainId_, peer_.transceiver))
            );

            if (peer_.isEvm) {
                _addToBatch(
                    transceiver_,
                    abi.encodeCall(IWormholeTransceiverState.setIsWormholeEvmChain, (destinationChainId_, true))
                );
            }
        }

        _simulateBatch(_SAFE_MULTISIG);
        _proposeBatch(_SAFE_MULTISIG, deployer_);
    }
}
