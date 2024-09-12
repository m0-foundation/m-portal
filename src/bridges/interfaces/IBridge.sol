// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title Common interface for bridges.
 * @dev   IBridge extended to pass gas limit and a refund address to receive excess native gas.
 */
interface IBridge {
    /* ============ Events ============ */

    /**
     * @notice Emitted when a message has successfully been dispatched.
     * @param  chainId   ID of the chain receiving the message.
     * @param  messageId ID uniquely identifying the message.
     * @param  data      Data that was dispatched.
     */
    event MessageDispatched(uint256 indexed chainId, bytes32 indexed messageId, bytes data);

    /**
     * @notice Emitted when a message has successfully been executed.
     * @param  messageId ID uniquely identifying the message that was executed.
     */
    event MessageExecuted(bytes32 indexed messageId);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the caller is not the Portal.
    error NotPortal();

    /// @notice Emitted when the Portal is 0x0.
    error ZeroPortal();

    /**
     * @notice Emitted if a call to a contract fails.
     * @param  messageId ID uniquely identifying the message.
     * @param  errorData Error data returned by the call.
     */
    error MessageFailure(bytes32 messageId, bytes errorData);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Dispatch a message to the receiving chain.
     * @dev    MUST compute and return an ID uniquely identifying the message.
     * @dev    MUST emit the `MessageDispatched` event when successfully dispatched.
     * @param  chainId       ID of the receiving chain.
     * @param  message       Data dispatched to the receiving chain's Portal.
     * @param  gasLimit      Gas limit to be used for executing the message.
     * @param  refundAddress Refund address in case of excess native gas.
     * @return messageId     ID uniquely identifying the message.
     */
    function dispatch(
        uint256 chainId,
        bytes calldata message,
        uint32 gasLimit,
        address refundAddress
    ) external payable returns (bytes32 messageId);

    /* ============ View Functions ============ */

    /**
     * @notice Quote the native fee for dispatching a message to the receiving chain.
     * @param  chainId   The destination chain ID.
     * @param  message   The message to send.
     * @param  gasLimit  Gas limit for the destination chain execution.
     * @return nativeFee The calculated native fee for the message.
     */
    function quote(uint256 chainId, bytes calldata message, uint32 gasLimit) external view returns (uint256 nativeFee);

    /// @notice The address of the Portal contract.
    function portal() external view returns (address);
}
