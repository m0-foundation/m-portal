// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Upgrader interface.
 * @author M^0 Labs
 */
interface IUpgrader {
    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted when the WormholeTransceiver address is 0x0.
    error ZeroWormholeTransceiver();

    /// @notice Executes the upgrade approved by governance.
    function execute() external;

    /// @notice Address of the Portal being upgraded.
    function portal() external view returns (address);

    /// @notice Address of the WormholeTransceiver used to relay messages.
    function wormholeTransceiver() external view returns (address);
}
