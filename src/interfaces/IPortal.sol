// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

// TODO: If `MTokenSent` emitted on the source chain cares about `destinationChainId`, `sender`, and `recipient`, then
//       `MTokenReceived` should care about `sourceChainId`, `sender`, and `recipient` as well.

/**
 * @title  Portal interface inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
interface IPortal {
    /* ============ Events ============ */

    /**
     * @notice Emitted when M token are sent to a destination chain.
     * @param  destinationChainId The destination chain ID.
     * @param  bridge             The address of the bridge that will send M to the destination chain.
     * @param  messageId          The unique identifier for the sent message.
     * @param  sender             The address that bridged the M tokens via the Portal.
     * @param  recipient          The account receiving tokens on destination chain.
     * @param  amount             The amount of tokens.
     * @param  index              The the M token index.
     */
    event MTokenSent(
        uint256 indexed destinationChainId,
        address indexed bridge,
        bytes32 indexed messageId,
        address sender,
        address recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when M token are received from a source chain.
     * @param  sourceChainId The source chain ID.
     * @param  bridge        The address of the bridge that received the message.
     * @param  sender        The account sending tokens.
     * @param  recipient     The account receiving tokens.
     * @param  amount        The amount of tokens.
     * @param  index         The the M token index.
     */
    event MTokenReceived(
        uint256 sourceChainId,
        address indexed bridge,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index
    );

    /* ============ Custom Errors ============ */

    /**
     * @notice Emitted when the bridged amount is insufficient.
     * @param  amount Amount being bridged.
     */
    error InsufficientAmount(uint256 amount);

    /**
     * @notice Emitted when the recipient on the destination chain is invalid.
     * @param  recipient Address of the invalid recipient.
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Emitted when the refund address is invalid.
     * @param  account Address of the invalid refund account.
     */
    error InvalidRefundAddress(address account);

    /**
     * @notice Emitted when the caller is not the trusted bridge.
     * @param  caller The caller address.
     */
    error NotBridge(address caller);

    /**
     * @notice Emitted when the queried chain is not supported.
     * @param  chainId The queried chain ID.
     */
    error UnsupportedChain(uint256 chainId);

    /// @notice Emitted when the bridge is 0x0.
    error ZeroBridge();

    /// @notice Emitted when the M token is 0x0.
    error ZeroMToken();

    /// @notice Emitted when the Registrar address is 0x0.
    error ZeroRegistrar();

    /* ============ Interactive Functions ============ */

    /**
     * @notice Transfer M tokens to the destination chain.
     * @param  chainId       The destination chain ID.
     * @param  recipient     The account receiving tokens on the destination chain.
     * @param  amount        The amount of M tokens being sent.
     * @param  refundAddress Refund address to receive excess native gas.
     * @return ID uniquely identifying the message
     */
    function sendMToken(
        uint256 chainId,
        address recipient,
        uint256 amount,
        address refundAddress
    ) external payable returns (bytes32);

    /**
     * @notice Receive M tokens from the source chain.
     * @dev    MUST only be callable by an approved bridge.
     * @param  fromChainId The source chain ID.
     * @param  sender      The address of the account that sent the M tokens.
     * @param  recipient   The account receiving tokens.
     * @param  amount      The amount of M Token received.
     * @param  index       The index from the source chain.
     */
    function receiveMToken(
        uint256 fromChainId,
        address sender,
        address recipient,
        uint256 amount,
        uint128 index
    ) external;

    /* ============ View/Pure Functions ============ */

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /**
     * @notice Gets the native fee to pay to send M tokens to the destination chain.
     * @param  chainId   The destination chain ID.
     * @param  recipient The account receiving tokens on the destination chain.
     * @param  amount    The amount of M tokens being sent.
     * @return The native fee to pay.
     */
    function quoteSendMToken(uint256 chainId, address recipient, uint256 amount) external view returns (uint256);

    /// @notice The address of the bridge.
    function bridge() external view returns (address);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);
}
