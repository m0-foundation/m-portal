// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

import { ContractHelper } from "../../lib/common/src/libs/ContractHelper.sol";
import { Proxy } from "../../lib/common/src/Proxy.sol";

import { MToken as SpokeMToken } from "../../lib/protocol/src/MToken.sol";
import { Registrar as SpokeRegistrar } from "../../lib/ttg/src/Registrar.sol";
import { EarnerManager as SpokeSmartMTokenEarnerManager } from "../../lib/smart-m-token/src/EarnerManager.sol";
import { SmartMToken as SpokeSmartMToken } from "../../lib/smart-m-token/src/SmartMToken.sol";

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { INttManager } from "../../lib/example-native-token-transfers/evm/src/interfaces/INttManager.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";
import { SpokeVault } from "../../src/SpokeVault.sol";

import { Utils } from "../helpers/Utils.sol";

contract DeployBase is Script, Utils {
    using stdJson for string;

    /* ============ Config Structs ============ */

    struct WormholeConfiguration {
        uint16 chainId;
        address coreBridge;
        address relayer;
        address specialRelayer;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    struct HubConfiguration {
        address mToken;
        address registrar;
        WormholeConfiguration wormhole;
    }

    struct SpokeConfiguration {
        address hubVault;
        uint16 hubVaultWormholechainId;
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

    function _deploySpokeSmartMToken(
        address deployer_,
        address spokeMToken_,
        address registrar_,
        address spokeVault_,
        address migrationAdmin_,
        function(address, uint64, uint64) internal burnNonces_
    )
        internal
        returns (
            address spokeSmartMTokenEarnerManagerImplementation_,
            address spokeSmartMTokenEarnerManagerProxy_,
            address spokeSmartMTokenImplementation_,
            address spokeSmartMTokenProxy_
        )
    {
        uint64 deployerNonce_ = vm.getNonce(deployer_);

        if (deployerNonce_ > _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE, deployerNonce_);
        }

        burnNonces_(deployer_, deployerNonce_, _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE, deployerNonce_);
        }

        // Pre-compute the expected SpokeSmartMTokenEarnerManager implementation address.
        address expectedSmartMTokenEarnerManagerImplementation_ = ContractHelper.getContractFrom(
            deployer_,
            _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_NONCE
        );

        spokeSmartMTokenEarnerManagerImplementation_ = address(
            new SpokeSmartMTokenEarnerManager(registrar_, migrationAdmin_)
        );

        if (expectedSmartMTokenEarnerManagerImplementation_ != spokeSmartMTokenEarnerManagerImplementation_) {
            revert ExpectedAddressMismatch(
                expectedSmartMTokenEarnerManagerImplementation_,
                spokeSmartMTokenEarnerManagerImplementation_
            );
        }

        console.log("SpokeSmartMTokenEarnerManagerImplementation:", spokeSmartMTokenEarnerManagerImplementation_);

        // Pre-compute the expected SpokeSmartMTokenEarnerManager proxy address.
        address expectedSmartMTokenEarnerManagerProxy_ = ContractHelper.getContractFrom(
            deployer_,
            _SPOKE_SMART_M_TOKEN_EARNER_MANAGER_PROXY_NONCE
        );

        spokeSmartMTokenEarnerManagerProxy_ = address(new Proxy(spokeSmartMTokenEarnerManagerImplementation_));

        if (expectedSmartMTokenEarnerManagerProxy_ != spokeSmartMTokenEarnerManagerProxy_) {
            revert ExpectedAddressMismatch(expectedSmartMTokenEarnerManagerProxy_, spokeSmartMTokenEarnerManagerProxy_);
        }

        console.log("SpokeSmartMTokenEarnerManagerProxy:", spokeSmartMTokenEarnerManagerProxy_);

        // Pre-compute the expected SpokeSmartMToken implementation address.
        address expectedSmartMTokenImplementation_ = ContractHelper.getContractFrom(
            deployer_,
            _SPOKE_SMART_M_TOKEN_NONCE
        );

        spokeSmartMTokenImplementation_ = address(
            new SpokeSmartMToken(
                spokeMToken_,
                registrar_,
                spokeSmartMTokenEarnerManagerProxy_,
                spokeVault_,
                migrationAdmin_
            )
        );

        if (expectedSmartMTokenImplementation_ != spokeSmartMTokenImplementation_) {
            revert ExpectedAddressMismatch(expectedSmartMTokenImplementation_, spokeSmartMTokenImplementation_);
        }

        console.log("SpokeSmartMTokenImplementation:", spokeSmartMTokenImplementation_);

        deployerNonce_ = vm.getNonce(deployer_);
        if (deployerNonce_ != _SPOKE_SMART_M_TOKEN_PROXY_NONCE) {
            revert DeployerNonceTooHigh(_SPOKE_SMART_M_TOKEN_PROXY_NONCE, deployerNonce_);
        }

        // Pre-compute the expected SpokeSmartMToken proxy address.
        address expectedSmartMTokenProxy_ = ContractHelper.getContractFrom(deployer_, _SPOKE_SMART_M_TOKEN_PROXY_NONCE);

        spokeSmartMTokenProxy_ = address(new Proxy(spokeSmartMTokenImplementation_));

        if (expectedSmartMTokenProxy_ != spokeSmartMTokenProxy_) {
            revert ExpectedAddressMismatch(expectedSmartMTokenProxy_, spokeSmartMTokenProxy_);
        }

        console.log("SpokeSmartMTokenProxy:", spokeSmartMTokenProxy_);
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
        string memory hub_ = string.concat("$.hub.", vm.toString(chainId_), ".");

        console.log("Hub configuration for chain ID %s loaded:", chainId_);

        hubConfig_.mToken = file_.readAddress(_readKey(hub_, "m_token"));
        hubConfig_.registrar = file_.readAddress(_readKey(hub_, "registrar"));

        console.log("M Token:", hubConfig_.mToken);
        console.log("Registrar:", hubConfig_.registrar);

        hubConfig_.wormhole = _loadWormholeConfig(file_, hub_);
    }

    function _loadSpokeConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (SpokeConfiguration memory spokeConfig_) {
        string memory file_ = vm.readFile(filepath_);
        string memory spoke_ = string.concat("$.spoke.", vm.toString(chainId_), ".");
        string memory hubVault_ = string.concat(spoke_, "hub_vault.");

        console.log("Spoke configuration for chain ID %s loaded:", chainId_);

        spokeConfig_.hubVault = file_.readAddress(_readKey(hubVault_, "address"));
        spokeConfig_.hubVaultWormholechainId = uint16(file_.readUint(_readKey(hubVault_, "wormhole_chain_id")));

        console.log("Hub Vault:", spokeConfig_.hubVault);
        console.log("Hub Vault Wormhole Chain ID:", spokeConfig_.hubVaultWormholechainId);

        spokeConfig_.wormhole = _loadWormholeConfig(file_, spoke_);
    }

    function _loadWormholeConfig(
        string memory file_,
        string memory parentNode_
    ) internal view returns (WormholeConfiguration memory wormholeConfig_) {
        string memory wormhole_ = string.concat(parentNode_, "wormhole.");

        wormholeConfig_.chainId = uint16(file_.readUint(_readKey(wormhole_, "chain_id")));
        wormholeConfig_.coreBridge = file_.readAddress(_readKey(wormhole_, "core_bridge"));
        wormholeConfig_.relayer = file_.readAddress(_readKey(wormhole_, "relayer"));
        wormholeConfig_.specialRelayer = file_.readAddress(_readKey(wormhole_, "special_relayer"));
        wormholeConfig_.consistencyLevel = uint8(file_.readUint(_readKey(wormhole_, "consistency_level")));
        wormholeConfig_.gasLimit = file_.readUint(_readKey(wormhole_, "gas_limit"));

        console.log("Wormhole chain ID:", wormholeConfig_.chainId);
        console.log("Wormhole Core Bridge:", wormholeConfig_.coreBridge);
        console.log("Wormhole Relayer:", wormholeConfig_.relayer);
        console.log("Wormhole Special Relayer:", wormholeConfig_.specialRelayer);
        console.log("Wormhole Consistency Level:", wormholeConfig_.consistencyLevel);
        console.log("Wormhole Gas Limit:", wormholeConfig_.gasLimit);
    }

    function _readKey(string memory parentNode_, string memory key_) internal view returns (string memory) {
        return string.concat(parentNode_, key_);
    }
}
