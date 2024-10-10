// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../../lib/forge-std/src/Script.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";

import {
    ERC1967Proxy
} from "../../lib/example-native-token-transfers/evm/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";

import { Utils } from "../helpers/Utils.sol";

import { ICreateXLike } from "./interfaces/ICreateXLike.sol";

contract DeployBase is Script, Utils {
    error DeployerNonceTooHigh(uint64 expected, uint64 actual);

    error ExpectedAddressMismatch(address expected, address actual);

    struct DeploymentParams {
        address mToken;
        address registrar;
        uint16 wormholeChainId;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    /**
     * @dev    Deploys Hub components.
     * @param  deployer_            The address of the deployer.
     * @param  registrar_           The address of the Registrar.
     * @param  mToken_              The address of the M Token contract.
     * @param  wormholeChainId_     The Wormhole chain ID on which the contracts will be deployed.
     * @param  wormholeCoreBridge_  The address of the Wormhole Core Bridge.
     * @param  wormholeRelayerAddr_ The address of the Wormhole Standard Relayer.
     * @param  specialRelayerAddr_  The address of the Specialized Relayer.
     * @return hubPortal_           The address of the deployed Hub Portal.
     * @return hubTransceiver_      The address of the deployed Hub WormholeTransceiver.
     */
    function _deployHubComponents(
        address deployer_,
        address registrar_,
        address mToken_,
        uint16 wormholeChainId_,
        address wormholeCoreBridge_,
        address wormholeRelayerAddr_,
        address specialRelayerAddr_
    ) internal returns (address hubPortal_, address hubTransceiver_) {
        DeploymentParams memory params_ = DeploymentParams({
            mToken: mToken_,
            registrar: registrar_,
            wormholeChainId: wormholeChainId_,
            wormholeCoreBridge: wormholeCoreBridge_,
            wormholeRelayerAddr: wormholeRelayerAddr_,
            specialRelayerAddr: specialRelayerAddr_,
            consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
            gasLimit: _WORMHOLE_GAS_LIMIT
        });

        hubPortal_ = _deployHubPortal(params_, _computeSalt(deployer_, "Portal"));
        hubTransceiver_ = _deployWormholeTransceiver(
            params_,
            hubPortal_,
            _computeSalt(deployer_, "WormholeTransceiver")
        );

        _configurePortal(hubPortal_, hubTransceiver_);
    }

    /**
     * @dev    Deploys Spoke components.
     * @param  deployer_            The address of the deployer.
     * @param  wormholeChainId_     The Wormhole chain ID on which the contracts will be deployed.
     * @param  wormholeCoreBridge_  The address of the Wormhole Core Bridge.
     * @param  wormholeRelayerAddr_ The address of the Wormhole Standard Relayer.
     * @param  specialRelayerAddr_  The address of the Specialized Relayer.
     * @param  burnNonces_          The function to burn nonces.
     * @return spokePortal_         The address of the deployed Spoke Portal.
     * @return spokeTransceiver_    The address of the deployed Spoke WormholeTransceiver.
     * @return spokeRegistrar_      The address of the deployed Spoke Registrar.
     * @return spokeMToken_         The address of the deployed Spoke MToken.
     */
    function _deploySpokeComponents(
        address deployer_,
        uint16 wormholeChainId_,
        address wormholeCoreBridge_,
        address wormholeRelayerAddr_,
        address specialRelayerAddr_,
        function(address, uint64, uint64) internal burnNonces_
    )
        internal
        virtual
        returns (address spokePortal_, address spokeTransceiver_, address spokeRegistrar_, address spokeMToken_)
    {
        (spokeRegistrar_, spokeMToken_) = _deploySpokeProtocol(deployer_, burnNonces_);

        DeploymentParams memory params_ = DeploymentParams({
            mToken: spokeMToken_,
            registrar: spokeRegistrar_,
            wormholeChainId: wormholeChainId_,
            wormholeCoreBridge: wormholeCoreBridge_,
            wormholeRelayerAddr: wormholeRelayerAddr_,
            specialRelayerAddr: specialRelayerAddr_,
            consistencyLevel: _INSTANT_CONSISTENCY_LEVEL,
            gasLimit: _WORMHOLE_GAS_LIMIT
        });

        spokePortal_ = _deploySpokePortal(params_, _computeSalt(deployer_, "Portal"));
        spokeTransceiver_ = _deployWormholeTransceiver(
            params_,
            spokePortal_,
            _computeSalt(deployer_, "WormholeTransceiver")
        );

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

    function _deployHubPortal(DeploymentParams memory params_, bytes32 salt_) internal returns (address) {
        HubPortal implementation_ = new HubPortal(params_.mToken, params_.registrar, params_.wormholeChainId);

        HubPortal hubPortalProxy_ = HubPortal(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                salt_,
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(implementation_), ""))
            )
        );

        hubPortalProxy_.initialize();

        console2.log("HubPortal:", address(hubPortalProxy_));

        return address(hubPortalProxy_);
    }

    function _deploySpokePortal(DeploymentParams memory params_, bytes32 salt_) internal returns (address) {
        SpokePortal implementation_ = new SpokePortal(params_.mToken, params_.registrar, params_.wormholeChainId);

        SpokePortal spokePortalProxy_ = SpokePortal(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                salt_,
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(implementation_), ""))
            )
        );

        spokePortalProxy_.initialize();

        console2.log("SpokePortal:", address(spokePortalProxy_));

        return address(spokePortalProxy_);
    }

    function _deployWormholeTransceiver(
        DeploymentParams memory params_,
        address nttManager_,
        bytes32 salt_
    ) internal returns (address) {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            nttManager_,
            params_.wormholeCoreBridge,
            params_.wormholeRelayerAddr,
            params_.specialRelayerAddr,
            params_.consistencyLevel,
            params_.gasLimit
        );

        WormholeTransceiver transceiverProxy_ = WormholeTransceiver(
            ICreateXLike(_CREATE_X_FACTORY).deployCreate3(
                salt_,
                abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(implementation_), ""))
            )
        );

        transceiverProxy_.initialize();

        console2.log("WormholeTransceiver:", address(transceiverProxy_));

        return address(transceiverProxy_);
    }

    function _deploySpokeRegistrar(address spokeNTTManager_) internal returns (address) {
        SpokeRegistrar spokeRegistrar_ = new SpokeRegistrar(spokeNTTManager_);

        console2.log("SpokeRegistrar:", address(spokeRegistrar_));

        return address(spokeRegistrar_);
    }

    function _deploySpokeMToken(address spokeRegistrar_) internal returns (address) {
        SpokeMToken spokeMToken_ = new SpokeMToken(spokeRegistrar_);

        console2.log("SpokeMToken:", address(spokeMToken_));

        return address(spokeMToken_);
    }

    function _configurePortal(address portal_, address transceiver_) internal {
        IManagerBase(portal_).setTransceiver(transceiver_);
        console2.log("Transceiver address set: ", transceiver_);

        INttManager(portal_).setThreshold(1);
        console2.log("Threshold set: ", uint256(1));
    }
}
