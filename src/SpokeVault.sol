// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { Migratable } from "../lib/common/src/Migratable.sol";

import { ISpokeVault } from "./interfaces/ISpokeVault.sol";

/**
 * @title  Deprecated Vault residing on L2s and receiving excess M from Wrapped M.
 * @author M0 Labs
 * @dev    The Vault no longer bridges excess M to the Vault on Ethereum Mainnet. Since the excess destination of
 *         Wrapped M is immutable and set to this contract, excess M keeps accruing here and is swept to
 *         `excessDestination` by anyone calling `transferExcessM`.
 */
contract SpokeVault is ISpokeVault, Migratable {
    /* ============ Variables ============ */

    /// @inheritdoc ISpokeVault
    address public immutable migrationAdmin;

    /// @inheritdoc ISpokeVault
    address public immutable mToken;

    /// @inheritdoc ISpokeVault
    address public immutable excessDestination;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the SpokeVault contract.
     * @param  mToken_            The address of the M token.
     * @param  excessDestination_ The address receiving the excess M held by the SpokeVault.
     * @param  migrationAdmin_    The address of a migration admin.
     */
    constructor(address mToken_, address excessDestination_, address migrationAdmin_) {
        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((excessDestination = excessDestination_) == address(0)) revert ZeroExcessDestination();
        if ((migrationAdmin = migrationAdmin_) == address(0)) revert ZeroMigrationAdmin();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc ISpokeVault
    function transferExcessM() external {
        IERC20 mToken_ = IERC20(mToken);
        uint256 amount_ = mToken_.balanceOf(address(this));

        if (amount_ == 0) return;

        address excessDestination_ = excessDestination;

        mToken_.transfer(excessDestination_, amount_);

        emit ExcessMTokenSent(excessDestination_, amount_);
    }

    /* ============ Temporary Admin Migration ============ */

    /// @inheritdoc ISpokeVault
    function migrate(address migrator_) external {
        if (msg.sender != migrationAdmin) revert UnauthorizedMigration();

        _migrate(migrator_);
    }

    /* ============ Internal View/Pure Functions ============ */

    /// @dev The Registrar is deprecated, disabling the permissionless migration path. `migrate()` always reverts.
    function _getMigrator() internal pure override returns (address migrator_) {
        return address(0);
    }
}
