// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { TrimmedAmount, TrimmedAmountLib } from "../lib/native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
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
    mapping(address sourceToken => mapping(uint16 destinationChainId => mapping(bytes32 destinationToken => bool supported)))
        public supportedBridgingPath;

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
    function setSupportedBridgingPath(
        address sourceToken_,
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        bool supported_
    ) external onlyOwner {
        if (sourceToken_ == address(0)) revert ZeroSourceToken();
        if (destinationChainId_ == chainId) revert InvalidDestinationChain(destinationChainId_);
        if (destinationToken_ == bytes32(0)) revert ZeroDestinationToken();

        supportedBridgingPath[sourceToken_][destinationChainId_][destinationToken_] = supported_;
        emit SupportedBridgingPathSet(sourceToken_, destinationChainId_, destinationToken_, supported_);
    }

    /// @inheritdoc IPortal
    function transferMLikeToken(
        uint256 amount_,
        address sourceToken_,
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) external payable nonReentrant whenNotPaused returns (uint64 sequence_) {
        if (!supportedBridgingPath[sourceToken_][destinationChainId_][destinationToken_]) {
            revert UnsupportedBridgingPath(sourceToken_, destinationChainId_, destinationToken_);
        }

        sequence_ = _transferMLikeToken(
            amount_,
            sourceToken_,
            destinationChainId_,
            destinationToken_,
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
        sequence_ = _transferMLikeToken(
            amount_,
            token, // M Token
            destinationChainId_,
            destinationMToken[destinationChainId_], // M Token on destination
            recipient_,
            refundAddress_
        );
    }

    function _transferMLikeToken(
        uint256 amount_,
        address sourceToken_,
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) private returns (uint64 sequence_) {
        _verifyTransferAmount(amount_);

        if (destinationToken_ == bytes32(0)) revert ZeroDestinationToken();
        if (recipient_ == bytes32(0)) revert InvalidRecipient();
        if (refundAddress_ == bytes32(0)) revert InvalidRefundAddress();

        IERC20 mToken_ = IERC20(token);
        uint256 balanceBefore = mToken_.balanceOf(address(this));

        // transfer source token from the sender
        IERC20(sourceToken_).transferFrom(msg.sender, address(this), amount_);

        // if the source token isn't M token, unwrap it
        if (sourceToken_ != address(mToken_)) {
            IWrappedMTokenLike(sourceToken_).unwrap(address(this), amount_);
        }

        // account for potential rounding errors when transferring between earners and non-earners
        amount_ = mToken_.balanceOf(address(this)) - balanceBefore;
        _verifyTransferAmount(amount_);

        sequence_ = _transferNativeToken(
            amount_,
            sourceToken_,
            destinationChainId_,
            destinationToken_,
            recipient_,
            refundAddress_
        );
    }

    /// @dev adapted from NttManager `_transfer` function.
    //       https://github.com/wormhole-foundation/native-token-transfers/blob/main/evm/src/NttManager/NttManager.sol#L521
    function _transferNativeToken(
        uint256 amount_,
        address sourceToken_,
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        bytes32 recipient_,
        bytes32 refundAddress_
    ) private returns (uint64 sequence_) {
        // burns token on Spoke. In case of Hub, tokens are already transferred
        _burnOrLock(amount_);

        sequence_ = _useMessageSequence();
        uint128 index_ = _currentIndex();

        (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) = _encodeTokenTransfer(
            _trimTransferAmount(amount_, destinationChainId_),
            destinationChainId_,
            destinationToken_,
            msg.sender,
            recipient_,
            index_,
            sequence_
        );

        uint256 totalPriceQuote_ = _sendMessage(destinationChainId_, refundAddress_, message_);

        // prevent stack too deep
        uint256 transferAmount_ = amount_;

        emit MTokenSent(
            sourceToken_,
            destinationChainId_,
            destinationToken_,
            msg.sender,
            recipient_,
            transferAmount_,
            index_,
            messageId_
        );

        // emit NTT events
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
        uint16 destinationChainId_,
        bytes32 destinationToken_,
        address sender_,
        bytes32 recipient_,
        uint128 index_,
        uint64 sequence_
    ) internal returns (TransceiverStructs.NttManagerMessage memory message_, bytes32 messageId_) {
        TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_ = TransceiverStructs.NativeTokenTransfer(
            amount_,
            token.toBytes32(),
            recipient_,
            destinationChainId_,
            PayloadEncoder.encodeAdditionalPayload(index_, destinationToken_)
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

        emit MTokenReceived(sourceChainId_, destinationToken_, sender_, recipient_, amount_, index_, messageId_);

        // Emitting `INttManager.TransferRedeemed` to comply with Wormhole NTT specification.
        emit TransferRedeemed(messageId_);

        address mToken_ = token;
        if (destinationToken_ == mToken_) {
            // mints or unlocks M Token to the recipient
            _mintOrUnlock(recipient_, amount_, index_);
        } else {
            // mints or unlocks M Token to the Portal
            _mintOrUnlock(address(this), amount_, index_);

            // wraps M token and transfers it to the recipient
            _wrap(mToken_, destinationToken_, recipient_, amount_);
        }
    }

    /// @dev Wraps M token to the token specified by `destinationWrappedToken_`.
    ///      If wrapping fails transfers $M token to `recipient_`.
    function _wrap(address mToken_, address destinationWrappedToken_, address recipient_, uint256 amount_) private {
        IERC20(mToken_).approve(destinationWrappedToken_, amount_);

        // Attempt to wrap $M token
        // NOTE: the call might fail with out-of-gas exception
        //       even if the destination token is the valid wrapped M token.
        //       Recipients must support both $M and wrapped $M transfers.
        bool success = destinationWrappedToken_.safeCall(
            abi.encodeCall(IWrappedMTokenLike.wrap, (recipient_, amount_))
        );

        if (!success) {
            emit WrapFailed(destinationWrappedToken_, recipient_, amount_);
            // reset approval to prevent a potential double-spend attack
            IERC20(mToken_).approve(destinationWrappedToken_, 0);
            // transfer $M token to the recipient
            IERC20(mToken_).transfer(recipient_, amount_);
        }
    }

    function _receiveCustomPayload(
        bytes32 messageId_,
        PayloadType payloadType_,
        bytes memory payload_
    ) internal virtual {}

    /// @dev Verifies that the destination chain is the current chain.
    function _verifyDestinationChain(uint16 destinationChainId_) internal view {
        if (destinationChainId_ != chainId) revert InvalidTargetChain(destinationChainId_, chainId);
    }

    /// @dev Verifies that the destination chain isn't forked.
    function _verifyIfChainForked() private view {
        uint256 evmChainId_ = evmChainId;
        if (evmChainId_ != block.chainid) revert InvalidFork(evmChainId_, block.chainid);
    }

    /// @dev Verifies that the transfer amount isn't zero.
    function _verifyTransferAmount(uint256 amount_) private view {
        if (amount_ == 0) revert ZeroAmount();
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
