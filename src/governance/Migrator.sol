// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IManagerBase } from "../../lib/native-token-transfers/evm/src/interfaces/IManagerBase.sol";
import { ITransceiver } from "../../lib/native-token-transfers/evm/src/interfaces/ITransceiver.sol";
import {
    WormholeTransceiver
} from "../../lib/native-token-transfers/evm/src/Transceiver/WormholeTransceiver/WormholeTransceiver.sol";

import { HubPortal } from "../HubPortal.sol";
import { SpokePortal } from "../SpokePortal.sol";

import { IMigrator } from "./interfaces/IMigrator.sol";
import { ISpokeVault } from "../interfaces/ISpokeVault.sol";

/**
 * @title  Base migrator contract.
 * @author M^0 Labs
 * @dev    Base contract that can be inherited by migrator contracts to perform contracts migrations.
 */
abstract contract Migrator is IMigrator {
    /// @dev Portal migration parameters.
    struct PortalMigrateParams {
        address mToken;
        address registrar;
        uint16 wormholeChainId;
    }

    /// @dev Wormhole transceiver migration parameters.
    struct WormholeTransceiverMigrateParams {
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

    /// @inheritdoc IMigrator
    address public immutable vault;

    /**
     * @dev    Constructs the Migrator contract.
     * @param  portal_              The address of the portal contract.
     * @param  wormholeTransceiver_ The address of the wormhole transceiver contract.
     * @param  vault_               The address of the vault contract.
     */
    constructor(address portal_, address wormholeTransceiver_, address vault_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
        if ((wormholeTransceiver = wormholeTransceiver_) == address(0)) revert ZeroWormholeTransceiver();
        if ((vault = vault_) == address(0)) revert ZeroVault();
    }

    /// @inheritdoc IMigrator
    function migrate() external virtual {}

    /**
     * @notice Migrates the HubPortal contract.
     * @param  params_ The parameters for the migrate.
     */
    function _migrateHubPortal(PortalMigrateParams memory params_) internal {
        HubPortal implementation_ = new HubPortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    /**
     * @notice Migrates the SpokePortal contract.
     * @param  params_ The parameters for the migrate.
     */
    function _migrateSpokePortal(PortalMigrateParams memory params_) internal {
        SpokePortal implementation_ = new SpokePortal(params_.mToken, params_.registrar, params_.wormholeChainId);
        IManagerBase(portal).upgrade(address(implementation_));
    }

    /**
     * @notice Migrates the WormholeTransceiver contract.
     * @param  params_ The parameters for the migrate.
     */
    function _migrateWormholeTransceiver(WormholeTransceiverMigrateParams memory params_) internal {
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

    /**
     * @notice Migrates the Spoke Vault contract.
     * @param  migrator_ The address of the migrator contract.
     */
    function _migrateVault(address migrator_) internal {
        ISpokeVault(vault).migrate(migrator_);
    }
}
