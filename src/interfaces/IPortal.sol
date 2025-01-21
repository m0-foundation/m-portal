// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Portal interface inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
interface IPortal {
    /* ============ Events ============ */

    /**
     * @notice Emitted when M token is sent to a destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  sourceToken        The address of the token on the source chain.
     * @param  destinationToken   The address of the token on the destination chain.
     * @param  messageId          The unique identifier for the sent message.
     * @param  sender             The address that bridged the M tokens via the Portal.
     * @param  recipient          The account receiving tokens on destination chain.
     * @param  amount             The amount of tokens.
     * @param  index              The M token index.
     */
    event MTokenSent(
        uint16 destinationChainId,
        address indexed sourceToken,
        bytes32 destinationToken,
        bytes32 messageId,
        address indexed sender,
        bytes32 indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when M token is received from a source chain.
     * @param  sourceChainId    The Wormhole source chain ID.
     * @param  destinationToken The address of the token on the destination chain.
     * @param  messageId        The unique identifier for the received message.
     * @param  sender           The account sending tokens.
     * @param  recipient        The account receiving tokens.
     * @param  amount           The amount of tokens.
     * @param  index            The M token index.
     */
    event MTokenReceived(
        uint16 sourceChainId,
        address indexed destinationToken,
        bytes32 messageId,
        bytes32 indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when wrapping M token is failed on the destination.
     * @param  destinationWrappedToken The address of the Wrapped M Token on the destination chain.
     * @param  recipient               The account receiving tokens.
     * @param  amount                  The amount of tokens.
     */
    event WrapFailed(address indexed destinationWrappedToken, address indexed recipient, uint256 amount);

    /**
     * @notice Emitted when M token is set for the remote chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  mToken             The address of M token on the destination chain.
     */
    event DestinationMTokenSet(uint16 indexed destinationChainId, bytes32 mToken);

    /**
     * @notice Emitted when a supported token is set for the remote chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  destinationToken   The address of the token on the destination chain.
     * @param  supported          `True` if the token is supported, `false` otherwise.
     */
    event SupportedDestinationTokenSet(
        uint16 indexed destinationChainId,
        bytes32 indexed destinationToken,
        bool supported
    );

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the M token is 0x0.
    error ZeroMToken();

    /// @notice Emitted when the Registrar address is 0x0.
    error ZeroRegistrar();

    /// @notice Emitted when the source token address is 0x0.
    error ZeroSourceToken();

    /// @notice Emitted when the destination token address is 0x0.
    error ZeroDestinationToken();

    /// @notice Emitted when a message received if the block.chainId
    ///         isn't equal to EVM chainId set in the constructor.
    error InvalidFork(uint256 evmChainId, uint256 blockChainId);

    /// @notice Emitted in `setDestinationWrappedMToken` function when the destination chain id
    ///         is equal to the source one.
    error InvalidDestinationChain(uint16 destinationChainId);

    /// @notice Emitted in `transferWrappedMToken` function when the token is not supported on the destination chain.
    error UnsupportedDestinationToken(uint16 destinationChainId, bytes32 destinationToken);

    /* ============ View/Pure Functions ============ */

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);

    /**
     * @notice Returns the address of M token the destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @return mToken             The address of M token the destination chain.
     */
    function destinationMToken(uint16 destinationChainId) external view returns (bytes32 mToken);

    /**
     * @notice Indicates whether the provided token is supported on the destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  destinationToken   The address of the token on the destination chain.
     * @return supported          `True` if the token is supported, `false` otherwise.
     */
    function supportedDestinationToken(
        uint16 destinationChainId,
        bytes32 destinationToken
    ) external view returns (bool supported);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Sets M token address on the remote chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  mToken             The address of M token on the destination chain.
     */
    function setDestinationMToken(uint16 destinationChainId, bytes32 mToken) external;

    /**
     * @notice Sets whether the token is supported on the remote chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  destinationToken   The address of the token on the destination chain.
     * @param  supported          `True` if the token is supported, `false` otherwise.
     */
    function setSupportedDestinationToken(uint16 destinationChainId, bytes32 destinationToken, bool supported) external;

    /**
     * @notice Transfers M or Wrapped M Token to the destination chain.
     * @param  amount             The amount of tokens to transfer.
     * @param  sourceToken        The address of the token (M or Wrapped M) on the source chain.
     * @param  destinationToken   The address of the token (M or Wrapped M) on the destination chain.
     * @param  destinationChainId The Wormhole destination chain ID.
     * @param  recipient          The account to receive tokens.
     * @param  refundAddress      The address to receive excess native gas on the destination chain.
     * @return messageId          The ID uniquely identifying the message.
     */
    function transferWrappedMToken(
        uint256 amount,
        address sourceToken,
        bytes32 destinationToken,
        uint16 destinationChainId,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable returns (bytes32 messageId);
}
