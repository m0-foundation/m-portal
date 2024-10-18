// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IManagerBase } from "../../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { ITransceiver } from "../../../lib/example-native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import {
    WormholeTransceiver
} from "../../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../../HubPortal.sol";
import { SpokePortal } from "../../SpokePortal.sol";

import { IUpgrader } from "../interfaces/IUpgrader.sol";

/**
 * @title  Base upgrader contract.
 * @author M^0 Labs
 */
contract Upgrader is IUpgrader {
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

    /// @inheritdoc IUpgrader
    address public immutable portal;

    /// @inheritdoc IUpgrader
    address public immutable wormholeTransceiver;

    constructor(address portal_, address wormholeTransceiver_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((wormholeTransceiver = wormholeTransceiver_) == address(0)) revert ZeroWormholeTransceiver();
    }

    /// @inheritdoc IUpgrader
    function execute() external virtual {}

    function _upgradeHubPortal(PortalUpgradeParams memory params_) internal {
        HubPortal implementation_ = new HubPortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    function _upgradeSpokePortal(PortalUpgradeParams memory params_) internal {
        SpokePortal implementation_ = new SpokePortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    function _upgradeWormholeTransceiver(WormholeTransceiverUpgradeParams memory params_) internal {
        WormholeTransceiver implementation_ = new WormholeTransceiver(
            portal,
            params_.wormholeCoreBridge,
            params_.wormholeRelayerAddr,
            params_.specialRelayerAddr,
            params_.consistencyLevel,
            params_.gasLimit
        );

        ITransceiver(wormholeTransceiver).upgrade(address(implementation_));
    }
}
