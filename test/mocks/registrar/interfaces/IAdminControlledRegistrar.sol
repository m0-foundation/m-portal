// SPDX-License-Identifier: GPL-3.0

import { IERC6372 } from "./IERC6372.sol";

pragma solidity ^0.8.23;

/**
 * @title  A book of record of TTG-specific contracts and arbitrary key-value pairs and lists.
 * @dev    Simplified Admin controlled registrar for testing
 * @author M^0 Labs
 */
interface IAdminControlledRegistrar is IERC6372 {
    /* ============ Events ============ */

    /**
     * @notice Emitted when `account` is added to `list`.
     * @param  list    The key for the list.
     * @param  account The address of the added account.
     */
    event AddressAddedToList(bytes32 indexed list, address indexed account);

    /**
     * @notice Emitted when `account` is removed from `list`.
     * @param  list    The key for the list.
     * @param  account The address of the removed account.
     */
    event AddressRemovedFromList(bytes32 indexed list, address indexed account);

    /**
     * @notice Emitted when `key` is set to `value`.
     * @param  key   The key.
     * @param  value The value.
     */
    event KeySet(bytes32 indexed key, bytes32 indexed value);

    /* ============ Custom Errors ============ */

    /// @notice Revert message when the caller is the admin.
    error NotAdmin();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Adds `account` to `list`.
     * @param  list    The key for some list.
     * @param  account The address of some account to be added.
     */
    function addToList(bytes32 list, address account) external;

    /**
     * @notice Removes `account` from `list`.
     * @param  list    The key for some list.
     * @param  account The address of some account to be removed.
     */
    function removeFromList(bytes32 list, address account) external;

    /**
     * @notice Sets `key` to `value`.
     * @param  key   Some key.
     * @param  value Some value.
     */
    function setKey(bytes32 key, bytes32 value) external;

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the starting timestamp of Epoch 1.
    function clockStartingTimestamp() external pure returns (uint256);

    /// @notice Returns the period/duration, in seconds, of an epoch.
    function clockPeriod() external pure returns (uint256);

    /**
     * @notice Returns the value of `key`.
     * @param  key Some key.
     * @return Some value.
     */
    function get(bytes32 key) external view returns (bytes32);

    /**
     * @notice Returns the values of `keys` respectively.
     * @param  keys Some keys.
     * @return Some values.
     */
    function get(bytes32[] calldata keys) external view returns (bytes32[] memory);

    /**
     * @notice Returns whether `list` contains `account`.
     * @param  list    The key for some list.
     * @param  account The address of some account.
     * @return Whether `list` contains `account`.
     */
    function listContains(bytes32 list, address account) external view returns (bool);

    /**
     * @notice Returns whether `list` contains all specified accounts.
     * @param  list     The key for some list.
     * @param  accounts An array of addressed of some accounts.
     * @return Whether `list` contains all specified accounts.
     */
    function listContains(bytes32 list, address[] calldata accounts) external view returns (bool);

    /// @notice Returns the address of the admin.
    function admin() external view returns (address);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address);
}
