// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Subset of SwapFacility interface.
 * @author M0 Labs
 */
interface ISwapFacilityLike {
    /**
     * @notice Swaps $M token to $M Extension.
     * @param  extensionOut The address of the M Extension to swap to.
     * @param  amount       The amount of $M token to swap.
     * @param  recipient    The address to receive the swapped $M Extension tokens.
     */
    function swapInM(address extensionOut, uint256 amount, address recipient) external;

    /**
     * @notice Swaps $M Extension to $M token.
     * @param  extensionIn The address of the $M Extension to swap from.
     * @param  amount      The amount of $M Extension tokens to swap.
     * @param  recipient   The address to receive $M tokens.
     */
    function swapOutM(address extensionIn, uint256 amount, address recipient) external;

    /**
     * @notice Sets the trusted status of a router.
     * @param router The address of the router.
     * @param trusted The trusted status to set - `true` to add, `false` to remove router from the trusted list.
     */
    function setTrustedRouter(address router, bool trusted) external;

    /// @notice The name of the role that allows swapping $M Extension to $M token.
    function M_SWAPPER_ROLE() external view returns (bytes32);
}
