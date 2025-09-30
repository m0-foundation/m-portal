// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IHubPortal } from "./interfaces/IHubPortal.sol";
import { ExecutorArgs, IHubExecutorEntryPoint } from "./interfaces/IHubExecutorEntryPoint.sol";
import { ExecutorEntryPoint } from "./ExecutorEntryPoint.sol";

/// @title ExecutorEntryPoint
/// @notice The ExecutorEntryPoint contract is a shim contract that initiates
///         an M NTT transfer using the executor for relaying.
contract HubExecutorEntryPoint is ExecutorEntryPoint, IHubExecutorEntryPoint {
    constructor(
        address _executor,
        address _portal,
        address _wormhole
    ) ExecutorEntryPoint(_executor, _portal, _wormhole) {}

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IHubExecutorEntryPoint
    function sendMTokenIndex(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (uint64 sequence) {
        address emitter;
        (emitter, sequence) = _getNextTransceiverSequence();

        IHubPortal(portal).sendMTokenIndex{ value: msg.value - executorArgs.value }(
            destinationChainId,
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        _requestExecution(destinationChainId, emitter, sequence, executorArgs);
    }

    /// @inheritdoc IHubExecutorEntryPoint
    function sendEarnersMerkleRoot(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (uint64 sequence) {
        address emitter;
        (emitter, sequence) = _getNextTransceiverSequence();

        IHubPortal(portal).sendEarnersMerkleRoot{ value: msg.value - executorArgs.value }(
            destinationChainId,
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        _requestExecution(destinationChainId, emitter, sequence, executorArgs);
    }
}
