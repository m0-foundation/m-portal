// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { ERC1967Proxy } from "../../lib/protocol/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ContractHelper } from "../../lib/common/src/libs/ContractHelper.sol";

import { MToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar } from "../../lib/ttg/src/Registrar.sol";
import { WrappedMToken } from "../../lib/wrapped-m-token/src/WrappedMToken.sol";

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";
import { MerkleTreeBuilder } from "../../src/MerkleTreeBuilder.sol";
import { ExecutorEntryPoint } from "../../src/ExecutorEntryPoint.sol";
import { HubExecutorEntryPoint } from "../../src/HubExecutorEntryPoint.sol";

import { ScriptBase } from "../ScriptBase.sol";
import { WormholeTransceiverConfig } from "../config/WormholeConfig.sol";
import { HubDeployConfig, SpokeDeployConfig } from "../config/DeployConfig.sol";

contract DeployBase is ScriptBase {
    /// @dev Contract names used for deterministic deployment
    string internal constant _PORTAL_CONTRACT_NAME = "Portal";
    string internal constant _TRANSCEIVER_CONTRACT_NAME = "WormholeTransceiver";
    string internal constant _VAULT_CONTRACT_NAME = "Vault";
    string internal constant _EXECUTOR_ENTRY_POINT_CONTRACT_NAME = "ExecutorEntryPoint";

    /// @dev Contract names used for deterministic deployment of Noble Portal
    string internal constant _NOBLE_PORTAL_CONTRACT_NAME = "NoblePortal";
    string internal constant _NOBLE_TRANSCEIVER_CONTRACT_NAME = "NobleWormholeTransceiver";

    /* ============ Custom Errors ============ */

    error UnexpectedDeployerNonce(uint64 expected, uint64 actual);
    error DeployerNonceTooHigh(uint64 expected, uint64 actual);
    error ExpectedAddressMismatch(address expected, address actual);

    /* ============ Deploy Functions ============ */

    /**
     * @dev    Deploys Hub Portal and Wormhole Transceiver.
     * @param  deployer_          The address of the deployer.
     * @param  wormholeChainId_   The Wormhole Chain Id where Hub is deployed.
     * @param  swapFacility_      The address of the swap facility.
     * @param  hubConfig_         The configuration to deploy Hub Portal.
     * @param  transceiverConfig_ The configuration to deploy Wormhole Transceiver.
     * @return hubPortal_         The address of the deployed Hub Portal.
     * @return hubTransceiver_    The address of the deployed Hub WormholeTransceiver.
     */
    function _deployHubComponents(
        address deployer_,
        uint16 wormholeChainId_,
        address swapFacility_,
        HubDeployConfig memory hubConfig_,
        WormholeTransceiverConfig memory transceiverConfig_
    ) internal returns (address hubPortal_, address hubTransceiver_) {
        hubPortal_ = _deployHubPortal(deployer_, wormholeChainId_, swapFacility_, hubConfig_, _PORTAL_CONTRACT_NAME);
        hubTransceiver_ = _deployWormholeTransceiver(
            deployer_,
            transceiverConfig_,
            hubPortal_,
            _TRANSCEIVER_CONTRACT_NAME
        );

        _configurePortal(hubPortal_, hubTransceiver_);
    }

    /**
     * @dev    Deploys Hub Portal and Wormhole Transceiver for Noble.
     * @param  deployer_          The address of the deployer.
     * @param  wormholeChainId_   The Wormhole Chain Id where Hub is deployed.
     * @param  swapFacility_      The address of the swap facility.
     * @param  hubConfig_         The configuration to deploy Hub Portal.
     * @param  transceiverConfig_ The configuration to deploy Wormhole Transceiver.
     * @return hubPortal_         The address of the deployed Noble Portal.
     * @return hubTransceiver_    The address of the deployed Noble WormholeTransceiver.
     */
    function _deployNobleHubComponents(
        address deployer_,
        uint16 wormholeChainId_,
        address swapFacility_,
        HubDeployConfig memory hubConfig_,
        WormholeTransceiverConfig memory transceiverConfig_
    ) internal returns (address hubPortal_, address hubTransceiver_) {
        hubPortal_ = _deployHubPortal(
            deployer_,
            wormholeChainId_,
            swapFacility_,
            hubConfig_,
            _NOBLE_PORTAL_CONTRACT_NAME
        );
        hubTransceiver_ = _deployWormholeTransceiver(
            deployer_,
            transceiverConfig_,
            hubPortal_,
            _NOBLE_TRANSCEIVER_CONTRACT_NAME
        );

        _configurePortal(hubPortal_, hubTransceiver_);
    }

    /**
     * @dev    Deploys Spoke M Token, Registrar, Portal and Wormhole Transceiver.
     * @param  deployer_          The address of the deployer.
     * @param  wormholeChainId_   The Wormhole Chain Id where Spoke is deployed.
     * @param  swapFacility_      The address of the swap facility.
     * @param  transceiverConfig_ The configuration to deploy Wormhole Transceiver.
     * @param  migrationAdmin_    The address of the migration admin.
     * @return spokePortal_       The address of the deployed Spoke Portal.
     * @return spokeTransceiver_  The address of the deployed Spoke WormholeTransceiver.
     * @return spokeRegistrar_    The address of the deployed Spoke Registrar.
     * @return spokeMToken_       The address of the deployed Spoke MToken.
     */
    function _deploySpokeComponents(
        address deployer_,
        uint16 wormholeChainId_,
        address swapFacility_,
        WormholeTransceiverConfig memory transceiverConfig_,
        address migrationAdmin_
    )
        internal
        virtual
        returns (address spokePortal_, address spokeTransceiver_, address spokeRegistrar_, address spokeMToken_)
    {
        (spokeRegistrar_, spokeMToken_) = _deploySpokeProtocol(deployer_, migrationAdmin_);

        spokePortal_ = _deploySpokePortal(deployer_, spokeMToken_, spokeRegistrar_, swapFacility_, wormholeChainId_);
        spokeTransceiver_ = _deployWormholeTransceiver(
            deployer_,
            transceiverConfig_,
            spokePortal_,
            _TRANSCEIVER_CONTRACT_NAME
        );

        _configurePortal(spokePortal_, spokeTransceiver_);
    }

    function _deploySpokeProtocol(
        address deployer_,
        address migrationAdmin_
    ) internal returns (address spokeRegistrar_, address spokeMToken_) {
        address mTokenImplementation_ = _deploySpokeMTokenImplementation(
            migrationAdmin_,
            deployer_,
            vm.getNonce(deployer_)
        );
        spokeRegistrar_ = _deploySpokeRegistrar(deployer_, vm.getNonce(deployer_));
        spokeMToken_ = _deploySpokeMToken(vm.getNonce(deployer_), mTokenImplementation_);
    }

    function _deployHubPortal(
        address deployer_,
        uint16 wormholeChainId_,
        address swapFacility_,
        HubDeployConfig memory config_,
        string memory contractName_
    ) internal returns (address hubPortal_) {
        HubPortal implementation_ = new HubPortal(config_.mToken, config_.registrar, swapFacility_, wormholeChainId_);
        HubPortal hubPortalProxy_ = HubPortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, contractName_))
        );

        hubPortalProxy_.initialize();

        return address(hubPortalProxy_);
    }

    function _deploySpokePortal(
        address deployer_,
        address mToken_,
        address registrar_,
        address swapFacility_,
        uint16 wormholeChainId_
    ) internal returns (address pokePortal_) {
        SpokePortal implementation_ = new SpokePortal(mToken_, registrar_, swapFacility_, wormholeChainId_);
        SpokePortal spokePortalProxy_ = SpokePortal(
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, _PORTAL_CONTRACT_NAME))
        );

        spokePortalProxy_.initialize();

        return address(spokePortalProxy_);
    }

    function _deployWormholeTransceiver(
        address deployer_,
        WormholeTransceiverConfig memory config_,
        address nttManager_,
        string memory contractName_
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
            _deployCreate3Proxy(address(implementation_), _computeSalt(deployer_, contractName_))
        );

        transceiverProxy_.initialize();

        return address(transceiverProxy_);
    }

    function _deploySpokeMTokenImplementation(
        address migrationAdmin_,
        address deployer_,
        uint64 currentNonce_
    ) internal returns (address registrar_) {
        if (currentNonce_ > _SPOKE_M_TOKEN_IMPLEMENTATION_NONCE)
            revert DeployerNonceTooHigh(_SPOKE_M_TOKEN_IMPLEMENTATION_NONCE, currentNonce_);

        while (currentNonce_ < _SPOKE_M_TOKEN_IMPLEMENTATION_NONCE) {
            payable(deployer_).transfer(0);
            ++currentNonce_;
        }

        if (currentNonce_ != _SPOKE_M_TOKEN_IMPLEMENTATION_NONCE)
            revert UnexpectedDeployerNonce(_SPOKE_M_TOKEN_IMPLEMENTATION_NONCE, currentNonce_);

        address registrarAddress_ = ContractHelper.getContractFrom(deployer_, _SPOKE_REGISTRAR_NONCE);

        return address(new MToken(registrarAddress_, _computePortalAddress(deployer_), migrationAdmin_));
    }

    function _deploySpokeRegistrar(address deployer_, uint64 currentNonce_) internal returns (address registrar_) {
        if (currentNonce_ != _SPOKE_REGISTRAR_NONCE)
            revert UnexpectedDeployerNonce(_SPOKE_REGISTRAR_NONCE, currentNonce_);
        return address(new Registrar(_computePortalAddress(deployer_)));
    }

    function _deploySpokeMToken(uint64 currentNonce_, address implementation_) internal returns (address mToken_) {
        if (currentNonce_ != _SPOKE_M_TOKEN_NONCE) revert UnexpectedDeployerNonce(_SPOKE_M_TOKEN_NONCE, currentNonce_);
        return address(new ERC1967Proxy(implementation_, abi.encodeCall(MToken.initialize, ())));
    }

    function _deploySpokeVault(
        address deployer_,
        address spokePortal_,
        address hubVault_,
        uint16 hubChainId_,
        address migrationAdmin_
    ) internal returns (address spokeVaultImplementation_, address spokeVaultProxy_) {
        spokeVaultImplementation_ = address(new SpokeVault(spokePortal_, hubVault_, hubChainId_, migrationAdmin_));

        spokeVaultProxy_ = _deployCreate3Proxy(
            address(spokeVaultImplementation_),
            _computeSalt(deployer_, _VAULT_CONTRACT_NAME)
        );
    }

    function _deploySpokeWrappedMToken(
        address deployer_,
        address mToken_,
        address registrar_,
        address vault_,
        address migrationAdmin_
    ) internal returns (address wrappedMTokenImplementation_, address wrappedMTokenProxy_) {
        uint64 currentNonce_ = vm.getNonce(deployer_);

        if (currentNonce_ > _SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE)
            revert DeployerNonceTooHigh(_SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE, currentNonce_);

        while (currentNonce_ < _SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE) {
            payable(deployer_).transfer(0);
            ++currentNonce_;
        }

        if (currentNonce_ != _SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE)
            revert UnexpectedDeployerNonce(_SPOKE_WRAPPED_M_TOKEN_IMPLEMENTATION_NONCE, currentNonce_);

        wrappedMTokenImplementation_ = address(new WrappedMToken(mToken_, registrar_, vault_, migrationAdmin_));

        currentNonce_ = vm.getNonce(deployer_);
        if (currentNonce_ != _SPOKE_WRAPPED_M_TOKEN_NONCE)
            revert DeployerNonceTooHigh(_SPOKE_WRAPPED_M_TOKEN_NONCE, currentNonce_);

        wrappedMTokenProxy_ = address(new ERC1967Proxy(wrappedMTokenImplementation_, ""));

        if (wrappedMTokenProxy_ != _EXPECTED_WRAPPED_M_TOKEN_ADDRESS) {
            revert ExpectedAddressMismatch(_EXPECTED_WRAPPED_M_TOKEN_ADDRESS, wrappedMTokenProxy_);
        }
    }

    function _deployMerkleTreeBuilder(address deployer_, address registrar_) internal returns (address) {
        return address(new MerkleTreeBuilder(registrar_));
    }

    function _deployExecutorEntryPoint(
        address deployer_,
        address admin_,
        WormholeTransceiverConfig memory config_,
        address portal_
    ) internal returns (address implementation_, address proxy_) {
        implementation_ = address(new ExecutorEntryPoint(config_.executor, portal_, config_.coreBridge));

        proxy_ = _deployCreate3TransparentProxy(
            implementation_,
            admin_,
            "",
            _computeSalt(deployer_, _EXECUTOR_ENTRY_POINT_CONTRACT_NAME)
        );
    }

    function _deployHubExecutorEntryPoint(
        address deployer_,
        address admin_,
        WormholeTransceiverConfig memory config_,
        address portal_
    ) internal returns (address implementation_, address proxy_) {
        implementation_ = address(new HubExecutorEntryPoint(config_.executor, portal_, config_.coreBridge));

        proxy_ = _deployCreate3TransparentProxy(
            implementation_,
            admin_,
            "",
            _computeSalt(deployer_, _EXECUTOR_ENTRY_POINT_CONTRACT_NAME)
        );
    }

    function _configurePortal(address portal_, address transceiver_) internal {
        IManagerBase(portal_).setTransceiver(transceiver_);
        INttManager(portal_).setThreshold(1);
    }

    function _computePortalAddress(address deployer_) internal view returns (address portal_) {
        return _getCreate3Address(deployer_, _computeSalt(deployer_, _PORTAL_CONTRACT_NAME));
    }
}
