// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

/**
 * @title  Portal interface inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
interface IPortal {
    /* ============ Events ============ */

    /**
     * @notice Emitted when M token are sent to a destination chain.
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
     * @notice Emitted when M token are received from a source chain.
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

    /* ============ Custom Errors ============ */

    /// @notice Emitted when the M token is 0x0.
    error ZeroMToken();

    /// @notice Emitted when the Registrar address is 0x0.
    error ZeroRegistrar();

    /* ============ View/Pure Functions ============ */

    /// @notice The current index of the Portal's earning mechanism.
    function currentIndex() external view returns (uint128);

    /// @notice The address of the M token.
    function mToken() external view returns (address);

    /// @notice The address of the Registrar contract.
    function registrar() external view returns (address);
}
