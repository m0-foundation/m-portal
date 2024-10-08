// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Governor interface.
 * @author M^0 Labs
 */
interface IGovernor {
    /// @notice Emitted when the Configurator address is 0x0.
    error ZeroConfigurator();

    /// @notice Emitted when the Migrator address is 0x0.
    error ZeroMigrator();

    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Executes the configuration approved by governance.
    function configure() external;

    /// @notice Executes the migration approved by governance.
    function migrate() external;

    /// @notice Address of the Portal being governed.
    function portal() external view returns (address);

    /// @notice Address of the Registrar where Configurator and Migrator are stored.
    function registrar() external view returns (address);
}
