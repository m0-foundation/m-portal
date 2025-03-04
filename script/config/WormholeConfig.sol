// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Chains } from "./Chains.sol";

struct WormholeTransceiverConfig {
    uint16 wormholeChainId;
    uint8 consistencyLevel;
    address coreBridge;
    uint256 gasLimit;
    address relayer;
    address specialRelayer;
}

/// @dev Wormhole addresses and configuration
library WormholeConfig {
    /// @dev https://wormhole.com/docs/build/reference/consistency-levels/
    uint8 internal constant INSTANT_CONSISTENCY_LEVEL = 200;
    uint8 internal constant FINALIZED_CONSISTENCY_LEVEL = 1;

    /// @dev Gas limit to process a message on the destination
    uint256 internal constant GAS_LIMIT = 300_000;
    address internal constant ZERO_ADDRESS = address(0);

    /// @dev Wormhole Chain Ids https://wormhole.com/docs/build/reference/chain-ids/
    function toWormholeChainId(uint256 chainId_) internal pure returns (uint16 wormholeChainId_) {
        if (chainId_ == Chains.ETHEREUM) return Chains.WORMHOLE_ETHEREUM;
        if (chainId_ == Chains.ARBITRUM) return Chains.WORMHOLE_ARBITRUM;
        if (chainId_ == Chains.OPTIMISM) return Chains.WORMHOLE_OPTIMISM;
        if (chainId_ == Chains.NOBLE) return Chains.WORMHOLE_NOBLE;

        if (chainId_ == Chains.ETHEREUM_SEPOLIA) return Chains.WORMHOLE_ETHEREUM_SEPOLIA;
        if (chainId_ == Chains.ARBITRUM_SEPOLIA) return Chains.WORMHOLE_ARBITRUM_SEPOLIA;
        if (chainId_ == Chains.OPTIMISM_SEPOLIA) return Chains.WORMHOLE_OPTIMISM_SEPOLIA;
        if (chainId_ == Chains.NOBLE_TESTNET) return Chains.WORMHOLE_NOBLE_TESTNET;

        revert Chains.UnsupportedChain(chainId_);
    }

    /// @dev Wormhole Core Bridge https://wormhole.com/docs/build/reference/contract-addresses/#core-contracts
    ///      Wormhole Relayer https://wormhole.com/docs/build/reference/contract-addresses/#wormhole-relayer
    function getWormholeTransceiverConfig(
        uint256 chainId_
    ) internal pure returns (WormholeTransceiverConfig memory config_) {
        // Ethereum Mainnet
        if (chainId_ == Chains.ETHEREUM)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: FINALIZED_CONSISTENCY_LEVEL,
                    coreBridge: 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayer: ZERO_ADDRESS
                });

        // Arbitrum
        if (chainId_ == Chains.ARBITRUM)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: FINALIZED_CONSISTENCY_LEVEL,
                    coreBridge: 0xa5f208e072434bC67592E4C49C1B991BA79BCA46,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayer: ZERO_ADDRESS
                });

        // Optimism
        if (chainId_ == Chains.OPTIMISM)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: FINALIZED_CONSISTENCY_LEVEL,
                    coreBridge: 0xEe91C335eab126dF5fDB3797EA9d6aD93aeC9722,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911,
                    specialRelayer: ZERO_ADDRESS
                });

        // Ethereum Sepolia
        if (chainId_ == Chains.ETHEREUM_SEPOLIA)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: INSTANT_CONSISTENCY_LEVEL,
                    coreBridge: 0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
                    specialRelayer: ZERO_ADDRESS
                });

        // Arbitrum Sepolia
        if (chainId_ == Chains.ARBITRUM_SEPOLIA)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: INSTANT_CONSISTENCY_LEVEL,
                    coreBridge: 0x6b9C8671cdDC8dEab9c719bB87cBd3e782bA6a35,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470,
                    specialRelayer: ZERO_ADDRESS
                });

        // Optimism Sepolia
        if (chainId_ == Chains.OPTIMISM_SEPOLIA)
            return
                WormholeTransceiverConfig({
                    wormholeChainId: toWormholeChainId(chainId_),
                    consistencyLevel: INSTANT_CONSISTENCY_LEVEL,
                    coreBridge: 0x31377888146f3253211EFEf5c676D41ECe7D58Fe,
                    gasLimit: GAS_LIMIT,
                    relayer: 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE,
                    specialRelayer: ZERO_ADDRESS
                });

        revert Chains.UnsupportedChain(chainId_);
    }
}
