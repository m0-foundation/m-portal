// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {
    TrimmedAmount,
    TrimmedAmountLib
} from "../lib/example-native-token-transfers/evm/src/libraries/TrimmedAmount.sol";
import { TransceiverStructs } from "../lib/example-native-token-transfers/evm/src/libraries/TransceiverStructs.sol";
import {
    NttManagerNoRateLimiting
} from "../lib/example-native-token-transfers/evm/src/NttManager/NttManagerNoRateLimiting.sol";

import { IPortal } from "./interfaces/IPortal.sol";
import { TypeConverter } from "./libs/TypeConverter.sol";
import { PayloadType, PayloadEncoder } from "./libs/PayloadEncoder.sol";

/**
 * @title  Base Portal contract inherited by HubPortal and SpokePortal.
 * @author M^0 Labs
 */
abstract contract Portal is NttManagerNoRateLimiting, IPortal {
    using TypeConverter for *;
    using PayloadEncoder for bytes;
    using TrimmedAmountLib for *;

    /// @inheritdoc IPortal
    address public immutable registrar;

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

    /* ============ Internal Interactive Functions ============ */

    /// @dev Adds M Token index to the NTT payload.
    function _prepareNativeTokenTransfer(
        TrimmedAmount amount_,
        bytes32 recipient_,
        uint16 destinationChainId_,
        uint64 sequence_,
        address sender_,
        bytes32 // refundAddress
    ) internal override returns (TransceiverStructs.NativeTokenTransfer memory nativeTokenTransfer_) {
        // Convert to uint64 for compatibility with Solana and other non-EVM chains.
        uint64 index_ = _currentIndex().toUint64();

        nativeTokenTransfer_ = TransceiverStructs.NativeTokenTransfer(
            amount_,
            token.toBytes32(),
            recipient_,
            destinationChainId_,
            abi.encodePacked(index_)
        );

        bytes32 messageId_ = TransceiverStructs.nttManagerMessageDigest(
            chainId,
            TransceiverStructs.NttManagerMessage(
                bytes32(uint256(sequence_)),
                sender_.toBytes32(),
                TransceiverStructs.encodeNativeTokenTransfer(nativeTokenTransfer_)
            )
        );

        uint256 untrimmedAmount_ = amount_.untrim(tokenDecimals());
        _beforeTokenSent(untrimmedAmount_);

        emit MTokenSent(destinationChainId_, messageId_, sender_, recipient_, untrimmedAmount_, index_);
    }

    /// @dev Hook that is called before cross-chain transfer
    function _beforeTokenSent(uint256 amount_) internal virtual {}

    /// @dev Hook that is called before receiving M tokens
    function _afterTokenReceived(uint256 amount_) internal virtual {}

    /// @dev Handles token transfer with an additional payload and custom payload types on the destination.
    function _handleMsg(
        uint16 sourceChainId_,
        bytes32, // sourceNttManagerAddress
        TransceiverStructs.NttManagerMessage memory message_,
        bytes32 messageId_ // digest
    ) internal override {
        bytes memory payload_ = message_.payload;
        PayloadType payloadType_ = message_.payload.getPayloadType();

        if (payloadType_ == PayloadType.Token) {
            _receiveMToken(sourceChainId_, messageId_, message_.sender, payload_);
            return;
        }

        _receiveCustomPayload(messageId_, payloadType_, payload_);
    }

    function _receiveMToken(uint16 sourceChainId_, bytes32 messageId_, bytes32 sender_, bytes memory payload_) private {
        (TrimmedAmount trimmedAmount_, uint128 index_, address recipient_, uint16 destinationChainId_) = payload_
            .decodeTokenTransfer();

        _verifyDestinationChain(destinationChainId_);

        // NOTE: Assumes that token.decimals() are the same on all chains.
        uint256 amount_ = trimmedAmount_.untrim(tokenDecimals());

        emit MTokenReceived(sourceChainId_, messageId_, sender_, recipient_, amount_, index_);

        _mintOrUnlock(recipient_, amount_, index_);

        _afterTokenReceived(amount_);
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

    /**
     * @dev   HubPortal:   unlocks and transfers `amount_` M tokens to `recipient_`.
     *        SpokePortal: mints `amount_` M tokens to `recipient_`.
     * @param recipient_ The account receiving M tokens.
     * @param amount_    The amount of M tokens to unlock/mint.
     * @param index_     The index from the source chain.
     */
    function _mintOrUnlock(address recipient_, uint256 amount_, uint128 index_) internal virtual {}

    /// @dev Returns the current M token index used by the Portal.
    function _currentIndex() internal view virtual returns (uint128) {}
}
