// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IMTokenLike } from "./IMTokenLike.sol";

/**
 * @title  Subset of Spoke M Token interface required for `SpokePortal` contract.
 * @author M^0 Labs
 */
interface ISpokeMTokenLike is IMTokenLike {
    /**
     * @notice Mints tokens.
     * @dev    MUST only be callable by the SpokePortal.
     * @param  account The address of account to mint to.
     * @param  amount  The amount of M Token to mint.
     */
    function mint(address account, uint256 amount) external;

    /**
     * @notice Updates the index and mints tokens.
     * @dev    MUST only be callable by the SpokePortal.
     * @param  account The address of account to mint to.
     * @param  amount  The amount of M Token to mint.
     * @param  index   The index to update to.
     */
    function mint(address account, uint256 amount, uint128 index) external;

    /**
     * @notice Burns tokens of msg.sender.
     * @dev    MUST only be callable by the SpokePortal.
     * @param  amount  The amount of M Token to burn.
     */
    function burn(uint256 amount) external;

    /**
     * @notice Updates the latest index and latest accrual time in storage.
     * @param  index The new index to compute present amounts from principal amounts.
     */
    function updateIndex(uint128 index) external;
}
