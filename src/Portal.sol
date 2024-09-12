// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IBridge } from "./bridges/interfaces/IBridge.sol";

import { IMTokenLike } from "./interfaces/Dependencies.sol";
import { IPortal } from "./interfaces/IPortal.sol";

// TODO: lookup msg.sender at Registrar for bridge validity in `onlyBridge()`.
// TODO: differentiate a default bridge from a defined bridge.
// TODO: add other quoting functions.

/**
 * @title  Base Portal contract inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
abstract contract Portal is IPortal {
    /* ============ Variables ============ */

    /// @inheritdoc IPortal
    address public immutable bridge;

    /// @inheritdoc IPortal
    address public immutable mToken;

    /// @inheritdoc IPortal
    address public immutable registrar;

    /// @notice The scaling of rates in for exponent math.
    uint56 internal constant _EXP_SCALED_ONE = 1e12;

    /// TODO: properly estimate the following gas limit
    /// @dev Gas limit for sending M tokens.
    uint32 internal constant _SEND_M_TOKEN_GAS_LIMIT = 200_000;

    /* ============ Modifiers ============ */

    /// @dev Modifier to check if caller is the Bridge.
    modifier onlyBridge() {
        if (msg.sender != bridge) revert NotBridge(msg.sender);

        _;
    }

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     * @param  bridge_    The address of the bridge that will dispatch and receive messages.
     * @param  mToken_    The address of the M token to bridge.
     * @param  registrar_ The address of the Registrar.
     */
    constructor(address bridge_, address mToken_, address registrar_) {
        if ((bridge = bridge_) == address(0)) revert ZeroBridge();
        if ((mToken = mToken_) == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
    }

    /* ============ Interactive Functions ============ */

    /// @inheritdoc IPortal
    function sendMToken(
        uint256 chainId_,
        address recipient_,
        uint256 amount_,
        address refundAddress_
    ) external payable returns (bytes32 messageId_) {
        if (amount_ == 0) revert InsufficientAmount(amount_);
        if (recipient_ == address(0)) revert InvalidRecipient(recipient_);
        if (refundAddress_ == address(0)) revert InvalidRefundAddress(refundAddress_);

        _sendMToken(amount_);

        uint128 index_ = _currentIndex();

        messageId_ = _dispatch(
            chainId_,
            _encodeSendMTokenMessage(msg.sender, recipient_, amount_, index_),
            _SEND_M_TOKEN_GAS_LIMIT,
            refundAddress_
        );

        emit MTokenSent(chainId_, bridge, messageId_, msg.sender, recipient_, amount_, index_);
    }

    /// @inheritdoc IPortal
    function receiveMToken(
        uint256 fromChainId_,
        address sender_,
        address recipient_,
        uint256 amount_,
        uint128 index_
    ) external onlyBridge {
        emit MTokenReceived(fromChainId_, msg.sender, sender_, recipient_, amount_, index_);

        uint128 currentIndex_ = _currentIndex();

        _receiveMToken(recipient_, amount_, index_);

        // If the index from the origin chain is lower than the current index and the sender is an earner,
        // adjust the amount to account for the accrued earnings.
        if (currentIndex_ > index_ && IMTokenLike(mToken).isEarning(sender_)) {
            _receiveMToken(sender_, (amount_ * (currentIndex_ - index_)) / _EXP_SCALED_ONE, index_);
        }
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPortal
    function currentIndex() external view returns (uint128) {
        return _currentIndex();
    }

    /// @inheritdoc IPortal
    function quoteSendMToken(uint256 chainId_, address recipient_, uint256 amount_) external view returns (uint256) {
        return
            _quote(
                chainId_,
                _encodeSendMTokenMessage(msg.sender, recipient_, amount_, IMTokenLike(mToken).currentIndex()),
                _SEND_M_TOKEN_GAS_LIMIT
            );
    }

    /* ============ Internal Interactive Functions ============ */

    /**
     * @dev    Dispatch a message to the local bridge.
     * @param  chainId_       ID of the receiving chain.
     * @param  message_       Data dispatched to the receiving chain's Portal.
     * @param  gasLimit_      Gas limit to be used for executing the message.
     * @param  refundAddress_ Refund address in case of excess native gas.
     * @return ID uniquely identifying the message.
     */
    function _dispatch(
        uint256 chainId_,
        bytes memory message_,
        uint32 gasLimit_,
        address refundAddress_
    ) internal returns (bytes32) {
        return IBridge(bridge).dispatch{ value: msg.value }(chainId_, message_, gasLimit_, refundAddress_);
    }

    /**
     * @dev   Function overridden by the inheriting contract to send M tokens to the destination chain.
     * @dev   HubPortal:   transfers and locks `amount_` M tokens from the caller.
     *        SpokePortal: burns `amount_` M tokens from the caller.
     * @param amount_ The amount of M tokens to lock/burn.
     */
    function _sendMToken(uint256 amount_) internal virtual {}

    /**
     * @dev   Receive M tokens from the source chain.
     * @dev   HubPortal:   unlocks and transfers `amount_` M tokens to `recipient_`.
     *        SpokePortal: mints `amount_` M tokens to `recipient_`.
     * @param recipient_ The account receiving M tokens.
     * @param amount_    The amount of M tokens to unlock/mint.
     * @param index_     The index from the source chain.
     */
    function _receiveMToken(address recipient_, uint256 amount_, uint128 index_) internal virtual {}

    /* ============ Internal View/Pure Functions ============ */

    /// @dev Returns the current M token index used by the Portal.
    function _currentIndex() internal view virtual returns (uint128) {}

    /**
     * @dev    Helper function to query the Bridge.quote() for fee calculation.
     * @param  chainId_  The destination chain ID.
     * @param  message_  The message to send.
     * @param  gasLimit_ Gas limit for the destination chains execution.
     * @return The calculated native fee for the message.
     */
    function _quote(uint256 chainId_, bytes memory message_, uint32 gasLimit_) internal view returns (uint256) {
        return IBridge(bridge).quote(chainId_, message_, gasLimit_);
    }

    /**
     * @dev    Encodes the message to send tokens to the destination chain.
     * @param  sender_    The account sending tokens from the source chain.
     * @param  recipient_ The account receiving tokens on the destination chain.
     * @param  amount_    The amount of tokens to send.
     * @param  index_     The index from the source chain.
     * @return The encoded message.
     */
    function _encodeSendMTokenMessage(
        address sender_,
        address recipient_,
        uint256 amount_,
        uint128 index_
    ) internal view returns (bytes memory) {
        return abi.encodeCall(IPortal.receiveMToken, (block.chainid, sender_, recipient_, amount_, index_));
    }
}
