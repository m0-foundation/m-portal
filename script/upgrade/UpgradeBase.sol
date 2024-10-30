// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Script, console2 } from "../../lib/forge-std/src/Script.sol";

import { ITransceiver } from "../../lib/example-native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";

import { Utils } from "../helpers/Utils.sol";

contract UpgradeBase is Script, Utils {
    struct PortalUpgradeParams {
        address mToken;
        address registrar;
        uint16 wormholeChainId;
    }

    struct WormholeTransceiverUpgradeParams {
        uint16 wormholeChainId;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    function _upgradeWormholeTransceiver(address deployer_, WormholeTransceiverUpgradeParams memory params_) internal {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            _getCreate3Address(deployer_, _computeSalt(deployer_, "Portal")),
            params_.wormholeCoreBridge,
            params_.wormholeRelayerAddr,
            params_.specialRelayerAddr,
            params_.consistencyLevel,
            params_.gasLimit
        );

        console2.log("WormholeTransceiver implementation deployed at: ", address(implementation_));

        ITransceiver(_getCreate3Address(deployer_, _computeSalt(deployer_, "WormholeTransceiver"))).upgrade(
            address(implementation_)
        );
    }

    function _upgradeHubPortal(address deployer_, PortalUpgradeParams memory params_) internal {
        HubPortal implementation_ = new HubPortal(params_.mToken, params_.registrar, params_.wormholeChainId);

        console2.log("HubPortal implementation deployed at: ", address(implementation_));

        IManagerBase(_getCreate3Address(deployer_, _computeSalt(deployer_, "Portal"))).upgrade(
            address(implementation_)
        );
    }

    function _upgradeSpokePortal(address deployer_, PortalUpgradeParams memory params_) internal {
        SpokePortal implementation_ = new SpokePortal(params_.mToken, params_.registrar, params_.wormholeChainId);

        console2.log("SpokePortal implementation deployed at: ", address(implementation_));

        IManagerBase(_getCreate3Address(deployer_, _computeSalt(deployer_, "Portal"))).upgrade(
            address(implementation_)
        );
    }
}
