// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IExecutorEntryPoint, ExecutorArgs } from "./IExecutorEntryPoint.sol";

interface IHubExecutorEntryPoint is IExecutorEntryPoint {
    /// @notice Send the M token index to a given chain using the Executor for relaying.
    /// @param destinationChainId The Wormhole chain ID for the destination.
    /// @param refundAddress The Wormhole address to refund excess gas to.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @param transceiverInstructions The transceiver specific instructions for quoting and sending.
    /// @return sequence The resulting sequence ID on the transceiver for the index send.
    function sendMTokenIndex(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (uint64 sequence);

    /// @notice Send the earners Merkle root to SVM chains using the Executor for relaying.
    /// @param destinationChainId The Wormhole chain ID for the destination.
    /// @param refundAddress The Wormhole address to refund excess gas to.
    /// @param executorArgs The arguments to be passed into the Executor.
    /// @param transceiverInstructions The transceiver specific instructions for quoting and sending.
    /// @return sequence The resulting sequence ID on the transceiver for the Merkle root send.
    function sendEarnersMerkleRoot(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (uint64 sequence);
}
