// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";
import { Script } from "../../lib/forge-std/src/Script.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

import { ITransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";

import { Utils } from "../helpers/Utils.sol";

contract UpgradeBase is Script, Utils {
    using stdJson for string;

    /* ============ Struct functions ============ */

    struct PortalConfiguration {
        address mToken;
        address registrar;
        address portal;
        uint16 wormholeChainId;
    }

    struct WormholeTransceiverConfiguration {
        address portal;
        address coreBridge;
        address relayer;
        address specialRelayer;
        address transceiver;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    /* ============ Upgrade functions ============ */

    function _upgradeWormholeTransceiver(WormholeTransceiverConfiguration memory config_) internal {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            config_.portal,
            config_.coreBridge,
            config_.relayer,
            config_.specialRelayer,
            config_.consistencyLevel,
            config_.gasLimit
        );

        console.log("WormholeTransceiver implementation deployed at: ", address(implementation_));

        ITransceiver(config_.transceiver).upgrade(address(implementation_));
    }

    function _upgradeHubPortal(PortalConfiguration memory config_) internal {
        HubPortal implementation_ = new HubPortal(config_.mToken, config_.registrar, config_.wormholeChainId);

        console.log("HubPortal implementation deployed at: ", address(implementation_));

        IManagerBase(config_.portal).upgrade(address(implementation_));
    }

    function _upgradeSpokePortal(PortalConfiguration memory config_) internal {
        SpokePortal implementation_ = new SpokePortal(config_.mToken, config_.registrar, config_.wormholeChainId);

        console.log("SpokePortal implementation deployed at: ", address(implementation_));

        IManagerBase(config_.portal).upgrade(address(implementation_));
    }

    /* ============ JSON Config loading functions ============ */

    function _loadPortalConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (PortalConfiguration memory portalConfig_) {
        string memory file_ = vm.readFile(filepath_);
        string memory config_ = string.concat("$.config.", vm.toString(chainId_), ".");

        console.log("Portal configuration for chain ID %s loaded:", chainId_);

        portalConfig_.mToken = file_.readAddress(_readKey(config_, "m_token"));
        portalConfig_.registrar = file_.readAddress(_readKey(config_, "registrar"));
        portalConfig_.portal = file_.readAddress(_readKey(config_, "portal"));
        portalConfig_.wormholeChainId = uint16(file_.readUint(_readKey(config_, "wormhole.chain_id")));

        console.log("M Token:", portalConfig_.mToken);
        console.log("Registrar:", portalConfig_.registrar);
        console.log("Portal:", portalConfig_.portal);
        console.log("Wormhole chain ID:", portalConfig_.wormholeChainId);
    }

    function _loadWormholeConfig(
        string memory filepath_,
        uint256 chainId_
    ) internal view returns (WormholeTransceiverConfiguration memory wormholeConfig_) {
        string memory file_ = vm.readFile(filepath_);
        string memory config_ = string.concat("$.config.", vm.toString(chainId_), ".");
        string memory wormhole_ = string.concat(config_, "wormhole.");

        wormholeConfig_.portal = file_.readAddress(_readKey(config_, "portal"));
        wormholeConfig_.transceiver = file_.readAddress(_readKey(wormhole_, "transceiver"));
        wormholeConfig_.coreBridge = file_.readAddress(_readKey(wormhole_, "core_bridge"));
        wormholeConfig_.relayer = file_.readAddress(_readKey(wormhole_, "relayer"));
        wormholeConfig_.specialRelayer = file_.readAddress(_readKey(wormhole_, "special_relayer"));
        wormholeConfig_.consistencyLevel = uint8(file_.readUint(_readKey(wormhole_, "consistency_level")));
        wormholeConfig_.gasLimit = file_.readUint(_readKey(wormhole_, "gas_limit"));

        console.log("Portal:", wormholeConfig_.portal);
        console.log("Wormhole Transceiver:", wormholeConfig_.transceiver);
        console.log("Wormhole Core Bridge:", wormholeConfig_.coreBridge);
        console.log("Wormhole Relayer:", wormholeConfig_.relayer);
        console.log("Wormhole Special Relayer:", wormholeConfig_.specialRelayer);
        console.log("Wormhole Consistency Level:", wormholeConfig_.consistencyLevel);
        console.log("Wormhole Gas Limit:", wormholeConfig_.gasLimit);
    }
}
