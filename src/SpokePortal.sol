// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";
import { UIntMath } from "../lib/common/src/libs/UIntMath.sol";
import { IndexingMath } from "../lib/common/src/libs/IndexingMath.sol";

import { ISpokeMTokenLike } from "./interfaces/ISpokeMTokenLike.sol";
import { IRegistrarLike } from "./interfaces/IRegistrarLike.sol";
import { ISpokePortal } from "./interfaces/ISpokePortal.sol";

import { Portal } from "./Portal.sol";
import { PayloadType, PayloadEncoder } from "./libs/PayloadEncoder.sol";

/**
 * @title  Portal residing on L2s handling sending/receiving M, update the M index and Registrar keys.
 * @author M^0 Labs
 */
contract SpokePortal is ISpokePortal, Portal {
    using PayloadEncoder for bytes;
    using UIntMath for uint256;

    /// @inheritdoc ISpokePortal
    uint64 public lastProcessedSequence;

    /**
     * @notice Constructs the contract.
     * @param  mToken_    The address of the M token to bridge.
     * @param  registrar_ The address of the Registrar.
     * @param  chainId_   Wormhole chain id.
     */
    constructor(
        address mToken_,
        address registrar_,
        uint16 chainId_
    ) Portal(mToken_, registrar_, Mode.BURNING, chainId_) {}

    /* ============ Internal/Private Interactive Functions ============ */

    function _receiveCustomPayload(
        bytes32 messageId_,
        PayloadType payloadType_,
        bytes memory payload_
    ) internal override {
        if (payloadType_ == PayloadType.Index) {
            _updateMTokenIndex(messageId_, payload_);
        } else if (payloadType_ == PayloadType.Key) {
            _setRegistrarKey(messageId_, payload_);
        } else if (payloadType_ == PayloadType.List) {
            _updateRegistrarList(messageId_, payload_);
        }
    }

    /// @notice Updates M Token index to the index received from the remote chain.
    function _updateMTokenIndex(bytes32 messageId_, bytes memory payload_) private {
        (uint128 index_, uint16 destinationChainId_) = payload_.decodeIndex();

        _verifyDestinationChain(destinationChainId_);

        emit MTokenIndexReceived(messageId_, index_);

        if (index_ > _currentIndex()) {
            ISpokeMTokenLike(mToken()).updateIndex(index_);
        }
    }

    /// @notice Sets a Registrar key received from the Hub chain.
    function _setRegistrarKey(bytes32 messageId_, bytes memory payload_) private {
        (bytes32 key_, bytes32 value_, uint64 sequence_, uint16 destinationChainId_) = payload_.decodeKey();

        _verifyDestinationChain(destinationChainId_);

        emit RegistrarKeyReceived(messageId_, key_, value_, sequence_);

        _verifyMessageSequence(sequence_);

        lastProcessedSequence = sequence_;

        IRegistrarLike(registrar).setKey(key_, value_);
    }

    /// @notice Adds or removes an account from the Registrar List based on the message from the Hub chain.
    function _updateRegistrarList(bytes32 messageId_, bytes memory payload_) private {
        (bytes32 listName_, address account_, bool add_, uint64 sequence_, uint16 destinationChainId_) = payload_
            .decodeListUpdate();

        _verifyDestinationChain(destinationChainId_);

        emit RegistrarListStatusReceived(messageId_, listName_, account_, add_, sequence_);

        _verifyMessageSequence(sequence_);

        lastProcessedSequence = sequence_;

        if (add_) {
            IRegistrarLike(registrar).addToList(listName_, account_);
        } else {
            IRegistrarLike(registrar).removeFromList(listName_, account_);
        }
    }

    /**
     * @dev Mints M Token to the `recipient_`.
     * @param recipient_ The account to mint M tokens to.
     * @param amount_    The amount of M Token to mint to the recipient.
     * @param index_     The index from the source chain.
     */
    function _mintOrUnlock(address recipient_, uint256 amount_, uint128 index_) internal override {
        uint128 currentIndex_ = _currentIndex();

        // Update M token index only if the index received from the remote chain is bigger
        if (index_ > currentIndex_) {
            currentIndex_ = index_;
            ISpokeMTokenLike(mToken()).mint(recipient_, amount_, index_);
        } else {
            ISpokeMTokenLike(mToken()).mint(recipient_, amount_);
        }
    }

    /// @dev Checks if the incoming message sequence is greater than the last processed one to prevent
    ///      Registrar data from being overwritten due to message reordering.
    function _verifyMessageSequence(uint64 sequence_) private view {
        uint64 lastProcessedSequence_ = lastProcessedSequence;
        if (lastProcessedSequence_ != 0 && sequence_ < lastProcessedSequence_)
            revert ObsoleteMessageSequence(sequence_, lastProcessedSequence_);
    }

    /// @dev Returns the current M token index used by the Spoke Portal.
    function _currentIndex() internal view override returns (uint128) {
        return ISpokeMTokenLike(mToken()).currentIndex();
    }
}
