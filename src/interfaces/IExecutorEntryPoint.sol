// SPDX-License-Identifier: GPL-3.0
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

    /// @notice Emitted in the constructor if chain ID is 0.
    error ZeroChainId();

    /// @notice Emitted in the constructor if Executor address is 0x0.
    error ZeroExecutor();

    /// @notice Emitted in the constructor if Portal address is 0x0.
    error ZeroPortal();

    /// @notice Emitted in the constructor if Wormhole address is 0x0.
    error ZeroWormhole();

    /// @notice Transfer a given amount to a recipient on a given chain using the Executor for relaying.
    /// @param amount The amount to transfer.
    /// @param sourceToken M or an M extension that is supported by the Portal.
    /// @param destinationChainId The Wormhole chain ID for the destination.
    /// @param destinationToken The token address on the destination chain (M or Wrapped M).
    /// @param recipient The recipient address on the destination chain.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @param transceiverInstructions The transceiver specific instructions for quoting and sending.
    /// @return sequence The resulting sequence ID on the transceiver for the transfer.
    function transferMLikeToken(
        uint256 amount,
        address sourceToken,
        uint16 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (uint64 sequence);
}
