// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IPortal } from "./IPortal.sol";

/**
 * @title  SpokePortal interface.
 * @author M^0 Labs
 */
interface ISpokePortal is IPortal {
    /* ============ Events ============ */

    /**
     * @notice Emitted when the M Token index is received from Mainnet.
     * @param  bridge The address of the bridge that received the message.
     * @param  index  The the M token index.
     */
    event MTokenIndexReceived(address indexed bridge, uint128 index);

    /**
     * @notice Emitted when the Registrar key is received from Mainnet.
     * @param  bridge The address of the bridge that received the message.
     * @param  key    The Registrar key of some value.
     * @param  value  The value.
     */
    event RegistrarKeyReceived(address indexed bridge, bytes32 indexed key, bytes32 value);

    /**
     * @notice Emitted when the Registrar list status is received from Mainnet.
     * @param  bridge   The address of the bridge that received the message.
     * @param  listName The name of the list.
     * @param  account  The account.
     * @param  status   The status of the account in the list.
     */
    event RegistrarListStatusReceived(
        address indexed bridge,
        bytes32 indexed listName,
        address indexed account,
        bool status
    );

    /* ============ Interactive Functions ============ */

    /**
     * @notice Update the M Token index from the source chain.
     * @dev    MUST only be callable by an approved bridge.
     * @param  index The index from the source chain.
     */
    function updateMTokenIndex(uint128 index) external;

    /**
     * @notice Sets a Registrar key from the source chain.
     * @dev    MUST only be callable by an approved bridge.
     * @param  key   The key of some value.
     * @param  value Some value.
     */
    function setRegistrarKey(bytes32 key, bytes32 value) external;

    /**
     * @notice Sets a Registrar list status for an account from the source chain.
     * @dev    MUST only be callable by an approved bridge.
     * @param  listName The name of the list.
     * @param  account  The account.
     * @param  status   The status of the account in the list.
     */
    function setRegistrarListStatus(bytes32 listName, address account, bool status) external;
}
