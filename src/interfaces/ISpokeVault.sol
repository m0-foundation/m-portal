// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IMigratable } from "../../lib/common/src/interfaces/IMigratable.sol";

/**
 * @title  SpokeVault interface.
 * @author M0 Labs
 */
interface ISpokeVault is IMigratable {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the excess M held by the SpokeVault is transferred to the excess destination.
     * @param  excessDestination The address receiving the M tokens.
     * @param  amount            The amount of M tokens transferred.
     */
    event ExcessMTokenSent(address indexed excessDestination, uint256 amount);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the non-governance migrate function is called by an account other than the migration admin.
    error UnauthorizedMigration();

    /// @notice Emitted in constructor if M Token is 0x0.
    error ZeroMToken();

    /// @notice Emitted in constructor if Excess Destination is 0x0.
    error ZeroExcessDestination();

    /// @notice Emitted in constructor if Migration Admin is 0x0.
    error ZeroMigrationAdmin();

    /* ============ Interactive Functions ============ */

    /// @notice Transfers the total excess amount of M held by the SpokeVault to the excess destination.
    function transferExcessM() external;

    /* ============ Temporary Admin Migration ============ */

    /**
     * @notice Performs an arbitrarily defined migration.
     * @param  migrator The address of a migrator contract.
     */
    function migrate(address migrator) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The account that can call the `migrate(address migrator)` function.
    function migrationAdmin() external view returns (address migrationAdmin);

    /// @notice The address of the M token.
    function mToken() external view returns (address mToken);

    /// @notice The address receiving the excess M held by the SpokeVault.
    function excessDestination() external view returns (address excessDestination);
}
