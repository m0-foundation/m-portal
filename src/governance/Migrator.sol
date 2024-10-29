// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/example-native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { ITransceiver } from "../../lib/example-native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import {
    WormholeTransceiver
} from "../../lib/example-native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../HubPortal.sol";
import { SpokePortal } from "../SpokePortal.sol";

import { IMigrator } from "./interfaces/IMigrator.sol";

/**
 * @title  Base migrator contract.
 * @author M^0 Labs
 */
contract Migrator is IMigrator {
    /// @dev Portal upgrade parameters.
    struct PortalUpgradeParams {
        address mToken;
        address registrar;
        uint16 wormholeChainId;
    }

    /// @dev Wormhole transceiver upgrade parameters.
    struct WormholeTransceiverUpgradeParams {
        uint16 wormholeChainId;
        address wormholeCoreBridge;
        address wormholeRelayerAddr;
        address specialRelayerAddr;
        uint8 consistencyLevel;
        uint256 gasLimit;
    }

    /// @inheritdoc IMigrator
    address public immutable portal;

    /// @inheritdoc IMigrator
    address public immutable wormholeTransceiver;

    /**
     * @dev    Constructs the Migrator contract.
     * @param  portal_              The address of the portal contract.
     * @param  wormholeTransceiver_ The address of the wormhole transceiver contract.
     */
    constructor(address portal_, address wormholeTransceiver_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((wormholeTransceiver = wormholeTransceiver_) == address(0)) revert ZeroWormholeTransceiver();
    }

    /// @inheritdoc IMigrator
    function migrate() external virtual {}

    /**
     * @notice Upgrades the HubPortal contract.
     * @param  params_ The parameters for the upgrade.
     */
    function _upgradeHubPortal(PortalUpgradeParams memory params_) internal {
        HubPortal implementation_ = new HubPortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    /**
     * @notice Upgrades the SpokePortal contract.
     * @param  params_ The parameters for the upgrade.
     */
    function _upgradeSpokePortal(PortalUpgradeParams memory params_) internal {
        SpokePortal implementation_ = new SpokePortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    /**
     * @notice Upgrades the WormholeTransceiver contract.
     * @param  params_ The parameters for the upgrade.
     */
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
