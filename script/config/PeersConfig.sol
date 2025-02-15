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

    address internal constant MAINNET_M_TOKEN_ADDRESS = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant MAINNET_PORTAL_ADDRESS = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
    address internal constant MAINNET_TRANSCEIVER_ADDRESS = 0x0763196A091575adF99e2306E5e90E0Be5154841;
    address internal constant MAINNET_WRAPPED_M_ADDRESS = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    address internal constant TESTNET_M_TOKEN_ADDRESS = 0x58582438ab47FfA2206570AC93E85B42640bef09;
    address internal constant TESTNET_PORTAL_ADDRESS = 0xf1669804140fA31cdAA805A1B3Be91e6282D5e41;
    address internal constant TESTNET_TRANSCEIVER_ADDRESS = 0xb1725758f7255B025cdbF2814Bc428B403623562;
    address internal constant TESTNET_WRAPPED_M_ADDRESS = 0x71c72Ee9F587DAC1df749940c7581E4BbC789F85;

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
        if (peerChainId_ == Chains.ETHEREUM) return _getMainnetPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.ARBITRUM) return _getMainnetPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.OPTIMISM) return _getMainnetPeerConfig(peerChainId_);

        if (peerChainId_ == Chains.ETHEREUM_SEPOLIA)
            return
                PeerConfig({
                    wormholeChainId: peerChainId_.toWormholeChainId(),
                    mToken: 0x245902cAB620E32DF09DA4a26094064e096dd480.toBytes32(),
                    portal: TESTNET_PORTAL_ADDRESS.toBytes32(),
                    wrappedMToken: 0xe91A93a2B782781744a07118bab5855fb256b881.toBytes32(),
                    transceiver: TESTNET_TRANSCEIVER_ADDRESS.toBytes32(),
                    isEvm: true,
                    specialRelaying: false,
                    wormholeRelaying: true
                });

        if (peerChainId_ == Chains.ARBITRUM_SEPOLIA) return _getTestnetPeerConfig(peerChainId_);
        if (peerChainId_ == Chains.OPTIMISM_SEPOLIA) return _getTestnetPeerConfig(peerChainId_);
    }

    /// @dev Returns the configuration for Mainnet chains
    ///      Assumes the same addresses on all chains
    function _getMainnetPeerConfig(uint256 peerChainId_) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerChainId_.toWormholeChainId(),
                mToken: MAINNET_M_TOKEN_ADDRESS.toBytes32(),
                portal: MAINNET_PORTAL_ADDRESS.toBytes32(),
                wrappedMToken: MAINNET_WRAPPED_M_ADDRESS.toBytes32(),
                transceiver: MAINNET_TRANSCEIVER_ADDRESS.toBytes32(),
                isEvm: true,
                specialRelaying: false,
                wormholeRelaying: true
            });
    }

    function _getTestnetPeerConfig(uint256 peerChainId_) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerChainId_.toWormholeChainId(),
                mToken: TESTNET_M_TOKEN_ADDRESS.toBytes32(),
                portal: TESTNET_PORTAL_ADDRESS.toBytes32(),
                wrappedMToken: TESTNET_WRAPPED_M_ADDRESS.toBytes32(),
                transceiver: TESTNET_TRANSCEIVER_ADDRESS.toBytes32(),
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
            peers_ = new uint256[](2);
            peers_[0] = Chains.ARBITRUM_SEPOLIA;
            peers_[1] = Chains.OPTIMISM_SEPOLIA;
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
