// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";
import { ExecutorArgs, IExecutorEntryPoint } from "./interfaces/IExecutorEntryPoint.sol";
import { IExecutor } from "./external/IExecutor.sol";
import { ExecutorMessages } from "./external/ExecutorMessages.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";

/// @title ExecutorEntryPoint
/// @notice The ExecutorEntryPoint contract is a shim contract that initiates
///         an M NTT transfer using the executor for relaying.
contract ExecutorEntryPoint is IExecutorEntryPoint {
    using TypeConverter for address;

    uint16 public immutable chainId;
    address public immutable executor;
    address public immutable portal;

    string public constant VERSION = "ExecutorEntryPoint-0.0.1";

    constructor(uint16 _chainId, address _executor, address _portal) {
        if ((chainId = _chainId) == 0) revert ZeroChainId();
        if ((executor = _executor) == address(0)) revert ZeroExecutor();
        if ((portal = _portal) == address(0)) revert ZeroPortal();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IExecutorEntryPoint
    function transferMLikeToken(
        uint256 amount,
        address sourceToken,
        uint16 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId) {
        // Custody the tokens in this contract and approve Portal to spend them.
        amount = _custodyTokens(sourceToken, amount);

        // Initiate the transfer.
        IERC20(sourceToken).approve(portal, amount);
        uint64 sequence = IPortal(portal).transferMLikeToken{ value: msg.value - executorArgs.value }(
            amount,
            sourceToken,
            destinationChainId,
            destinationToken,
            recipient,
            refundAddress,
            transceiverInstructions
        );
        messageId = bytes32(uint256(sequence));

        // Generate the executor request event.
        _requestExecution(destinationChainId, messageId, executorArgs);
    }

    /// @inheritdoc IExecutorEntryPoint
    function sendMTokenIndex(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId) {
        messageId = IHubPortal(portal).sendMTokenIndex{ value: msg.value - executorArgs.value }(
            destinationChainId,
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        _requestExecution(destinationChainId, messageId, executorArgs);
    }

    /// @inheritdoc IExecutorEntryPoint
    function sendEarnersMerkleRoot(
        uint16 destinationChainId,
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId) {
        messageId = IHubPortal(portal).sendEarnersMerkleRoot{ value: msg.value - executorArgs.value }(
            destinationChainId,
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        _requestExecution(destinationChainId, messageId, executorArgs);
    }

    /* ============ Internal Functions ============ */

    function _requestExecution(
        uint16 destinationChainId,
        bytes32 messageId,
        ExecutorArgs calldata executorArgs
    ) internal {
        // Generate the executor event.
        IExecutor(executor).requestExecution{ value: executorArgs.value }(
            destinationChainId,
            INttManager(portal).getPeer(destinationChainId).peerAddress,
            executorArgs.refundAddress,
            executorArgs.signedQuote,
            ExecutorMessages.makeNTTv1Request(chainId, portal.toBytes32(), messageId),
            executorArgs.instructions
        );

        // Refund any excess value.
        uint256 currentBalance = address(this).balance;
        if (currentBalance > 0) {
            (bool refundSuccessful, ) = payable(executorArgs.refundAddress).call{ value: currentBalance }("");
            if (!refundSuccessful) {
                revert RefundFailed(currentBalance);
            }
        }
    }

    function _custodyTokens(address token, uint256 amount) internal returns (uint256) {
        // query own token balance before transfer
        uint256 balanceBefore = _getBalance(token);

        // deposit tokens
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // return the balance difference
        return _getBalance(token) - balanceBefore;
    }

    function _getBalance(address token) internal view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }
}
