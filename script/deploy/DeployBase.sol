// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

import { ContractHelper } from "../../lib/common/src/libs/ContractHelper.sol";
import { Proxy } from "../../lib/common/src/Proxy.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";
import { WrappedMToken as SpokeWrappedMToken } from "../../lib/wrapped-m-token/src/WrappedMToken.sol";

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";

import { Utils } from "../helpers/Utils.sol";

contract DeployBase is Script, Utils {
    using stdJson for string;

    /* ============ Config Structs ============ */

    struct WormholeConfiguration {
        uint16 chainId;
        uint8 consistencyLevel;
        address coreBridge;
        uint256 gasLimit;
        address relayer;
        address specialRelayer;
    }

    struct HubConfiguration {
        address mToken;
        address registrar;
        WormholeConfiguration wormhole;
    }

    struct SpokeConfiguration {
        address hubVault;
        uint16 hubWormholeChainId;
        WormholeConfiguration wormhole;
    }

    /* ============ Custom Errors ============ */

    error DeployerNonceTooHigh(uint64 expected, uint64 actual);
    error ExpectedAddressMismatch(address expected, address actual);

    /* ============ Deploy Functions ============ */

    /**
     * @dev    Deploys Hub components.
     * @param  deployer_       The address of the deployer.
     * @param  config_         The Hub configuration.
     * @return hubPortal_      The address of the deployed Hub Portal.
     * @return hubTransceiver_ The address of the deployed Hub WormholeTransceiver.
     */
    function _deployHubComponents(
        address deployer_,
        HubConfiguration memory config_
    ) internal returns (address hubPortal_, address hubTransceiver_) {
        hubPortal_ = _deployHubPortal(deployer_, config_);
        hubTransceiver_ = _deployWormholeTransceiver(deployer_, config_.wormhole, hubPortal_);

        _configurePortal(hubPortal_, hubTransceiver_);
    }

    /**
     * @dev    Deploys Spoke components.
     * @param  deployer_         The address of the deployer.
     * @param  config_           The Spoke configuration.
     * @param  burnNonces_       The function to burn nonces.
     * @return spokePortal_      The address of the deployed Spoke Portal.
     * @return spokeTransceiver_ The address of the deployed Spoke WormholeTransceiver.
     * @return spokeRegistrar_   The address of the deployed Spoke Registrar.
     * @return spokeMToken_      The address of the deployed Spoke MToken.
     */
    function _deploySpokeComponents(
        address deployer_,
        SpokeConfiguration memory config_,
        function(address, uint64, uint64) internal burnNonces_
    )
        internal
        virtual
        returns (address spokePortal_, address spokeTransceiver_, address spokeRegistrar_, address spokeMToken_)
    {
        (spokeRegistrar_, spokeMToken_) = _deploySpokeProtocol(deployer_, burnNonces_);

        spokePortal_ = _deploySpokePortal(deployer_, spokeMToken_, spokeRegistrar_, config_.wormhole.chainId);
        spokeTransceiver_ = _deployWormholeTransceiver(deployer_, config_.wormhole, spokePortal_);

        _configurePortal(spokePortal_, spokeTransceiver_);
    }

    function _deploySpokeProtocol(
        address deployer_,
        function(address, uint64, uint64) internal burnNonces_
    ) internal returns (address spokeRegistrar_, address spokeMToken_) {
        uint64 deployerNonce_ = vm.getNonce(deployer_);

        if (deployerNonce_ > _SPOKE_REGISTRAR_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_REGISTRAR_NONCE, deployerNonce_);
        }

        burnNonces_(deployer_, deployerNonce_, _SPOKE_REGISTRAR_NONCE);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_REGISTRAR_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_REGISTRAR_NONCE, deployerNonce_);
        }

        // Pre-compute the expected SpokePortal proxy address.
        spokeRegistrar_ = _deploySpokeRegistrar(_getCreate3Address(deployer_, _computeSalt(deployer_, "Portal")));

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_M_TOKEN_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_M_TOKEN_NONCE, deployerNonce_);
        }

        spokeMToken_ = _deploySpokeMToken(spokeRegistrar_);
    }

    function _deployHubPortal(address deployer_, HubConfiguration memory config_) internal returns (address) {
        HubPortal implementation_ = new HubPortal(config_.mToken, config_.registrar, config_.wormhole.chainId);
        HubPortal hubPortalProxy_ = HubPortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, "Portal"))
        );

        hubPortalProxy_.initialize();

        console.log("HubPortal:", address(hubPortalProxy_));

        return address(hubPortalProxy_);
    }

    function _deploySpokePortal(
        address deployer_,
        address mToken_,
        address registrar_,
        uint16 wormholeChainId_
    ) internal returns (address) {
        SpokePortal implementation_ = new SpokePortal(mToken_, registrar_, wormholeChainId_);
        SpokePortal spokePortalProxy_ = SpokePortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, "Portal"))
        );

        spokePortalProxy_.initialize();

        console.log("SpokePortal:", address(spokePortalProxy_));

        return address(spokePortalProxy_);
    }

    function _deployWormholeTransceiver(
        address deployer_,
        WormholeConfiguration memory config_,
        address nttManager_
    ) internal returns (address) {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            nttManager_,
            config_.coreBridge,
            config_.relayer,
            config_.specialRelayer,
            config_.consistencyLevel,
            config_.gasLimit
        );

        WormholeTransceiver transceiverProxy_ = WormholeTransceiver(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, "WormholeTransceiver"))
        );

        transceiverProxy_.initialize();

        console.log("WormholeTransceiver:", address(transceiverProxy_));

        return address(transceiverProxy_);
    }

    function _deploySpokeRegistrar(address spokeNTTManager_) internal returns (address) {
        SpokeRegistrar spokeRegistrar_ = new SpokeRegistrar(spokeNTTManager_);

        console.log("SpokeRegistrar:", address(spokeRegistrar_));

        return address(spokeRegistrar_);
    }

    function _deploySpokeMToken(address spokeRegistrar_) internal returns (address) {
        SpokeMToken spokeMToken_ = new SpokeMToken(spokeRegistrar_);

        console.log("SpokeMToken:", address(spokeMToken_));

        return address(spokeMToken_);
    }

    function _deploySpokeVault(
        address deployer_,
        address spokePortal_,
        address hubVault_,
        uint16 destinationChainId_,
        address migrationAdmin_
    ) internal returns (address spokeVaultImplementation_, address spokeVaultProxy_) {
        spokeVaultImplementation_ = address(
            new SpokeVault(spokePortal_, hubVault_, destinationChainId_, migrationAdmin_)
        );

        spokeVaultProxy_ = _deployCreate3Proxy(address(spokeVaultImplementation_), _computeSalt(deployer_, "Vault"));

        console.log("SpokeVault:", spokeVaultProxy_);
    }

    function _deploySpokeWrappedMToken(
        address deployer_,
        address spokeMToken_,
        address registrar_,
        address spokeVault_,
        address migrationAdmin_,
        function(address, uint64, uint64) internal burnNonces_
    ) internal returns (address spokeWrappedMTokenImplementation_, address spokeWrappedMTokenProxy_) {
        uint64 deployerNonce_ = vm.getNonce(deployer_);

        if (deployerNonce_ > _SPOKE_WRAPPED_M_TOKEN_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_WRAPPED_M_TOKEN_NONCE, deployerNonce_);
        }

        burnNonces_(deployer_, deployerNonce_, _SPOKE_WRAPPED_M_TOKEN_NONCE);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_WRAPPED_M_TOKEN_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_WRAPPED_M_TOKEN_NONCE, deployerNonce_);
        }

        // Pre-compute the expected SpokeWrappedMToken implementation address.
        address expectedWrappedMTokenImplementation_ = ContractHelper.getContractFrom(
            deployer_,
            _SPOKE_WRAPPED_M_TOKEN_NONCE
        );

        spokeWrappedMTokenImplementation_ = address(
            new SpokeWrappedMToken(spokeMToken_, registrar_, spokeVault_, migrationAdmin_)
        );

        if (expectedWrappedMTokenImplementation_ != spokeWrappedMTokenImplementation_) {
            revert ExpectedAddressMismatch(expectedWrappedMTokenImplementation_, spokeWrappedMTokenImplementation_);
        }

        console.log("SpokeWrappedMTokenImplementation:", spokeWrappedMTokenImplementation_);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_WRAPPED_M_TOKEN_PROXY_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_WRAPPED_M_TOKEN_PROXY_NONCE, deployerNonce_);
        }

        // Pre-compute the expected SpokeWrappedMToken proxy address.
        address expectedWrappedMTokenProxy_ = ContractHelper.getContractFrom(
            deployer_,
            _SPOKE_WRAPPED_M_TOKEN_PROXY_NONCE
        );

        spokeWrappedMTokenProxy_ = address(new Proxy(spokeWrappedMTokenImplementation_));

        if (expectedWrappedMTokenProxy_ != spokeWrappedMTokenProxy_) {
            revert ExpectedAddressMismatch(expectedWrappedMTokenProxy_, spokeWrappedMTokenProxy_);
        }

        console.log("SpokeWrappedMTokenProxy:", spokeWrappedMTokenProxy_);
    }

    function _configurePortal(address portal_, address transceiver_) internal {
        IManagerBase(portal_).setTransceiver(transceiver_);
        console.log("Transceiver address set: ", transceiver_);

        INttManager(portal_).setThreshold(1);
        console.log("Threshold set: ", uint256(1));
    }

    /* ============ JSON Config loading functions ============ */

    function _loadHubConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (HubConfiguration memory hubConfig_) {
        string memory file_ = vm.readFile(filepath_);
        bytes memory data = vm.parseJson(file_, string.concat(".hub.", vm.toString(chainId_)));
        hubConfig_ = abi.decode(data, (HubConfiguration));

        console.log("Hub configuration for Chain ID %s loaded:", chainId_);
        console.log("M Token:", hubConfig_.mToken);
        console.log("Registrar:", hubConfig_.registrar);
        _logWormholeConfig(hubConfig_.wormhole);
    }

    function _loadSpokeConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (SpokeConfiguration memory spokeConfig_) {
        string memory file_ = vm.readFile(filepath_);
        bytes memory data = vm.parseJson(file_, string.concat(".spoke.", vm.toString(chainId_)));
        string memory spoke_ = string.concat("$.spoke.", vm.toString(chainId_), ".");
        string memory hubVault_ = string.concat(spoke_, "hub_vault.");
        spokeConfig_ = abi.decode(data, (SpokeConfiguration));

        console.log("Spoke configuration for Chain ID %s loaded:", chainId_);
        console.log("Hub Vault:", spokeConfig_.hubVault);
        console.log("Hub Wormhole Chain ID:", spokeConfig_.hubWormholeChainId);
        _logWormholeConfig(spokeConfig_.wormhole);
    }

    function _logWormholeConfig(WormholeConfiguration memory wormholeConfig_) internal pure {
        console.log("Wormhole Chain ID:", wormholeConfig_.chainId);
        console.log("Wormhole Core Bridge:", wormholeConfig_.coreBridge);
        console.log("Wormhole Relayer:", wormholeConfig_.relayer);
        console.log("Wormhole Special Relayer:", wormholeConfig_.specialRelayer);
        console.log("Wormhole Consistency Level:", wormholeConfig_.consistencyLevel);
        console.log("Wormhole Gas Limit:", wormholeConfig_.gasLimit);
    }

    function _deployOutputPath() internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");
    }
}
