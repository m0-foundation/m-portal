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
     * @param  messageId          The unique identifier for the sent message.
     * @param  sender             The address that bridged the M tokens via the Portal.
     * @param  recipient          The account receiving tokens on destination chain.
     * @param  amount             The amount of tokens.
     * @param  index              The the M token index.
     */
    event MTokenSent(
        uint16 indexed destinationChainId,
        bytes32 messageId,
        address indexed sender,
        bytes32 indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when Wrapped M token is sent to a destination chain.
     * @param  destinationChainId       The Wormhole destination chain ID.
     * @param  sourceWrappedToken       The address of Wrapped M Token on the source chain.
     * @param  destinationWrappedToken  The address of Wrapped M Token on the destination chain.
     * @param  messageId                The unique identifier for the sent message.
     * @param  sender                   The address that bridged the M tokens via the Portal.
     * @param  recipient                The account receiving tokens on destination chain.
     * @param  amount                   The amount of tokens.
     * @param  index                    The the M token index.
     */
    event WrappedMTokenSent(
        uint16 destinationChainId,
        address indexed sourceWrappedToken,
        bytes32 destinationWrappedToken,
        bytes32 messageId,
        address indexed sender,
        bytes32 indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when M token is received from a source chain.
     * @param  sourceChainId The Wormhole source chain ID.
     * @param  messageId     The unique identifier for the received message.
     * @param  sender        The account sending tokens.
     * @param  recipient     The account receiving tokens.
     * @param  amount        The amount of tokens.
     * @param  index         The the M token index.
     */
    event MTokenReceived(
        uint16 indexed sourceChainId,
        bytes32 messageId,
        bytes32 indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when Wrapped M token is received from a source chain.
     * @param  sourceChainId            The Wormhole source chain ID.
     * @param  destinationWrappedToken  The address of the Wrapped M Token on the destination chain.
     * @param  messageId                The unique identifier for the received message.
     * @param  sender                   The account sending tokens.
     * @param  recipient                The account receiving tokens.
     * @param  amount                   The amount of tokens.
     * @param  index                    The the M token index.
     */
    event WrappedMTokenReceived(
        uint16 sourceChainId,
        address indexed destinationWrappedToken,
        bytes32 messageId,
        bytes32 indexed sender,
        address indexed recipient,
        uint256 amount,
        uint128 index
    );

    /**
     * @notice Emitted when wrapping M token is failed on the destination.
     * @param  destinationWrappedToken  The address of the Wrapped M Token on the destination chain.
     * @param  recipient                The account receiving tokens.
     * @param  amount                   The amount of tokens.
     */
    event WrapFailed(address indexed destinationWrappedToken, address indexed recipient, uint256 amount);

    /**
     * @notice Emitted when Smart M token is set for the remote chain.
     * @param  remoteChainId  The Wormhole remote chain ID.
     * @param  smartMToken    The address of the Smart M Token on the remote chain.
     */
    event RemoteSmartMTokenSet(uint16 remoteChainId, bytes32 smartMToken);

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the M token is 0x0.
    error ZeroMToken();

    /// @notice Emitted when the Smart M token is 0x0.
    error ZeroSmartMToken();

    /// @notice Emitted when the Registrar address is 0x0.
    error ZeroRegistrar();

    /// @notice Emitted when a message received if the block.chainId
    ///         isn't equal to EVM chainId set in the constructor.
    error InvalidFork(uint256 evmChainId, uint256 blockChainId);

    /* ============ View/Pure Functions ============ */

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);

    /// @notice The address of the Smart M token.
    function smartMToken() external view returns (address);

    /**
     * @notice Returns the address of the Smart M Token on the remote chain.
     * @param  remoteChainId  The Wormhole remote chain ID.
     * @return smartMToken address on the remote chain.
     */
    function remoteSmartMToken(uint16 remoteChainId) external view returns (bytes32 smartMToken);

    /* ============ Interactive Functions ============ */

    /// @notice Sets the address of Smart M Token on the remote chain.
    function setRemoteSmartMToken(uint16 remoteChainId, bytes32 smartMToken) external;

    /**
     * @notice Transfers Smart M Token to the destination chain.
     * @param  amount               The amount of tokens to transfer.
     * @param  destinationChainId   The Wormhole destination chain ID.
     * @param  recipient            The account to receive tokens.
     * @param  refundAddress        The address to receive excess native gas on the destination chain.
     * @return messageId            The ID uniquely identifying the message.
     */
    function transferSmartMToken(
        uint256 amount,
        uint16 destinationChainId,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable returns (bytes32 messageId);

    /**
     * @notice Transfers Wrapped M Token to the destination chain.
     * @dev    Can be used for transferring M Token Extensions and converting between different Wrappers.
     * @param  amount                   The amount of tokens to transfer.
     * @param  sourceWrappedToken       The address of the Wrapped M Token of the source chain.
     * @param  destinationWrappedToken  The address of the Wrapped M Token of the destination chain.
     * @param  amount                   The amount of tokens to transfer.
     * @param  destinationChainId       The Wormhole destination chain ID.
     * @param  recipient                The account to receive tokens.
     * @param  refundAddress            The address to receive excess native gas on the destination chain.
     * @return messageId                The ID uniquely identifying the message.
     */
    function transferWrappedMToken(
        uint256 amount,
        address sourceWrappedToken,
        bytes32 destinationWrappedToken,
        uint16 destinationChainId,
        bytes32 recipient,
        bytes32 refundAddress
    ) external payable returns (bytes32 messageId);
}
