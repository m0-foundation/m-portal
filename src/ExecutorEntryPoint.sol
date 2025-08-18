// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { INttManager } from "../lib/native-token-transfers/evm/src/interfaces/INttManager.sol";
import { IPortal } from "./interfaces/IPortal.sol";
import { IHubPortal } from "./interfaces/IHubPortal.sol";
import "./interfaces/IExecutorEntryPoint.sol";
import "./external/IExecutor.sol";
import "./external/ExecutorMessages.sol";

string constant executorEntryPointVersion = "ExecutorEntryPoint-0.0.1";

/// @title ExecutorEntryPoint
/// @notice The ExecutorEntryPoint contract is a shim contract that initiates
///         an M NTT transfer using the executor for relaying.
contract ExecutorEntryPoint is IExecutorEntryPoint {
    uint16 public immutable chainId;
    IExecutor public immutable executor;
    IPortal public immutable portal;

    string public constant VERSION = executorEntryPointVersion;

    constructor(uint16 _chainId, address _executor, address _portal) {
        assert(_chainId != 0);
        assert(_executor != address(0));
        assert(_portal != address(0));
        chainId = _chainId;
        executor = IExecutor(_executor);
        portal = IPortal(_portal);
    }

    // ==================== External Interface ===============================================

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
        // Validate input
        if (!portal.supportedBridgingPath(sourceToken, destinationChainId, destinationToken)) {
            revert IPortal.UnsupportedBridgingPath(sourceToken, destinationChainId, destinationToken);
        }

        // Custody the tokens in this contract and approve Portal to spend them.
        // TODO do we need to handle rounding b/w M earners and non-earners?
        amount = _custodyTokens(sourceToken, amount);

        // Initiate the transfer.
        IERC20(sourceToken).approve(address(portal), amount);
        uint64 sequence = portal.transferMLikeToken{ value: msg.value - executorArgs.value }(
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
        messageId = IHubPortal(address(portal)).sendMTokenIndex{ value: msg.value - executorArgs.value }(
            destinationChainId,
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        _requestExecution(destinationChainId, messageId, executorArgs);
    }

    /// @inheritdoc IExecutorEntryPoint
    function sendEarnersMerkleRoot(
        bytes32 refundAddress,
        ExecutorArgs calldata executorArgs,
        bytes memory transceiverInstructions
    ) external payable returns (bytes32 messageId) {
        messageId = IHubPortal(address(portal)).sendEarnersMerkleRoot{ value: msg.value - executorArgs.value }(
            refundAddress,
            transceiverInstructions
        );

        // Generate the executor request event.
        // Chain ID is always Solana (1) for this message.
        _requestExecution(1, messageId, executorArgs);
    }

    // ==================== Internal Functions ==============================================

    function _requestExecution(
        uint16 destinationChainId,
        bytes32 messageId,
        ExecutorArgs calldata executorArgs
    ) internal {
        // Generate the executor event.
        executor.requestExecution{ value: executorArgs.value }(
            destinationChainId,
            INttManager(address(portal)).getPeer(destinationChainId).peerAddress,
            executorArgs.refundAddress,
            executorArgs.signedQuote,
            ExecutorMessages.makeNTTv1Request(chainId, bytes32(uint256(uint160(address(portal)))), messageId),
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
        // fetch the specified token balance for this contract
        (, bytes memory queriedBalance) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        balance = abi.decode(queriedBalance, (uint256));
    }
}
