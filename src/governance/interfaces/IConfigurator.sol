// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Configurator interface.
 * @author M^0 Labs
 */
interface IConfigurator {
    /// @notice Emitted when the Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted when the WormholeTransceiver address is 0x0.
    error ZeroWormholeTransceiver();

    /// @notice Executes the configuration approved by governance.
    function configure() external;

    /// @notice Address of the Portal being configured.
    function portal() external view returns (address);

    /// @notice Address of the WormholeTransceiver used to relay messages.
    function wormholeTransceiver() external view returns (address);
}
