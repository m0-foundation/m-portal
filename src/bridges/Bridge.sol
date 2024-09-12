// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IBridge } from "./interfaces/IBridge.sol";

/**
 * @title  Bridge
 * @author M^0 Labs
 * @notice A base contract for common bridging functionality.
 */
abstract contract Bridge is IBridge {
    /* ============ Variables ============ */
    /// @inheritdoc IBridge
    address public immutable portal;

    /* ============ Modifiers ============ */

    /// @dev Modifier to check if caller is the Portal.
    modifier onlyPortal() {
        if (msg.sender != portal) revert NotPortal();

        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the Bridge contract.
     * @param  portal_ The address of the Portal contract.
     */
    constructor(address portal_) {
        if ((portal = portal_) == address(0)) revert ZeroPortal();
    }
}
