// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Migrator interface.
 * @author M^0 Labs
 */
interface IMigrator {
    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted when the WormholeTransceiver address is 0x0.
    error ZeroWormholeTransceiver();

    /// @notice Emitted when the Vault address is 0x0.
    error ZeroVault();

    /// @notice Executes the migration approved by governance.
    function migrate() external;

    /// @notice Address of the Portal being migrated.
    function portal() external view returns (address);

    /// @notice Address of the WormholeTransceiver used to relay messages.
    function wormholeTransceiver() external view returns (address);

    /// @notice Address of the Spoke Vault contract.
    function vault() external view returns (address);
}
