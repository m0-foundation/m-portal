// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import {
    TrimmedAmount,
    TrimmedAmountLib
} from "../lib/native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
import { TransceiverStructs } from "../lib/native-token-transfers/evm/src/libraries/TransceiverStructs.sol";
import {
    NttManagerNoRateLimiting
} from "../lib/native-token-transfers/evm/src/NttManager/NttManagerNoRateLimiting.sol";

import { IPortal } from "./interfaces/IPortal.sol";
import { IWrappedMTokenLike } from "./interfaces/IWrappedMTokenLike.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";
import { SafeCall } from "./libs/SafeCall.sol";
import { PayloadType, PayloadEncoder } from "./libs/PayloadEncoder.sol";

/**
 * @title  Base Portal contract inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
abstract contract Portal is NttManagerNoRateLimiting, IPortal {
    using TypeConverter for *;
    using PayloadEncoder for bytes;
    using TrimmedAmountLib for *;
    using SafeCall for address;

    /// @dev Use only standard WormholeTransceiver with relaying enabled
    bytes public constant DEFAULT_TRANSCEIVER_INSTRUCTIONS = new bytes(1);

    /// @inheritdoc IPortal
    address public immutable registrar;

    /// @inheritdoc IPortal
    mapping(uint16 destinationChainId => mapping(bytes32 destinationToken => bool supported))
        public supportedDestinationToken;

    /// @inheritdoc IPortal
    mapping(uint16 destinationChainId => bytes32 mToken) public destinationMToken;

    /* ============ Constructor ============ */

    /**
     * @notice Constructs the contract.
     * @param  mToken_    The address of the M token to bridge.
     * @param  registrar_ The address of the Registrar.
     * @param  mode_      The NttManager token transfer mode - LOCKING or BURNING.
     * @param  chainId_   The Wormhole chain id.
     */
    constructor(
        address mToken_,
        address registrar_,
        Mode mode_,
        uint16 chainId_
    ) NttManagerNoRateLimiting(mToken_, mode_, chainId_) {
        if (mToken_ == address(0)) revert ZeroMToken();
        if ((registrar = registrar_) == address(0)) revert ZeroRegistrar();
    }

    /* ============ View/Pure Functions ============ */

    /// @inheritdoc IPortal
    function mToken() public view returns (address) {
        return token;
    }

    /// @inheritdoc IPortal
    function currentIndex() external view returns (uint128) {
        return _currentIndex();
    }

    /* ============ External Interactive Functions ============ */

    /// @inheritdoc IPortal
    function setDestinationMToken(uint16 destinationChainId_, bytes32 mToken_) external onlyOwner {
        if (destinationChainId_ == chainId) revert InvalidDestinationChain(destinationChainId_);
        if (mToken_ == bytes32(0)) revert ZeroMToken();

        destinationMToken[destinationChainId_] = mToken_;
        emit DestinationMTokenSet(destinationChainId_, mToken_);
    }

    /// @inheritdoc IPortal
    function setSupportedDestinationToken(
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        bool supported_
    ) external onlyOwner {
        if (destinationChainId_ == chainId) revert InvalidDestinationChain(destinationChainId_);
        if (destinationToken_ == bytes32(0)) revert ZeroDestinationToken();

        supportedDestinationToken[destinationChainId_][destinationToken_] = supported_;
        emit SupportedDestinationTokenSet(destinationChainId_, destinationToken_, supported_);
    }

    /// @inheritdoc IPortal
    function transferWrappedMToken(
        uint256 amount_,
        address sourceToken_,
        bytes32 destinationToken_,
        uint16 destinationChainId_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) external payable returns (bytes32 messageId_) {
        _verifyTransferArgs(amount_, destinationToken_, recipient_, refundAddress_);

        if (sourceToken_ == address(0)) revert ZeroSourceToken();
        if (!supportedDestinationToken[destinationChainId_][destinationToken_])
            revert UnsupportedDestinationToken(destinationChainId_, destinationToken_);

        IERC20 mToken_ = IERC20(token);
        uint256 balanceBefore = mToken_.balanceOf(address(this));

        // transfer source token from the sender
        IERC20(sourceToken_).transferFrom(msg.sender, address(this), amount_);

        // if the source token isn't M token, unwrap it
        if (sourceToken_ != address(mToken_)) {
            amount_ = IWrappedMTokenLike(sourceToken_).unwrap(address(this), amount_);
        }

        // account for potential rounding errors when transferring between earners and non-earners
        amount_ = mToken_.balanceOf(address(this)) - balanceBefore;

        (messageId_, ) = _transferMToken(
            amount_,
            sourceToken_,
            destinationToken_,
            destinationChainId_,
            recipient_,
            refundAddress_
        );
    }

    /* ============ Internal/Private Interactive Functions ============ */

    /// @dev Called from NTTManager `transfer` function to transfer M token
    ///      Overridden to reduce code duplication, optimize gas cost and prevent Yul stack too deep
    function _transferEntryPoint(
        uint256 amount_,
        uint16 destinationChainId_,
        bytes32 recipient_,
        bytes32 refundAddress_,
        bool, // shouldQueue_
        bytes memory // transceiverInstructions_
    ) internal override returns (uint64 sequence_) {
        bytes32 destinationToken_ = destinationMToken[destinationChainId_];

        _verifyTransferArgs(amount_, destinationToken_, recipient_, refundAddress_);

        IERC20 mToken_ = IERC20(token);
        uint256 balanceBefore = mToken_.balanceOf(address(this));

        // transfer M token from the sender
        mToken_.transferFrom(msg.sender, address(this), amount_);

        // account for potential rounding errors when transferring between earners and non-earners
        amount_ = mToken_.balanceOf(address(this)) - balanceBefore;

        (, sequence_) = _transferMToken(
            amount_,
            token,
            destinationToken_,
            destinationChainId_,
            recipient_,
            refundAddress_
        );
    }

    function _transferMToken(
        uint256 amount_,
        address sourceToken_,
        bytes32 destinationToken_,
        uint16 destinationChainId_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) private returns (bytes32 messageId_, uint64 sequence_) {
        // NOTE: the following code has been adapted from NTT manager `transfer` or `_transferEntryPoint` functions.
        // We cannot call those functions directly here as they attempt to transfer M Token from the msg.sender.

        _burnOrLock(amount_);

        sequence_ = _useMessageSequence();
        uint128 index_ = _currentIndex();

        TransceiverStructs.NttManagerMessage memory message_;
        (, message_, messageId_) = _encodeTokenTransfer(
            _trimTransferAmount(amount_, destinationChainId_),
            index_,
            recipient_,
            destinationToken_,
            destinationChainId_,
            sequence_,
            msg.sender
        );

        uint256 totalPriceQuote_ = _sendMessage(destinationChainId_, refundAddress_, message_);

        // Prevent stack too deep
        uint256 transferAmount_ = amount_;

        emit MTokenSent(
            destinationChainId_,
            sourceToken_,
            destinationToken_,
            messageId_,
            msg.sender,
            recipient_,
            transferAmount_,
            index_
        );

        // Emit NTT events
        emit TransferSent(
            recipient_,
            refundAddress_,
            transferAmount_,
            totalPriceQuote_,
            destinationChainId_,
            sequence_
        );
        emit TransferSent(messageId_);
    }

    function _encodeTokenTransfer(
        TrimmedAmount amount_,
        uint128 index_,
        bytes32 recipient_,
        bytes32 destinationWrappedToken_,
        uint16 destinationChainId_,
        uint64 sequence_,
        address sender_
    )
        internal
        returns (
            TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_,
            TransceiverStructs.NttManagerMessage memory message_,
            bytes32 messageId_
        )
    {
        nativeTokenTransfer_ = TransceiverStructs.NativeTokenTransfer(
            amount_,
            token.toBytes32(),
            recipient_,
            destinationChainId_,
            PayloadEncoder.encodeAdditionalPayload(index_, destinationWrappedToken_)
        );

        message_ = TransceiverStructs.NttManagerMessage(
            bytes32(uint256(sequence_)),
            sender_.toBytes32(),
            TransceiverStructs.encodeNativeTokenTransfer(nativeTokenTransfer_)
        );

        messageId_ = TransceiverStructs.nttManagerMessageDigest(chainId, message_);
    }

    /// @notice Sends a generic message to the destination chain.
    /// @dev    The implementation is adapted from `NttManager` `_transfer` function.
    function _sendMessage(
        uint16 destinationChainId_,
        bytes32 refundAddress_,
        TransceiverStructs.NttManagerMessage memory message_
    ) internal returns (uint256) {
        _verifyIfChainForked();

        (
            address[] memory enabledTransceivers_,
            TransceiverStructs.TransceiverInstruction[] memory instructions_,
            uint256[] memory priceQuotes_,
            uint256 totalPriceQuote_
        ) = _prepareForTransfer(destinationChainId_, DEFAULT_TRANSCEIVER_INSTRUCTIONS);

        // send a message
        _sendMessageToTransceivers(
            destinationChainId_,
            refundAddress_,
            _getPeersStorage()[destinationChainId_].peerAddress,
            priceQuotes_,
            instructions_,
            enabledTransceivers_,
            TransceiverStructs.encodeNttManagerMessage(message_)
        );

        return totalPriceQuote_;
    }

    /// @dev Handles token transfer with an additional payload and custom payload types on the destination.
    function _handleMsg(
        uint16 sourceChainId_,
        bytes32, // sourceNttManagerAddress
        TransceiverStructs.NttManagerMessage memory message_,
        bytes32 messageId_ // digest
    ) internal override {
        bytes memory payload_ = message_.payload;
        PayloadType payloadType_ = message_.payload.getPayloadType();

        _verifyIfChainForked();

        if (payloadType_ == PayloadType.Token) {
            _receiveMToken(sourceChainId_, messageId_, message_.sender, payload_);
            return;
        }

        _receiveCustomPayload(messageId_, payloadType_, payload_);
    }

    function _receiveMToken(uint16 sourceChainId_, bytes32 messageId_, bytes32 sender_, bytes memory payload_) private {
        (
            TrimmedAmount trimmedAmount_,
            uint128 index_,
            address destinationToken_,
            address recipient_,
            uint16 destinationChainId_
        ) = payload_.decodeTokenTransfer();

        _verifyDestinationChain(destinationChainId_);

        // NOTE: Assumes that token.decimals() are the same on all chains.
        uint256 amount_ = trimmedAmount_.untrim(tokenDecimals());

        emit MTokenReceived(sourceChainId_, destinationToken_, messageId_, sender_, recipient_, amount_, index_);

        // Emitting `INttManager.TransferRedeemed` to comply with Wormhole NTT specification.
        emit TransferRedeemed(messageId_);

        if (destinationToken_ == token) {
            // mints or unlocks M Token to the recipient
            _mintOrUnlock(recipient_, amount_, index_);
        } else {
            // mints or unlocks M Token to the Portal
            _mintOrUnlock(address(this), amount_, index_);

            // wraps M token and transfers it to the recipient
            _wrap(destinationToken_, recipient_, amount_);
        }
    }

    /// @dev Wraps M token to the token specified by `destinationWrappedToken_`.
    ///      If wrapping fails transfers M token to `recipient_`.
    function _wrap(address destinationWrappedToken_, address recipient_, uint256 amount_) private {
        bool success = destinationWrappedToken_.safeCall(
            abi.encodeCall(IWrappedMTokenLike.wrap, (recipient_, amount_))
        );

        if (!success) {
            emit WrapFailed(destinationWrappedToken_, recipient_, amount_);
            IERC20(mToken()).transfer(recipient_, amount_);
        }
    }

    function _receiveCustomPayload(
        bytes32 messageId_,
        PayloadType payloadType_,
        bytes memory payload_
    ) internal virtual {}

    function _verifyDestinationChain(uint16 destinationChainId_) internal view {
        // Verify that the destination chain is the current chain.
        if (destinationChainId_ != chainId) revert InvalidTargetChain(destinationChainId_, chainId);
    }

    function _verifyIfChainForked() internal view {
        // Verify that the destination chain isn't forked
        uint256 evmChainId_ = evmChainId;
        if (evmChainId_ != block.chainid) revert InvalidFork(evmChainId_, block.chainid);
    }

    function _verifyTransferArgs(
        uint256 amount_,
        bytes32 destinationToken_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) private view {
        if (amount_ == 0) revert ZeroAmount();
        if (destinationToken_ == bytes32(0)) revert ZeroDestinationToken();
        if (recipient_ == bytes32(0)) revert InvalidRecipient();
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();
    }

    /**
     * @dev   HubPortal:   unlocks and transfers `amount_` M tokens to `recipient_`.
     *        SpokePortal: mints `amount_` M tokens to `recipient_`.
     * @param recipient_ The account receiving M tokens.
     * @param amount_    The amount of M tokens to unlock/mint.
     * @param index_     The index from the source chain.
     */
    function _mintOrUnlock(address recipient_, uint256 amount_, uint128 index_) internal virtual {}

    /**
     * @dev   HubPortal:   locks amount_` M tokens.
     *        SpokePortal: burns `amount_` M tokens.
     * @param amount_ The amount of M tokens to lock/burn.
     */
    function _burnOrLock(uint256 amount_) internal virtual {}

    /// @dev Returns the current M token index used by the Portal.
    function _currentIndex() internal view virtual returns (uint128) {}
}
