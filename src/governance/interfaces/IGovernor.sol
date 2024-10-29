// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Governor interface.
 * @author M^0 Labs
 */
interface IGovernor {
    /* ============ Events ============ */

    /**
     * @dev Emitted when Governor Admin has been changed.
     * @param previousGovernorAdmin previous Governor Admin address.
     * @param newGovernorAdmin new Governor Admin address.
     */
    event GovernorAdminTransferred(address indexed previousGovernorAdmin, address indexed newGovernorAdmin);

    /* ============ Custom Errors ============ */

    /**
     * @notice Emitted when the delegatecall failed.
     * @param  data The data returned by the failed call.
     */
    error DelegatecallFailed(bytes data);

    /// @notice Emitted when the caller is not the Governor admin.
    error UnauthorizedGovernorAdmin();

    /// @notice Emitted when the Configurator address is 0x0.
    error ZeroConfigurator();

    /// @notice Emitted when the Governor admin address is 0x0.
    error ZeroGovernorAdmin();

    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted when the Upgrader address is 0x0.
    error ZeroUpgrader();

    /* ============ Interactive Functions ============ */

    /// @notice Executes the configuration approved by governance.
    function configure() external;

    /**
     * @notice Executes the configuration in `configurator`.
     * @dev    MUST only be callable by the Governor admin.
     * @param  configurator The address of the Configurator contract.
     */
    function configure(address configurator) external;

    /// @notice Executes the upgrade approved by governance.
    function upgrade() external;

    /**
     * @notice Executes the upgrade in `upgrader`.
     * @dev    MUST only be callable by the Governor admin.
     * @param  upgrader The address of the Upgrader contract.
     */
    function upgrade(address upgrader) external;

    /**
     * @notice Transfers ownership of the Governor to a new Governor admin.
     * @dev    MUST only be callable by the current Governor admin.
     * @param  newGovernorAdmin The address to which the Governor admin role will be transferred.
     */
    function transferOwnership(address newGovernorAdmin) external;

    /**
     * @notice Disables the Governor admin functionality.
     * @dev    MUST only be callable by the current Governor admin.
     */
    function disableGovernorAdmin() external;

    /* ============ View/Pure Functions ============ */

    /// @notice Address of the Governor admin.
    function governorAdmin() external view returns (address);

    /// @notice Address of the Portal being governed.
    function portal() external view returns (address);

    /// @notice Address of the Registrar where Configurator and Upgrader are stored.
    function registrar() external view returns (address);
}
