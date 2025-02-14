// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Subset of M Token interface required for Portal contracts.
 * @author M^0 Labs
 */
interface IMTokenLike {
    /// @notice The current index that would be written to storage if `updateIndex` is called.
    function currentIndex() external view returns (uint128);

    /**
     * @notice Checks if account is an earner.
     * @param  account The account to check.
     * @return True if account is an earner, false otherwise.
     */
    function isEarning(address account) external view returns (bool);

    /// @notice Starts earning for caller if allowed by TTG.
    function startEarning() external;

    /// @notice Stops earning for the account.
    function stopEarning(address account) external;
}
