// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script } from "../../lib/forge-std/src/Script.sol";

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

import { ScriptBase } from "../ScriptBase.sol";
import { WormholeTransceiverConfig } from "../config/WormholeConfig.sol";
import { HubDeployConfig, SpokeDeployConfig } from "../config/DeployConfig.sol";

contract DeployBase is ScriptBase {
    /* ============ Custom Errors ============ */

    error DeployerNonceTooHigh(uint64 expected, uint64 actual);
    error ExpectedAddressMismatch(address expected, address actual);

    /* ============ Deploy Functions ============ */

    /**
     * @dev    Deploys Hub Portal and Wormhole Transceiver.
     * @param  deployer_          The address of the deployer.
     * @param  wormholeChainId_   The Wormhole Chain Id where Hub is deployed.
     * @param  hubConfig_         The configuration to deploy Hub Portal.
     * @param  transceiverConfig_ The configuration to deploy Wormhole Transceiver.
     * @return hubPortal_         The address of the deployed Hub Portal.
     * @return hubTransceiver_    The address of the deployed Hub WormholeTransceiver.
     */
    function _deployHubComponents(
        address deployer_,
        uint16 wormholeChainId_,
        HubDeployConfig memory hubConfig_,
        WormholeTransceiverConfig memory transceiverConfig_
    ) internal returns (address hubPortal_, address hubTransceiver_) {
        hubPortal_ = _deployHubPortal(deployer_, wormholeChainId_, hubConfig_);
        hubTransceiver_ = _deployWormholeTransceiver(deployer_, transceiverConfig_, hubPortal_);

        _configurePortal(hubPortal_, hubTransceiver_);
    }

    /**
     * @dev    Deploys Spoke M Token, Registrar, Portal and Wormhole Transceiver.
     * @param  deployer_          The address of the deployer.
     * @param  wormholeChainId_   The Wormhole Chain Id where Spoke is deployed.
     * @param  transceiverConfig_ The configuration to deploy Wormhole Transceiver.
     * @param  burnNonces_        The function to burn nonces.
     * @return spokePortal_       The address of the deployed Spoke Portal.
     * @return spokeTransceiver_  The address of the deployed Spoke WormholeTransceiver.
     * @return spokeRegistrar_    The address of the deployed Spoke Registrar.
     * @return spokeMToken_       The address of the deployed Spoke MToken.
     */
    function _deploySpokeComponents(
        address deployer_,
        uint16 wormholeChainId_,
        WormholeTransceiverConfig memory transceiverConfig_,
        function(address, uint64, uint64) internal burnNonces_
    )
        internal
        virtual
        returns (address spokePortal_, address spokeTransceiver_, address spokeRegistrar_, address spokeMToken_)
    {
        (spokeRegistrar_, spokeMToken_) = _deploySpokeProtocol(deployer_, burnNonces_);

        spokePortal_ = _deploySpokePortal(deployer_, spokeMToken_, spokeRegistrar_, wormholeChainId_);
        spokeTransceiver_ = _deployWormholeTransceiver(deployer_, transceiverConfig_, spokePortal_);

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

    function _deployHubPortal(
        address deployer_,
        uint16 wormholeChainId_,
        HubDeployConfig memory config_
    ) internal returns (address hubPortal_) {
        HubPortal implementation_ = new HubPortal(config_.mToken, config_.registrar, wormholeChainId_);
        HubPortal hubPortalProxy_ = HubPortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, "Portal"))
        );

        hubPortalProxy_.initialize();

        return address(hubPortalProxy_);
    }

    function _deploySpokePortal(
        address deployer_,
        address mToken_,
        address registrar_,
        uint16 wormholeChainId_
    ) internal returns (address pokePortal_) {
        SpokePortal implementation_ = new SpokePortal(mToken_, registrar_, wormholeChainId_);
        SpokePortal spokePortalProxy_ = SpokePortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, "Portal"))
        );

        spokePortalProxy_.initialize();

        return address(spokePortalProxy_);
    }

    function _deployWormholeTransceiver(
        address deployer_,
        WormholeTransceiverConfig memory config_,
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

        return address(transceiverProxy_);
    }

    function _deploySpokeRegistrar(address spokePortal_) internal returns (address) {
        return address(new SpokeRegistrar(spokePortal_));
    }

    function _deploySpokeMToken(address spokeRegistrar_) internal returns (address) {
        return address(new SpokeMToken(spokeRegistrar_));
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
    }

    function _configurePortal(address portal_, address transceiver_) internal {
        IManagerBase(portal_).setTransceiver(transceiver_);
        INttManager(portal_).setThreshold(1);
    }
}
