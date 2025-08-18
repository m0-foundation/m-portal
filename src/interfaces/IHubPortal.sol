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

    /**
     * @notice Emitted when Merkle Tree Builder contract is set.
     * @param  merkleTreeBuilder The address of Merkle Tree Builder contract.
     */
    event MerkleTreeBuilderSet(address merkleTreeBuilder);

    /**
     * @notice Emitted when earners Merkle root is sent to Solana.
     * @param  messageId         The unique identifier for the sent message.
     * @param  earnersMerkleRoot The Merkle root of earners.
     */
    event EarnersMerkleRootSent(bytes32 messageId, bytes32 earnersMerkleRoot);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when trying to enable earning after it has been explicitly disabled.
    error EarningCannotBeReenabled();

    /// @notice Emitted when performing an operation that is not allowed when earning is disabled.
    error EarningIsDisabled();

    /// @notice Emitted when performing an operation that is not allowed when earning is enabled.
    error EarningIsEnabled();

    /// @notice Emitted when calling `setMerkleTreeBuilder` if Merkle Tree Builder address is 0x0.
    error ZeroMerkleTreeBuilder();

    /// @notice Emitted when the destination chain is not supported
    error UnsupportedDestinationChain(uint16 destinationChainId);

    /* ============ View/Pure Functions ============ */

    /// @notice Indicates whether earning for HubPortal was ever enabled.
    function wasEarningEnabled() external returns (bool);

    /// @notice Returns the value of M Token index when earning for HubPortal was disabled.
    function disableEarningIndex() external returns (uint128);

    /// @notice Returns the address of Merkle tree builder.
    function merkleTreeBuilder() external returns (address);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sends the M token index to the destination chain.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  refundAddress           The refund address to receive excess native gas.
     * @param  transceiverInstructions The transceiver specific instructions for quoting and sending.
     * @return messageId               The ID uniquely identifying the message.
     */
    function sendMTokenIndex(
        uint16 destinationChainId,
        bytes32 refundAddress,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Sends the Registrar key to the destination chain.
     * @dev    Not supported for Solana.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  key                     The key to dispatch.
     * @param  refundAddress           The refund address to receive excess native gas.
     * @param  transceiverInstructions The transceiver specific instructions for quoting and sending.
     * @return messageId               The ID uniquely identifying the message
     */
    function sendRegistrarKey(
        uint16 destinationChainId,
        bytes32 key,
        bytes32 refundAddress,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Sends the Registrar list status for an account to the destination chain.
     * @dev    Not supported for Solana.
     * @param  destinationChainId      The Wormhole destination chain ID.
     * @param  listName                The name of the list.
     * @param  account                 The account.
     * @param  refundAddress           The refund address to receive excess native gas.
     * @param  transceiverInstructions The transceiver specific instructions for quoting and sending.
     * @return messageId               The ID uniquely identifying the message.
     */
    function sendRegistrarListStatus(
        uint16 destinationChainId,
        bytes32 listName,
        address account,
        bytes32 refundAddress,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Sends earners Merkle root to Solana.
     * @param  refundAddress           The refund address to receive excess native gas.
     * @param  transceiverInstructions The transceiver specific instructions for quoting and sending.
     * @return messageId               The ID uniquely identifying the message.
     */
    function sendEarnersMerkleRoot(
        bytes32 refundAddress,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Sets Merkle Tree Builder contract.
     * @param  merkleTreeBuilder The address of Merkle Tree Builder contract.
     */
    function setMerkleTreeBuilder(address merkleTreeBuilder) external;

    /// @notice Enables earning for the Hub Portal if allowed by TTG.
    function enableEarning() external;

    /// @notice Disables earning for the Hub Portal if disallowed by TTG.
    function disableEarning() external;
}
