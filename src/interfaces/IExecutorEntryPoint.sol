// SPDX-License-Identifier: Apache 2
pragma solidity 0.8.26;

struct ExecutorArgs {
    // The msg value to be passed into the Executor.
    uint256 value;
    // The refund address used by the Executor.
    address refundAddress;
    // The signed quote to be passed into the Executor.
    bytes signedQuote;
    // The relay instructions to be passed into the Executor.
    bytes instructions;
}

interface IExecutorEntryPoint {
    /// @notice Error when the refund to the sender fails.
    /// @dev Selector 0x2ca23714.
    /// @param refundAmount The refund amount.
    error RefundFailed(uint256 refundAmount);

    /// @notice Peer cannot have zero decimals.
    error InvalidPeerDecimals();

    /// @notice Transfer a given amount to a recipient on a given chain using the Executor for relaying.
    /// @param amount The amount to transfer.
    /// @param sourceToken M or an M extension that is supported by the Portal.
    /// @param destinationChainId The Wormhole chain ID for the destination.
    /// @param destinationToken The token address on the destination chain (M or Wrapped M).
    /// @param recipient The recipient address on the destination chain.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @return messageId The resulting message ID of the transfer
    function transferMLikeToken(
        uint256 amount,
        address sourceToken,
        uint16 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Send the M token index to a given chain using the Executor for relaying.
    /// @param destinationChainId The Wormhole chain ID for the destination.
    /// @param refundAddress The Wormhole address to refund excess gas to.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @return messageId The resulting message ID of the index send.
    function sendMTokenIndex(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs
    ) external payable returns (bytes32 messageId);

    /// @notice Send the earners Merkle root to Solana using the Executor for relaying.
    /// @param refundAddress The Wormhole address to refund excess gas to.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @return messageId The resulting message ID of the Merkle root send.
    function sendEarnersMerkleRoot(
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs
    ) external payable returns (bytes32 messageId);
}
