// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IBridge } from "../../interfaces/IBridge.sol";

/// @title  Optimism Bridge.
/// @author M^0 Labs.
/// @notice A bridge to send data from Ethereum to OP Stack L2 chains.
/// @dev    The same contract must be deployed on Ethereum and L2 chains.
///         For each L2 bridge a separate Ethereum bridge must be deployed
///         since CrossChainMessenger is different for every L2.
interface IOptimismBridge is IBridge {
    /// @notice Emitted when the CrossChainMessenger address is 0x0.
    error ZeroCrossChainMessenger();

    /// @notice Emitted when the remote bridge address is 0x0.
    error ZeroRemoteBridge();

    /// @notice Emitted when the remote chain id is 0.
    error ZeroChainId();

    /// @notice Emitted when a `chainId` passed to `dispatch` is different from `remoteChainId`.
    error UnsupportedChain();

    /// @notice Emitted when `receiveMessage` called by unauthorize caller.
    error UnauthorizedCaller();

    function crossChainMessenger() external view returns (address);

    function remoteBridge() external view returns (address);

    function remoteChainId() external view returns (uint256);

    function nonce() external view returns (uint256);

    /// @notice Receives a cross-chain message and executes it on the Portal.
    /// @dev    Reverts if the sender is invalid.
    function receiveMessage(bytes32 messageId, bytes calldata message) external;
}
