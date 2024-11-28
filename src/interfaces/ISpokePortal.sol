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
     * @notice Emitted when M Token index is received from Mainnet.
     * @param  messageId The unique identifier of the received message.
     * @param  index     M token index.
     */
    event MTokenIndexReceived(bytes32 indexed messageId, uint128 index);

    /**
     * @notice Emitted when the Registrar key is received from Mainnet.
     * @param  messageId The unique identifier of the received message.
     * @param  key       The Registrar key of some value.
     * @param  value     The value.
     */
    event RegistrarKeyReceived(bytes32 indexed messageId, bytes32 indexed key, bytes32 value);

    /**
     * @notice Emitted when the Registrar list status is received from Mainnet.
     * @param  messageId The unique identifier of the received message.
     * @param  listName  The name of the list.
     * @param  account   The account.
     * @param  status    Indicates if the account is added or removed from the list.
     */
    event RegistrarListStatusReceived(
        bytes32 indexed messageId,
        bytes32 indexed listName,
        address indexed account,
        bool status
    );
}
