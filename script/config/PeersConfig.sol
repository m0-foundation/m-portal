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
    using TypeConverter for address;

    address internal constant M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant PORTAL = 0xD925C84b55E4e44a53749fF5F2a5A13F63D128fd;
    address internal constant TRANSCEIVER = 0x0763196A091575adF99e2306E5e90E0Be5154841;
    address internal constant WRAPPED_M_TOKEN = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    bytes32 internal constant NOBLE_M_TOKEN = 0x000000000000000000000000000000000000000000000000000000757573646e;
    bytes32 internal constant NOBLE_PORTAL = 0x0000000000000000000000002e859506ba229c183f8985d54fe7210923fb9bca;
    bytes32 internal constant NOBLE_TRANSCEIVER = 0x000000000000000000000000d1c9983597b8e45859df215dedad924b0f8505e3;

    bytes32 internal constant SOLANA_M_TOKEN = 0x0b86be66bfceb4c1d7e927bcc4d014be0f2863ab9df85fda610851b64dbd0ae5;
    bytes32 internal constant SOLANA_WRAPPED_M_TOKEN =
        0x0b86be66bc1f98b47d20a3be615a4905a825b826864e2a0f4c948467d33ee709;
    bytes32 internal constant SOLANA_USDK = 0x0d8b7427213bf00314ad7d773e51ed3158573ccbc8aa35181ba8169e54c37582;
    bytes32 internal constant SOLANA_USDKY = 0x0d8b742f62a9c8a57ad10368e9dbbbeba3d31427e1ea84a4385da7ea2f0e3678;

    bytes32 internal constant SOLANA_PORTAL = 0x0b86ec181cd4c5c984e9062b13f2b2de7b9f5b5e68e84349231d6614cdf3f99f;
    bytes32 internal constant SOLANA_TRANSCEIVER = 0xfcbdac3b256685bd2cc3a97bfcd815fb76b8d33df924e607c409c0bce3fa1668;

    function getPeersConfig(uint16 sourceWormholeChainId_) internal pure returns (PeerConfig[] memory _peersConfig) {
        uint16[] memory peerChainIds_ = getPeerChainIds(sourceWormholeChainId_);
        return getPeersConfig(peerChainIds_);
    }

    function getPeersConfig(uint16[] memory peerChainIds_) internal pure returns (PeerConfig[] memory _peersConfig) {
        uint256 peersCount_ = peerChainIds_.length;
        _peersConfig = new PeerConfig[](peersCount_);

        for (uint256 i = 0; i < peersCount_; i++) {
            _peersConfig[i] = getPeerConfig(peerChainIds_[i]);
        }
    }

    function getPeerConfig(uint16 peerWormholeChainId_) internal pure returns (PeerConfig memory _portalPeerConfig) {
        // Mainnet
        if (peerWormholeChainId_ == Chains.WORMHOLE_ETHEREUM) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_BASE) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_ARBITRUM) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_OPTIMISM) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_NOBLE) return _getNoblePeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_SOLANA) return _getSolanaPeerConfig(peerWormholeChainId_);

        // Testnet
        if (peerWormholeChainId_ == Chains.WORMHOLE_ETHEREUM_SEPOLIA) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_ARBITRUM_SEPOLIA) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_OPTIMISM_SEPOLIA) return _getEvmPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_NOBLE_TESTNET) return _getNoblePeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_SOLANA_TESTNET) return _getSolanaPeerConfig(peerWormholeChainId_);
        if (peerWormholeChainId_ == Chains.WORMHOLE_BASE_SEPOLIA) return _getEvmPeerConfig(peerWormholeChainId_);

        revert Chains.UnsupportedWormholeChain(peerWormholeChainId_);
    }

    /// @dev Returns the configuration for Noble chains. The same addresses are used on testnet and mainnet
    function _getNoblePeerConfig(
        uint16 peerWormholeChainId_
    ) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerWormholeChainId_,
                mToken: NOBLE_M_TOKEN,
                portal: NOBLE_PORTAL,
                wrappedMToken: bytes32(0),
                transceiver: NOBLE_TRANSCEIVER,
                isEvm: false,
                specialRelaying: false,
                wormholeRelaying: false
            });
    }

    /// @dev Returns the configuration for Solana chains. The same addresses are used on testnet and mainnet
    function _getSolanaPeerConfig(
        uint16 peerWormholeChainId_
    ) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerWormholeChainId_,
                mToken: SOLANA_M_TOKEN,
                portal: SOLANA_PORTAL,
                wrappedMToken: SOLANA_WRAPPED_M_TOKEN,
                transceiver: SOLANA_TRANSCEIVER,
                isEvm: false,
                specialRelaying: true,
                wormholeRelaying: false
            });
    }

    /// @dev Returns the configuration for EVM chains. Assumes the same addresses on all chains
    function _getEvmPeerConfig(uint16 peerWormholeChainId_) private pure returns (PeerConfig memory _portalPeerConfig) {
        return
            PeerConfig({
                wormholeChainId: peerWormholeChainId_,
                mToken: M_TOKEN.toBytes32(),
                portal: PORTAL.toBytes32(),
                wrappedMToken: WRAPPED_M_TOKEN.toBytes32(),
                transceiver: TRANSCEIVER.toBytes32(),
                isEvm: true,
                specialRelaying: false,
                wormholeRelaying: true
            });
    }

    /// @dev Returns a list of Wormhole Chain IDs where peer Portals are deployed
    function getPeerChainIds(uint16 wormholeChainId_) internal pure returns (uint16[] memory peerChainIds_) {
        if (wormholeChainId_ == Chains.WORMHOLE_ETHEREUM) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ARBITRUM;
            peerChainIds_[1] = Chains.WORMHOLE_OPTIMISM;
            peerChainIds_[2] = Chains.WORMHOLE_BASE;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_ARBITRUM) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM;
            peerChainIds_[1] = Chains.WORMHOLE_OPTIMISM;
            peerChainIds_[2] = Chains.WORMHOLE_BASE;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_OPTIMISM) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM;
            peerChainIds_[1] = Chains.WORMHOLE_ARBITRUM;
            peerChainIds_[2] = Chains.WORMHOLE_BASE;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_BASE) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM;
            peerChainIds_[1] = Chains.WORMHOLE_ARBITRUM;
            peerChainIds_[2] = Chains.WORMHOLE_OPTIMISM;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_ETHEREUM_SEPOLIA) {
            peerChainIds_ = new uint16[](5);
            peerChainIds_[0] = Chains.WORMHOLE_ARBITRUM_SEPOLIA;
            peerChainIds_[1] = Chains.WORMHOLE_OPTIMISM_SEPOLIA;
            peerChainIds_[2] = Chains.WORMHOLE_NOBLE_TESTNET;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA_TESTNET;
            peerChainIds_[4] = Chains.WORMHOLE_BASE_SEPOLIA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_ARBITRUM_SEPOLIA) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM_SEPOLIA;
            peerChainIds_[1] = Chains.WORMHOLE_OPTIMISM_SEPOLIA;
            peerChainIds_[2] = Chains.WORMHOLE_SOLANA_TESTNET;
            peerChainIds_[3] = Chains.WORMHOLE_BASE_SEPOLIA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_OPTIMISM_SEPOLIA) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM_SEPOLIA;
            peerChainIds_[1] = Chains.WORMHOLE_ARBITRUM_SEPOLIA;
            peerChainIds_[2] = Chains.WORMHOLE_SOLANA_TESTNET;
            peerChainIds_[3] = Chains.WORMHOLE_BASE_SEPOLIA;
        }

        if (wormholeChainId_ == Chains.WORMHOLE_BASE_SEPOLIA) {
            peerChainIds_ = new uint16[](4);
            peerChainIds_[0] = Chains.WORMHOLE_ETHEREUM_SEPOLIA;
            peerChainIds_[1] = Chains.WORMHOLE_ARBITRUM_SEPOLIA;
            peerChainIds_[2] = Chains.WORMHOLE_OPTIMISM_SEPOLIA;
            peerChainIds_[3] = Chains.WORMHOLE_SOLANA_TESTNET;
        }
    }
}
