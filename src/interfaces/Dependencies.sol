// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Subset of M Token interface required for source contracts.
 * @author M^0 Labs
 */
interface IMTokenLike {
    /// @notice The current index that would be written to storage if `updateIndex` is called.
    function currentIndex() external view returns (uint128 currentIndex);

    /**
     * @notice Checks if account is an earner.
     * @param  account The account to check.
     * @return True if account is an earner, false otherwise.
     */
    function isEarning(address account) external view returns (bool);

    /// @notice Starts earning for caller if allowed by TTG.
    function startEarning() external;

    /// @notice Stops earning for caller.
    function stopEarning() external;
}

/**
 * @title  Subset of Spoke M Token interface required for source contracts.
 * @author M^0 Labs
 */
interface ISpokeMTokenLike is IMTokenLike {
    /**
     * @notice Updates the index and mints tokens.
     * @dev    MUST only be callable by the SpokePortal.
     * @param  account The address of account to mint to.
     * @param  amount  The amount of M Token to mint.
     * @param  index   The index to update to.
     */
    function mint(address account, uint256 amount, uint128 index) external;

    /**
     * @notice Burns tokens.
     * @dev    MUST only be callable by the SpokePortal.
     * @param  account The address of account to burn from.
     * @param  amount  The amount of M Token to burn.
     */
    function burn(address account, uint256 amount) external;

    /**
     * @notice Updates the latest index and latest accrual time in storage.
     * @param  index The new index to compute present amounts from principal amounts.
     */
    function updateIndex(uint128 index) external;
}

/**
 * @title  Subset of Registrar interface required for source contracts.
 * @author M^0 Labs
 */
interface IRegistrarLike {
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

    /**
     * @notice Returns the value of `key`.
     * @param  key Some key.
     * @return Some value.
     */
    function get(bytes32 key) external view returns (bytes32);

    /**
     * @notice Returns whether `list` contains `account`.
     * @param  list    The key for some list.
     * @param  account The address of some account.
     * @return Whether `list` contains `account`.
     */
    function listContains(bytes32 list, address account) external view returns (bool);

    /// @notice Returns the address of the Portal contract.
    function portal() external view returns (address);
}
