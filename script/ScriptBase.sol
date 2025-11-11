// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../lib/forge-std/src/console.sol";
import { Script } from "../lib/forge-std/src/Script.sol";

import {
    ERC1967Proxy
} from "../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {
    TransparentUpgradeableProxy
} from "../lib/native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import { ICreateXLike } from "./deploy/interfaces/ICreateXLike.sol";

contract ScriptBase is Script {
    struct Deployment {
        address executorEntryPoint;
        address mToken;
        address portal;
        address registrar;
        address swapFacility;
        address transceiver;
        address vault;
        address wrappedMToken;
    }

    uint64 internal constant _SPOKE_M_TOKEN_IMPLEMENTATION_NONCE = 6;
    uint64 internal constant _SPOKE_REGISTRAR_NONCE = 7;
    uint64 internal constant _SPOKE_M_TOKEN_NONCE = 8;
    uint64 internal constant _SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE = 39;
    uint64 internal constant _SPOKE_WRAPPED_M_TOKEN_NONCE = 40;

    address internal constant _EXPECTED_WRAPPED_M_TOKEN_ADDRESS = 0x437cc33344a0B27A429f795ff6B469C72698B291;

    uint8 internal constant _M_TOKEN_DECIMALS = 6;

    // Same address for all EVM chains
    address internal constant _SWAP_FACILITY = 0xB6807116b3B1B321a390594e31ECD6e0076f6278;

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

    function _deployCreate3TransparentProxy(
        address implementation,
        address initialOwner,
        bytes memory initializerData,
        bytes32 salt
    ) internal returns (address) {
        return
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                salt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(implementation, initialOwner, initializerData)
                )
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

    function _readKey(string memory parentNode_, string memory key_) internal pure returns (string memory) {
        return string.concat(parentNode_, key_);
    }

    function _deployOutputPath(uint256 chainId_) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", vm.toString(chainId_), ".json");
    }

    function _readDeployment(
        uint256 chainId_
    )
        internal
        returns (
            address mToken_,
            address portal_,
            address registrar_,
            address transceiver_,
            address vault_,
            address wrappedMToken_
        )
    {
        if (!vm.isFile(_deployOutputPath(chainId_))) {
            revert("Deployment artifacts not found");
        }

        bytes memory data = vm.parseJson(vm.readFile(_deployOutputPath(chainId_)));
        Deployment memory deployment_ = abi.decode(data, (Deployment));
        return (
            deployment_.mToken,
            deployment_.portal,
            deployment_.registrar,
            deployment_.transceiver,
            deployment_.vault,
            deployment_.wrappedMToken
        );
    }
}
