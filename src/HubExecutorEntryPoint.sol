// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IWormhole } from "../lib/native-token-transfers/evm/lib/wormhole-solidity-sdk/src/interfaces/IWormhole.sol";
import { TransceiverRegistry } from "../lib/native-token-transfers/evm/src/NttManager/TransceiverRegistry.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";
import { ExecutorArgs, IHubExecutorEntryPoint } from "./interfaces/IHubExecutorEntryPoint.sol";
import { ExecutorEntryPoint } from "./ExecutorEntryPoint.sol";
import { IExecutor } from "./external/IExecutor.sol";
import { ExecutorMessages } from "./external/ExecutorMessages.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";

/// @title ExecutorEntryPoint
/// @notice The ExecutorEntryPoint contract is a shim contract that initiates
///         an M NTT transfer using the executor for relaying.
contract HubExecutorEntryPoint is ExecutorEntryPoint, IHubExecutorEntryPoint {
    constructor(
        uint16 _chainId,
        address _executor,
        address _portal,
        address _wormhole
    ) ExecutorEntryPoint(_chainId, _executor, _portal, _wormhole) {}

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
