// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

/// @notice EVM and Wormhole chain Ids
/// @dev    https://wormhole.com/docs/build/reference/chain-ids/
library Chains {
    error UnsupportedChain(uint256 chainId);

    /*****************************************************************/
    /*                       EVM CHAIN IDs                           */
    /*****************************************************************/

    // Mainnet
    uint256 internal constant ETHEREUM = 1;
    uint256 internal constant OPTIMISM = 10;
    uint256 internal constant ARBITRUM = 42161;

    // Testnet
    uint256 internal constant ETHEREUM_SEPOLIA = 11155111;
    uint256 internal constant OPTIMISM_SEPOLIA = 11155420;
    uint256 internal constant ARBITRUM_SEPOLIA = 421614;

    /*****************************************************************/
    /*                      NOBLE CHAIN IDs                          */
    /*****************************************************************/

    // Mainnet (noble-1)
    uint256 internal constant NOBLE = 110111981081014549;

    // Testnet (grand-1)
    uint256 internal constant NOBLE_TESTNET = 103114971101004549;

    /*****************************************************************/
    /*                     WORMHOLE CHAIN IDs                        */
    /*****************************************************************/

    // Mainnet
    uint16 internal constant WORMHOLE_ETHEREUM = 2;
    uint16 internal constant WORMHOLE_OPTIMISM = 24;
    uint16 internal constant WORMHOLE_ARBITRUM = 23;
    uint16 internal constant WORMHOLE_NOBLE = 4009;

    // Testnet
    uint16 internal constant WORMHOLE_ETHEREUM_SEPOLIA = 10002;
    uint16 internal constant WORMHOLE_OPTIMISM_SEPOLIA = 10005;
    uint16 internal constant WORMHOLE_ARBITRUM_SEPOLIA = 10003;
    uint16 internal constant WORMHOLE_NOBLE_TESTNET = 4009;

    function isHub(uint256 chainId_) internal pure returns (bool) {
        return chainId_ == ETHEREUM || chainId_ == ETHEREUM_SEPOLIA;
    }
}
