// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { TypeConverter } from "../../src/libs/TypeConverter.sol";
import { Chains } from "./Chains.sol";
import { WormholeConfig } from "./WormholeConfig.sol";

struct PeerConfig {
    uint16 wormholeChainId;
    bytes32 mToken;
    bytes32 portal;
    bytes32 wrappedMToken;
    bytes32 transceiver;
    bool isEvm;
    bool specialRelaying;
    bool wormholeRelaying;
}

library PeersConfig {
    using WormholeConfig for uint256;
    using TypeConverter for address;

    address internal constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant PORTAL = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
    address internal constant TRANSCEIVER = 0x0763196A091575adF99e2306E5e90E0Be5154841;
    address internal constant WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    function getPeersConfig(uint256 sourceChainId_) internal pure returns (PeerConfig[] memory _portalPeerConfig) {
        uint256[] memory peers_ = getPeerChains(sourceChainId_);
        return getPeersConfig(peers_);
    }

    function getPeersConfig(uint256[] memory peers_) internal pure returns (PeerConfig[] memory _portalPeerConfig) {
        uint256 peersCount_ = peers_.length;
        _portalPeerConfig = new PeerConfig[](peersCount_);

        for (uint256 i = 0; i < peersCount_; i++) {
            _portalPeerConfig[i] = getPeerConfig(peers_[i]);
        }
    }

    function getPeerConfig(uint256 peerChainId_) internal pure returns (PeerConfig memory _portalPeerConfig) {
        if (peerChainId_ == Chains.ETHEREUM) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.ARBITRUM) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.OPTIMISM) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.NOBLE) return getNoblePeerConfig(peerChainId_);

        if (peerChainId_ == Chains.ETHEREUM_SEPOLIA) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.ARBITRUM_SEPOLIA) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.OPTIMISM_SEPOLIA) return _getEvmPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.NOBLE_TESTNET) return getNoblePeerConfig(peerChainId_);
    }

    /// @dev Returns the configuration for Noble chains. The same addresses are used on testnet and mainnet
    function getNoblePeerConfig(uint256 peerChainId_) internal pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerChainId_.toWormholeChainId(),
                mToken: 0x000000000000000000000000000000000000000000000000000000757573646e,
                portal: 0x0000000000000000000000002e859506ba229c183f8985d54fe7210923fb9bca,
                wrappedMToken: bytes32(0),
                transceiver: 0x000000000000000000000000d1c9983597b8e45859df215dedad924b0f8505e3,
                isEvm: false,
                specialRelaying: false,
                wormholeRelaying: false
            });
    }

    /// @dev Returns the configuration for EVM chains. Assumes the same addresses on all chains
    function _getEvmPeerConfig(uint256 peerChainId_) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerChainId_.toWormholeChainId(),
                mToken: M_TOKEN.toBytes32(),
                portal: PORTAL.toBytes32(),
                wrappedMToken: WRAPPED_M_TOKEN.toBytes32(),
                transceiver: TRANSCEIVER.toBytes32(),
                isEvm: true,
                specialRelaying: false,
                wormholeRelaying: true
            });
    }

    function getPeerChains(uint256 chainId_) internal pure returns (uint256[] memory peers_) {
        if (chainId_ == Chains.ETHEREUM) {
            peers_ = new uint256[](2);
            peers_[0] = Chains.ARBITRUM;
            peers_[1] = Chains.OPTIMISM;
        }

        if (chainId_ == Chains.ARBITRUM) {
            peers_ = new uint256[](2);
            peers_[0] = Chains.ETHEREUM;
            peers_[1] = Chains.OPTIMISM;
        }

        if (chainId_ == Chains.OPTIMISM) {
            peers_ = new uint256[](2);
            peers_[0] = Chains.ETHEREUM;
            peers_[1] = Chains.ARBITRUM;
        }

        if (chainId_ == Chains.ETHEREUM_SEPOLIA) {
            peers_ = new uint256[](3);
            peers_[0] = Chains.ARBITRUM_SEPOLIA;
            peers_[1] = Chains.OPTIMISM_SEPOLIA;
            peers_[2] = Chains.NOBLE_TESTNET;
        }

        if (chainId_ == Chains.ARBITRUM_SEPOLIA) {
            peers_ = new uint256[](2);
            peers_[0] = Chains.ETHEREUM_SEPOLIA;
            peers_[1] = Chains.OPTIMISM_SEPOLIA;
        }

        if (chainId_ == Chains.OPTIMISM_SEPOLIA) {
            peers_ = new uint256[](2);
            peers_[0] = Chains.ETHEREUM_SEPOLIA;
            peers_[1] = Chains.ARBITRUM_SEPOLIA;
        }
    }
}
