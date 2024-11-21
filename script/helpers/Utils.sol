// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import {
    ERC1967Proxy
} from "../../lib/example-native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ICreateXLike } from "../deploy/interfaces/ICreateXLike.sol";

contract Utils {
    uint64 internal constant _SPOKE_REGISTRAR_NONCE = 7;
    uint64 internal constant _SPOKE_M_TOKEN_NONCE = 8;
    uint64 internal constant _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE = 37;
    uint64 internal constant _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_PROXY_NONCE = 38;
    uint64 internal constant _SPOKE_SMART_M_TOKEN_NONCE = 39;
    uint64 internal constant _SPOKE_SMART_M_TOKEN_PROXY_NONCE = 40;

    address internal constant _MAINNET_REGISTRAR = 0x119FbeeDD4F4f4298Fb59B720d5654442b81ae2c;
    address internal constant _MAINNET_M_TOKEN = 0x866A2BF4E572CbcF37D5071A7a58503Bfb36be1b;
    address internal constant _MAINNET_VAULT = 0xd7298f620B0F752Cf41BD818a16C756d9dCAA34f;

    address internal constant _SEPOLIA_REGISTRAR = 0x975Bf5f212367D09CB7f69D3dc4BA8C9B440aD3A;
    address internal constant _SEPOLIA_M_TOKEN = 0x0c941AD94Ca4A52EDAeAbF203b61bdd1807CeEC0;
    address internal constant _SEPOLIA_VAULT = 0x3dc71Be52d6D687e21FC0d4FFc196F32cacbc26d;

    uint8 internal constant _M_TOKEN_DECIMALS = 6;

    uint256 internal constant _MAINNET_CHAIN_ID = 1;
    uint256 internal constant _BASE_CHAIN_ID = 8453;
    uint256 internal constant _OPTIMISM_CHAIN_ID = 10;

    uint256 internal constant _SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant _BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 internal constant _OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

    uint16 internal constant _MAINNET_WORMHOLE_CHAIN_ID = 2;
    uint16 internal constant _BASE_WORMHOLE_CHAIN_ID = 30;
    uint16 internal constant _OPTIMISM_WORMHOLE_CHAIN_ID = 24;

    uint16 internal constant _SEPOLIA_WORMHOLE_CHAIN_ID = 10002;
    uint16 internal constant _BASE_SEPOLIA_WORMHOLE_CHAIN_ID = 10004;
    uint16 internal constant _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID = 10005;

    address internal constant _MAINNET_WORMHOLE_CORE_BRIDGE = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;
    address internal constant _BASE_WORMHOLE_CORE_BRIDGE = 0xbebdb6C8ddC678FfA9f8748f85C815C556Dd8ac6;
    address internal constant _OPTIMISM_WORMHOLE_CORE_BRIDGE = 0xEe91C335eab126dF5fDB3797EA9d6aD93aeC9722;

    address internal constant _SEPOLIA_WORMHOLE_CORE_BRIDGE = 0x4a8bc80Ed5a4067f1CCf107057b8270E0cC11A78;
    address internal constant _BASE_SEPOLIA_WORMHOLE_CORE_BRIDGE = 0x79A1027a6A159502049F10906D333EC57E95F083;
    address internal constant _OPTIMISM_SEPOLIA_WORMHOLE_CORE_BRIDGE = 0x31377888146f3253211EFEf5c676D41ECe7D58Fe;

    address internal constant _MAINNET_WORMHOLE_RELAYER = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;
    address internal constant _BASE_WORMHOLE_RELAYER = 0x706F82e9bb5b0813501714Ab5974216704980e31;
    address internal constant _OPTIMISM_WORMHOLE_RELAYER = 0x27428DD2d3DD32A4D7f7C497eAaa23130d894911;

    address internal constant _SEPOLIA_WORMHOLE_RELAYER = 0x7B1bD7a6b4E61c2a123AC6BC2cbfC614437D0470;
    address internal constant _BASE_SEPOLIA_WORMHOLE_RELAYER = 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE;
    address internal constant _OPTIMISM_SEPOLIA_WORMHOLE_RELAYER = 0x93BAD53DDfB6132b0aC8E37f6029163E63372cEE;

    uint256 internal constant _MIN_WORMHOLE_GAS_LIMIT = 150_000;
    uint256 internal constant _WORMHOLE_GAS_LIMIT = 250_000;

    // Instant confirmation. Guardians signs the VAA once the transaction has been included in a block.
    uint8 internal constant _INSTANT_CONSISTENCY_LEVEL = 200;
    uint8 internal constant _FINALIZED_CONSISTENCY_LEVEL = 15;

    // Same address across all supported mainnet and testnets networks.
    address internal constant _CREATE_X_FACTORY = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function _computeSalt(address deployer_, string memory contractName_) internal pure returns (bytes32) {
        return
            bytes32(
                abi.encodePacked(
                    bytes20(deployer_), // used to implement permissioned deploy protection
                    bytes1(0), // disable cross-chain redeploy protection
                    bytes11(keccak256(bytes(contractName_)))
                )
            );
    }

    function _computeGuardedSalt(address deployer_, bytes32 salt_) internal pure returns (bytes32) {
        return _efficientHash({ a: bytes32(uint256(uint160(deployer_))), b: salt_ });
    }

    /**
     * @dev Returns the `keccak256` hash of `a` and `b` after concatenation.
     * @param a The first 32-byte value to be concatenated and hashed.
     * @param b The second 32-byte value to be concatenated and hashed.
     * @return hash The 32-byte `keccak256` hash of `a` and `b`.
     */
    function _efficientHash(bytes32 a, bytes32 b) internal pure returns (bytes32 hash) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            hash := keccak256(0x00, 0x40)
        }
    }

    function _deployCreate3Proxy(address implementation_, bytes32 salt_) internal returns (address) {
        return
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                salt_,
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(implementation_), ""))
            );
    }

    function _getCreate3Address(address deployer_, bytes32 salt_) internal view virtual returns (address) {
        return ICreateXLike(_CREATE_X_FACTORY).computeCreate3Address(_computeGuardedSalt(deployer_, salt_));
    }

    function _toUniversalAddress(address evmAddr_) internal pure returns (bytes32 converted_) {
        assembly ("memory-safe") {
            converted_ := and(0xffffffffffffffffffffffffffffffffffffffff, evmAddr_)
        }
    }

    function _getWormholeChainId(uint256 chainId_) internal pure returns (uint16) {
        if (chainId_ == _MAINNET_CHAIN_ID) {
            return _MAINNET_WORMHOLE_CHAIN_ID;
        } else if (chainId_ == _BASE_CHAIN_ID) {
            return _BASE_WORMHOLE_CHAIN_ID;
        } else if (chainId_ == _OPTIMISM_CHAIN_ID) {
            return _OPTIMISM_WORMHOLE_CHAIN_ID;
        } else if (chainId_ == _SEPOLIA_CHAIN_ID) {
            return _SEPOLIA_WORMHOLE_CHAIN_ID;
        } else if (chainId_ == _BASE_SEPOLIA_CHAIN_ID) {
            return _BASE_SEPOLIA_WORMHOLE_CHAIN_ID;
        } else if (chainId_ == _OPTIMISM_SEPOLIA_CHAIN_ID) {
            return _OPTIMISM_SEPOLIA_WORMHOLE_CHAIN_ID;
        } else {
            console.log("Chain id: {}", chainId_);
            revert("Unsupported chain id.");
        }
    }

    function _readKey(string memory parentNode_, string memory key_) internal pure returns (string memory) {
        return string.concat(parentNode_, key_);
    }
}
