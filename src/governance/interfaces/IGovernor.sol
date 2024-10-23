// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Governor interface.
 * @author M^0 Labs
 */
interface IGovernor {
    /// @notice Emitted when the Configurator address is 0x0.
    error ZeroConfigurator();

    /// @notice Emitted when the Upgrader address is 0x0.
    error ZeroUpgrader();

    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted when the Governor admin address is 0x0.
    error ZeroGovernorAdmin();

    /// @notice Emitted when the caller is not the Governor admin.
    error UnauthorizedGovernorAdmin();

    /// @notice Executes the configuration approved by governance.
    function configure() external;

    /// @notice Executes the upgrade approved by governance.
    function configure(address configurator) external;

    /// @notice Executes the upgrade approved by governance.
    function upgrade() external;

    /// @notice Executes the upgrade approved by governance.
    function upgrade(address upgrader) external;

    /// @notice Address of the Portal being governed.
    function portal() external view returns (address);

    /// @notice Address of the Registrar where Configurator and Upgrader are stored.
    function registrar() external view returns (address);

    /// @notice Address of the Governor admin.
    function governorAdmin() external view returns (address);

    /// @notice Transfers the ownership of the Governor to a new Governor admin.
    function transferOwnership(address newGovernorAdmin_) external;

    /// @notice Disables the Governor admin functionality.
    function disableGovernorAdmin() external;
}
