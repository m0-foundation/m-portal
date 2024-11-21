// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IPortal } from "./IPortal.sol";

/**
 * @title  HubPortal interface.
 * @author M^0 Labs
 */
interface IHubPortal is IPortal {
    /* ============ Events ============ */

    /**
     * @notice Emitted when earning is enabled for the Hub Portal.
     * @param  index The index at which earning was enabled.
     */
    event EarningEnabled(uint128 index);

    /**
     * @notice Emitted when earning is disabled for the Hub Portal.
     * @param  index The index at which earning was disabled.
     */
    event EarningDisabled(uint128 index);

    /**
     * @notice Emitted when the M token index is sent to a destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  messageId          The unique identifier for the sent message.
     * @param  index              The the M token index.
     */
    event MTokenIndexSent(uint16 indexed destinationChainId, bytes32 messageId, uint128 index);

    /**
     * @notice Emitted when the Registrar key is sent to a destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  messageId          The unique identifier for the sent message.
     * @param  key                The key that was sent.
     * @param  value              The value that was sent.
     */
    event RegistrarKeySent(uint16 indexed destinationChainId, bytes32 messageId, bytes32 indexed key, bytes32 value);

    /**
     * @notice Emitted when the Registrar list status for an account is sent to a destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  messageId          The unique identifier for the sent message.
     * @param  listName           The name of the list.
     * @param  account            The account.
     * @param  status             The status of the account in the list.
     */
    event RegistrarListStatusSent(
        uint16 indexed destinationChainId,
        bytes32 messageId,
        bytes32 indexed listName,
        address indexed account,
        bool status
    );

    /* ============ Custom Errors ============ */

    /// @notice Emitted when trying to enable earning after it has been explicitly disabled.
    error EarningCannotBeReenabled();

    /// @notice Emitted when performing an operation that is not allowed when earning is disabled.
    error EarningIsDisabled();

    /// @notice Emitted when performing an operation that is not allowed when earning is enabled.
    error EarningIsEnabled();

    /// @notice Emitted when calling `disableEarning` if the Hub Portal is approved as earner by TTG.
    error IsApprovedEarner();

    /// @notice Emitted when calling `enableEarning` if the Hub Portal is not approved as earner by TTG.
    error NotApprovedEarner();

    /* ============ View/Pure Functions ============ */

    /// @notice Indicates whether earning for HubPortal was ever enabled.
    function wasEarningEnabled() external returns (bool);

    /// @notice Returns the value of M Token index when earning for HubPortal was disabled.
    function disableEarningIndex() external returns (uint128);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sends the M token index to the destination chain.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  refundAddress           Refund address to receive excess native gas.
     * @return ID uniquely identifying the message
     */
    function sendMTokenIndex(uint16 destinationChainId, bytes32 refundAddress) external payable returns (bytes32);

    /**
     * @notice Sends the Registrar key to the destination chain.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  key                     The key to dispatch.
     * @param  refundAddress           Refund address to receive excess native gas.
     * @return ID uniquely identifying the message
     */
    function sendRegistrarKey(
        uint16 destinationChainId,
        bytes32 key,
        bytes32 refundAddress
    ) external payable returns (bytes32);

    /**
     * @notice Sends the Registrar list status for an account to the destination chain.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  listName                The name of the list.
     * @param  account                 The account.
     * @param  refundAddress           Refund address to receive excess native gas.
     * @return ID uniquely identifying the message
     */
    function sendRegistrarListStatus(
        uint16 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress
    ) external payable returns (bytes32);

    /// @notice Enables earning for the Hub Portal if allowed by TTG.
    function enableEarning() external;

    /// @notice Disables earning for the Hub Portal if disallowed by TTG.
    function disableEarning() external;
}
