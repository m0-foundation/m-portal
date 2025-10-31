// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { console } from "../../lib/forge-std/src/console.sol";

import { ITransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../src/HubPortal.sol";
import { SpokePortal } from "../../src/SpokePortal.sol";

import { ScriptBase } from "../ScriptBase.sol";
import { WormholeTransceiverConfig } from "../config/WormholeConfig.sol";

contract UpgradeBase is ScriptBase {
    function _upgradeWormholeTransceiver(
        address portal_,
        address transceiver_,
        WormholeTransceiverConfig memory config_
    ) internal {
        address implementation_ = _deployWormholeTransceiver(portal_, config_);
        ITransceiver(transceiver_).upgrade(implementation_);
    }

    function _deployWormholeTransceiver(
        address portal_,
        WormholeTransceiverConfig memory config_
    ) internal returns (address) {
        address implementation_ = address(
            new WormholeTransceiver(
                portal_,
                config_.coreBridge,
                config_.relayer,
                config_.specialRelayer,
                config_.consistencyLevel,
                config_.gasLimit
            )
        );

        console.log("WormholeTransceiver implementation deployed at: ", implementation_);

        return implementation_;
    }

    function _upgradeHubPortal(
        address portal_,
        address mToken_,
        address registrar_,
        address swapFacility_,
        uint16 wormholeChainId_
    ) internal {
        address implementation_ = _deployHubPortalImplementation(mToken_, registrar_, swapFacility_, wormholeChainId_);
        IManagerBase(portal_).upgrade(implementation_);
    }

    function _deployHubPortalImplementation(
        address mToken_,
        address registrar_,
        address swapFacility_,
        uint16 wormholeChainId_
    ) internal returns (address) {
        address implementation_ = address(new HubPortal(mToken_, registrar_, swapFacility_, wormholeChainId_));

        console.log("HubPortal implementation deployed at: ", implementation_);

        return implementation_;
    }

    function _upgradeSpokePortal(
        address portal_,
        address mToken_,
        address registrar_,
        address swapFacility_,
        uint16 wormholeChainId_
    ) internal {
        address implementation_ = _deploySpokePortalImplementation(
            mToken_,
            registrar_,
            swapFacility_,
            wormholeChainId_
        );

        console.log("SpokePortal implementation deployed at: ", address(implementation_));

        IManagerBase(portal_).upgrade(implementation_);
    }

    function _deploySpokePortalImplementation(
        address mToken_,
        address registrar_,
        address swapFacility_,
        uint16 wormholeChainId_
    ) internal returns (address) {
        address implementation_ = address(new SpokePortal(mToken_, registrar_, swapFacility_, wormholeChainId_));

        console.log("SpokePortal implementation deployed at: ", implementation_);

        return implementation_;
    }
}
